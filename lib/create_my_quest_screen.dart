import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 日付フォーマットのために追加
import 'models/user_profile.dart' as model; // ◀◀◀ ユーザーモデルをインポート

class CreateMyQuestScreen extends StatefulWidget {
  const CreateMyQuestScreen({super.key});

  @override
  State<CreateMyQuestScreen> createState() => _CreateMyQuestScreenState();
}

class _CreateMyQuestScreenState extends State<CreateMyQuestScreen> {
  // フォームの各項目を管理するためのコントローラー
  final _titleController = TextEditingController();
  final _motivationController = TextEditingController();

  // カテゴリの選択肢 (Webアプリの定義を参考)
  final _categories = [
    "Life",
    "Study",
    "Physical",
    "Social",
    "Creative",
    "Mental"
  ];
  String _selectedCategory = "Life";

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  // ▼▼▼ 以下の2行を追加 ▼▼▼
  model.UserProfile? _currentUserProfile;
  bool _isUserDataLoading = true;
  // ▲▲▲

  // ▼▼▼ initState と _fetchUserData を追加 ▼▼▼
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isUserDataLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserProfile = model.UserProfile.fromFirestore(userDoc);
          _isUserDataLoading = false;
        });
      } else {
        setState(() => _isUserDataLoading = false);
      }
    } catch (e) {
      print("User data fetch error: $e");
      if (mounted) {
        setState(() => _isUserDataLoading = false);
      }
    }
  }
  // ▲▲▲

  // Firestoreにマイクエストを保存する処理
  Future<void> _createMyQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    // ▼▼▼ プロフィール情報のチェックを追加 ▼▼▼
    if (user == null || _currentUserProfile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ユーザー情報の読み込みに失敗しました。')));
      return;
    }
    // ▲▲▲

    final title = _titleController.text.trim();
    final motivation = _motivationController.text.trim();
    if (title.isEmpty ||
        motivation.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('すべての項目を入力してください。')));
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('終了日は開始日より後の日付に設定してください。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Webアプリの useCreateMyQuest を参考に実装
      await FirebaseFirestore.instance.collection('my_quests').add({
        'uid': user.uid,
        // ▼▼▼ 取得元を _currentUserProfile に変更 ▼▼▼
        'userName': _currentUserProfile!.displayName ?? '名無しさん',
        'userPhotoURL': _currentUserProfile!.photoURL,
        // ▲▲▲
        'title': title,
        'motivation': motivation,
        'category': _selectedCategory,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print('マイクエスト作成エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('作成に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 日付選択ダイアログを表示する関数
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新しいマイクエストを設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'クエスト名（目標）'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivationController,
              decoration: const InputDecoration(labelText: '意気込み（なぜ挑戦する？）'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectDate(context, true),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null
                        ? '開始日'
                        : DateFormat('yyyy-MM-dd').format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectDate(context, false),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_endDate == null
                        ? '終了日'
                        : DateFormat('yyyy-MM-dd').format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // ▼▼▼ 読み込み状態のハンドリングを追加 ▼▼▼
            if (_isUserDataLoading)
              const Center(child: CircularProgressIndicator())
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _createMyQuest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('この目標で冒険を始める'),
              ),
            // ▲▲▲
          ],
        ),
      ),
    );
  }
}
