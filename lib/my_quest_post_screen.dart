// lib/my_quest_post_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for TextInputFormatter
import 'package:image_picker/image_picker.dart';
import 'models/my_quest.dart';
import 'models/user_profile.dart' as model; // モデルのimportにエイリアスを設定
import 'utils/progression.dart';

class MyQuestPostScreen extends StatefulWidget {
  final MyQuest? initialQuest; // 特定のクエストに紐づける場合に受け取る

  const MyQuestPostScreen({super.key, this.initialQuest});

  @override
  State<MyQuestPostScreen> createState() => _MyQuestPostScreenState();
}

class _MyQuestPostScreenState extends State<MyQuestPostScreen> {
  final _textController = TextEditingController();
  final _timeController = TextEditingController(); // 時間入力用コントローラー
  bool _isLoading = false;
  MyQuest? _selectedMyQuest;
  List<MyQuest> _activeQuests = [];
  File? _imageFile;
  model.UserProfile? _currentUserProfile; // エイリアスを使用
  JobResult? _myJobInfo;
  bool _shareWisdom = false;

  @override
  void initState() {
    super.initState();
    _selectedMyQuest = widget.initialQuest; // 初期クエストを設定
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final questsFuture = FirebaseFirestore.instance
        .collection('my_quests')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();

    final responses = await Future.wait([userDocFuture, questsFuture]);

    final userDoc = responses[0] as DocumentSnapshot;
    final questsSnapshot = responses[1] as QuerySnapshot;

    if (mounted) {
      if (userDoc.exists) {
        final profile = model.UserProfile.fromFirestore(userDoc); // エイリアスを使用
        final level = computeLevel(profile.xp);
        final jobInfo = computeJob(profile.stats, level);
        setState(() {
          _currentUserProfile = profile;
          _myJobInfo = jobInfo;
        });
      }
      final quests =
          questsSnapshot.docs.map((doc) => MyQuest.fromFirestore(doc)).toList();
      setState(() => _activeQuests = quests);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _showMyQuestPicker() {
    if (widget.initialQuest != null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('マイクエストを選択',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (_activeQuests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('現在進行中のマイクエストがありません。'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _activeQuests.length,
                    itemBuilder: (context, index) {
                      final quest = _activeQuests[index];
                      return ListTile(
                        title: Text(quest.title),
                        onTap: () {
                          setState(() => _selectedMyQuest = quest);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUserProfile == null || _myJobInfo == null)
      return;

    final text = _textController.text.trim();
    final timeSpent = int.tryParse(_timeController.text.trim());

    if (_selectedMyQuest == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('紐付けるマイクエストを選択してください。')));
      return;
    }
    if (text.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿内容を入力するか、写真を選択してください。')));
      return;
    }
    if (timeSpent == null || timeSpent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('努力した時間(分)を正しく入力してください。')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final level = computeLevel(_currentUserProfile!.xp);
      final jobInfo = _myJobInfo!;
      final questCategory = _selectedMyQuest!.category;

      String? photoURL;
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_imageFile!);
        photoURL = await storageRef.getDownloadURL();
      }

      // Firestoreに投稿データを書き込む
      await FirebaseFirestore.instance.collection('posts').add({
        'uid': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userAvatar': user.photoURL,
        'userLevel': level,
        'userClass': jobInfo.title,
        'text': text,
        'photoURL': photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
        'myQuestId': _selectedMyQuest?.id,
        'myQuestTitle': _selectedMyQuest?.title,
        'questCategory': questCategory,
        'timeSpentMinutes': timeSpent,
        'isBlessed': false,
        'isWisdomShared': _shareWisdom,
      });

      // ユーザーデータの更新（XP, Stats, 総努力時間）
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updates = <String, dynamic>{
        'xp': FieldValue.increment(10), // 基本XP
        'totalEffortMinutes': FieldValue.increment(timeSpent), // 総努力時間を加算
      };
      if (questCategory != null) {
        updates['stats.$questCategory'] = FieldValue.increment(1); // 基本Stat
      }
      // TODO: 努力時間に応じてXPやStatの増加量を調整するロジックをここに追加する

      await userRef.set(
          updates, SetOptions(merge: true)); // merge:true で既存フィールドを保持

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("投稿エラー: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canShareWisdom =
        (_myJobInfo?.title == '魔術師') && (_selectedMyQuest?.category == 'Study');

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedMyQuest != null
            ? '${_selectedMyQuest!.title} の記録'
            : 'マイクエストの記録'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: '努力した時間（分）',
                hintText: '例: 30',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: '今日の進捗や感想を記録...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            if (_imageFile != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                    onPressed: () => setState(() => _imageFile = null),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (canShareWisdom)
              CheckboxListTile(
                title: const Text("叡智の共有を有効にする"),
                subtitle: const Text("他の人がこの投稿を見ると、獲得コインが増えます。"),
                value: _shareWisdom,
                onChanged: (newValue) {
                  setState(() => _shareWisdom = newValue!);
                },
                secondary: const Icon(Icons.lightbulb_outline),
              ),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null, child: CircularProgressIndicator())
          : FloatingActionButton.extended(
              onPressed: _addPost,
              icon: const Icon(Icons.send),
              label: const Text('記録する'),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              tooltip: '写真を追加',
              onPressed: _pickImage,
            ),
            const SizedBox(width: 8),
            if (widget.initialQuest == null)
              ActionChip(
                avatar: Icon(Icons.flag_outlined,
                    color: _selectedMyQuest != null
                        ? Theme.of(context).primaryColor
                        : null,
                    size: 20),
                label: Text(
                  _selectedMyQuest != null
                      ? _selectedMyQuest!.title
                      : 'マイクエストを選択',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _showMyQuestPicker,
                backgroundColor: _selectedMyQuest != null
                    ? Theme.of(context).primaryColor.withOpacity(0.12)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _selectedMyQuest != null
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade400,
                    width: 1,
                  ),
                ),
              )
            else if (_selectedMyQuest != null)
              Chip(
                avatar: Icon(Icons.flag,
                    color: Theme.of(context).primaryColor, size: 20),
                label: Text(
                  _selectedMyQuest!.title,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
