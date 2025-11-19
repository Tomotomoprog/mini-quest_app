// lib/edit_my_quest_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart'; // ◀◀◀ MyQuest モデルをインポート

class EditMyQuestScreen extends StatefulWidget {
  final MyQuest quest; // ◀◀◀ 編集対象のクエストを受け取る

  const EditMyQuestScreen({super.key, required this.quest});

  @override
  State<EditMyQuestScreen> createState() => _EditMyQuestScreenState();
}

class _EditMyQuestScreenState extends State<EditMyQuestScreen> {
  final _titleController = TextEditingController();
  final _motivationController = TextEditingController();
  // ▼▼▼ description を編集可能にするためコントローラー追加 ▼▼▼
  final _descriptionController = TextEditingController();
  // ▲▲▲

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

  @override
  void initState() {
    super.initState();
    // ▼▼▼ 受け取ったクエスト情報でフォームを初期化 ▼▼▼
    _titleController.text = widget.quest.title;
    _motivationController.text = widget.quest.motivation;
    _descriptionController.text =
        widget.quest.description; // ◀◀◀ description も初期化
    _selectedCategory = widget.quest.category;
    _startDate = DateTime.tryParse(widget.quest.startDate);
    _endDate = DateTime.tryParse(widget.quest.endDate);
    // ▲▲▲
  }

  // ▼▼▼ Firestoreのマイクエストを更新する処理 ▼▼▼
  Future<void> _updateMyQuest() async {
    final title = _titleController.text.trim();
    final motivation = _motivationController.text.trim();
    final description =
        _descriptionController.text.trim(); // ◀◀◀ description を取得
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
      // 既存のドキュメントをIDで指定して更新
      await FirebaseFirestore.instance
          .collection('my_quests')
          .doc(widget.quest.id) // ◀◀◀ IDを指定
          .update({
        // ◀◀◀ .add ではなく .update
        'title': title,
        'motivation': motivation,
        'description': description, // ◀◀◀ description を更新
        'category': _selectedCategory,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        // 'status' や 'createdAt', 'uid' などは変更しない
      });

      if (mounted) Navigator.of(context).pop(); // 編集画面を閉じる
    } catch (e) {
      print('マイクエスト更新エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // ▲▲▲

  // 日付選択ダイアログを表示する関数 (変更なし)
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      // ▼▼▼ 初期値を設定（nullなら現在日）▼▼▼
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
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
        title: const Text('マイクエストを編集'), // ◀◀◀ タイトル変更
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
            // ▼▼▼ 詳細(description) の編集フィールドを追加 ▼▼▼
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '詳細（任意）'),
              maxLines: 5,
            ),
            // ▲▲▲
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
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _updateMyQuest, // ◀◀◀ 実行する関数を変更
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('この内容で更新する'), // ◀◀◀ テキスト変更
              ),
          ],
        ),
      ),
    );
  }
}
