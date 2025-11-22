// lib/initial_profile_setup_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tutorial_screens.dart'; // ◀◀◀ 追加

class InitialProfileSetupScreen extends StatefulWidget {
  const InitialProfileSetupScreen({super.key});

  @override
  State<InitialProfileSetupScreen> createState() =>
      _InitialProfileSetupScreenState();
}

class _InitialProfileSetupScreenState extends State<InitialProfileSetupScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // ユーザー情報をFirestoreに保存
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': name,
        'email': user.email,
        'photoURL': null,
        'uid': user.uid,
        'xp': 0,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalEffortHours': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'stats': {
          'Life': 0,
          'Study': 0,
          'Physical': 0,
          'Social': 0,
          'Creative': 0,
          'Mental': 0,
        },
        // ▼▼▼ チュートリアル未完了状態で保存 ▼▼▼
        'isTutorialCompleted': false,
        // ▲▲▲
      });

      // AuthのProfileも更新
      await user.updateDisplayName(name);

      if (mounted) {
        // ▼▼▼ チュートリアル選択画面へ遷移 ▼▼▼
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const TutorialSelectionScreen()),
        );
        // ▲▲▲
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィールの保存に失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('まずは名前を教えてください'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '表示名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('次へ'),
                  ),
          ],
        ),
      ),
    );
  }
}
