// lib/account_name_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountNameScreen extends StatefulWidget {
  const AccountNameScreen({super.key});

  @override
  State<AccountNameScreen> createState() => _AccountNameScreenState();
}

class _AccountNameScreenState extends State<AccountNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitAccountName() async {
    // バリデーションを実行
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ユーザー情報が見つかりません。';
      });
      return;
    }

    // アカウント名は小文字に統一
    final accountName = _controller.text.trim().toLowerCase();

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    // 重複チェック用のコレクション
    final accountNameRef =
        firestore.collection('accountNames').doc(accountName);

    try {
      // トランザクションで重複チェックと書き込みを同時に行う
      await firestore.runTransaction((transaction) async {
        // 1. まず重複チェック用のドキュメントが存在するか確認
        final accountNameDoc = await transaction.get(accountNameRef);
        if (accountNameDoc.exists) {
          // 存在すればエラーを投げてcatchに送る
          throw FirebaseException(plugin: 'firestore', code: 'already-exists');
        }

        // 2. ユーザーのドキュメントが存在するか確認
        final userDoc = await transaction.get(userRef);

        // 3. 重複チェック用ドキュメントを作成 (名前を "予約" する)
        transaction.set(accountNameRef, {'uid': user.uid});

        // 4. ユーザードキュメントを作成または更新
        if (userDoc.exists) {
          // 既にドキュメントが存在する場合（例：古いユーザー）は、accountNameを更新
          transaction.update(userRef, {'accountName': accountName});
        } else {
          // 新規ユーザーの場合、ドキュメントを初期値で作成
          transaction.set(userRef, {
            'accountName': accountName,
            'displayName': user.displayName ?? accountName,
            'photoURL': user.photoURL,
            'xp': 0,
            'stats': {
              'Life': 0,
              'Study': 0,
              'Physical': 0,
              'Social': 0,
              'Creative': 0,
              'Mental': 0,
            },
            // 'avatar' はまだ設定しない
          });
        }
      });

      // 成功した場合、AuthGateが再実行され、
      // 自動的に AvatarCreationScreen に遷移するため、ここでは何もしない
      // (もし AuthGate が検知しない場合に備え、Navigator.pop(context) を呼んでも良い)
    } on FirebaseException catch (e) {
      if (e.code == 'already-exists') {
        setState(() {
          _errorMessage = 'このアカウント名はすでに使用されているため、他のアカウント名を使用してください';
        });
      } else {
        setState(() {
          _errorMessage = 'エラーが発生しました: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '予期せぬエラーが発生しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウント名を設定'),
        automaticallyImplyLeading: false, // 戻るボタンを非表示
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'アカウント名を設定してください',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'これはあなたの固有IDとなり、後から変更はできません。\n英数字とアンダースコア(_)のみ使用できます。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'アカウント名',
                  prefixText: '@',
                  border: const OutlineInputBorder(),
                  // エラーメッセージがあれば表示
                  errorText: _errorMessage,
                ),
                // 英数字とアンダースコアのみ許可
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'アカウント名を入力してください';
                  }
                  if (value.length < 3 || value.length > 15) {
                    return '3文字以上15文字以内で入力してください';
                  }
                  if (RegExp(r'[^a-zA-Z0-9_]').hasMatch(value)) {
                    return '英数字とアンダースコア(_)のみ使用できます';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _submitAccountName,
                      icon: const Icon(Icons.check),
                      label: const Text('決定して次へ'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
