// lib/edit_my_quest_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart';

class EditMyQuestScreen extends StatefulWidget {
  final MyQuest myQuest;

  const EditMyQuestScreen({super.key, required this.myQuest});

  @override
  State<EditMyQuestScreen> createState() => _EditMyQuestScreenState();
}

class _EditMyQuestScreenState extends State<EditMyQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _motivationController;

  // ▼▼▼ 新規項目のコントローラー ▼▼▼
  late TextEditingController _scheduleController;
  late TextEditingController _minimumStepController;
  late TextEditingController _rewardController;
  // ▲▲▲

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.myQuest.title);
    _motivationController =
        TextEditingController(text: widget.myQuest.motivation);

    // ▼▼▼ 初期値をセット ▼▼▼
    _scheduleController = TextEditingController(text: widget.myQuest.schedule);
    _minimumStepController =
        TextEditingController(text: widget.myQuest.minimumStep);
    _rewardController = TextEditingController(text: widget.myQuest.reward);
    // ▲▲▲

    _startDate = DateTime.tryParse(widget.myQuest.startDate);
    _endDate = DateTime.tryParse(widget.myQuest.endDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _motivationController.dispose();
    _scheduleController.dispose();
    _minimumStepController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2100);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _startDate!.isAfter(_endDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = pickedDate;
          if (_startDate != null && _endDate!.isBefore(_startDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('期間を設定してください'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final questRef = FirebaseFirestore.instance
          .collection('my_quests')
          .doc(widget.myQuest.id);

      await questRef.update({
        'title': _titleController.text.trim(),
        'motivation': _motivationController.text.trim(),
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
        // ▼▼▼ 新規項目を更新 ▼▼▼
        'schedule': _scheduleController.text.trim(),
        'minimumStep': _minimumStepController.text.trim(),
        'reward': _rewardController.text.trim(),
        // ▲▲▲
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新しました')),
        );
        Navigator.of(context).pop(true); // trueを返して更新を通知
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('クエストを編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveChanges,
            tooltip: '保存',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('基本設定', Icons.flag),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'クエストタイトル',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return '必須です';
                        return null;
                      },
                    ),

                    _buildSectionHeader('Why (動機)', Icons.psychology),
                    TextFormField(
                      controller: _motivationController,
                      decoration: const InputDecoration(
                        labelText: '意気込み・メモ',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    // ▼▼▼ 追加: 習慣化項目の編集フィールド ▼▼▼
                    _buildSectionHeader('習慣化の仕組み', Icons.build),
                    TextFormField(
                      controller: _scheduleController,
                      decoration: InputDecoration(
                        labelText: 'いつ、どこでやりますか？',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minimumStepController,
                      decoration: InputDecoration(
                        labelText: '最低目標 (2分ルール)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rewardController,
                      decoration: InputDecoration(
                        labelText: '自分へのご褒美',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                    ),
                    // ▲▲▲

                    _buildSectionHeader('期間', Icons.date_range),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(context, true),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _startDate == null
                                  ? '開始日'
                                  : DateFormat('yyyy/MM/dd')
                                      .format(_startDate!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text('〜'),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(context, false),
                            icon: const Icon(Icons.event),
                            label: Text(
                              _endDate == null
                                  ? '終了日'
                                  : DateFormat('yyyy/MM/dd').format(_endDate!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
