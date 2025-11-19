import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/my_quest.dart';
import 'models/quest.dart';
import 'models/user_profile.dart' as model; // エイリアスを使用
import 'utils/progression.dart';

// ヘルパー関数（クラス外または共通のユーティリティファイルに追加）
bool _isSameDate(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

class PostScreen extends StatefulWidget {
  final Quest? dailyQuest;
  const PostScreen({super.key, this.dailyQuest});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _textController = TextEditingController();
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
                child: Text('マイクエストに紐付ける',
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
    if (text.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿内容を入力するか、写真を選択してください。')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final level = computeLevel(_currentUserProfile!.xp);
      final jobInfo = _myJobInfo!;

      String? questCategory = widget.dailyQuest?.category;
      if (_selectedMyQuest != null) {
        questCategory = _selectedMyQuest!.category;
      }

      String? photoURL;
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_imageFile!);
        photoURL = await storageRef.getDownloadURL();
      }

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
        'questId': widget.dailyQuest?.id,
        'questTitle': widget.dailyQuest?.title,
        'questCategory': questCategory,
        'isBlessed': false,
        'isWisdomShared': _shareWisdom,
        // timeSpentMinutes はここでは追加しない
      });

      // --- 連続記録更新ロジック START ---
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception("ユーザードキュメントが存在しません！");
        }
        final currentProfile = model.UserProfile.fromFirestore(userSnapshot);

        int currentStreak = currentProfile.currentStreak;
        int longestStreak = currentProfile.longestStreak;
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);

        DateTime? lastPostDateTime;
        if (currentProfile.lastPostDate != null) {
          lastPostDateTime = currentProfile.lastPostDate!.toDate();
          final DateTime lastPostDay = DateTime(lastPostDateTime.year,
              lastPostDateTime.month, lastPostDateTime.day);
          final DateTime yesterday = today.subtract(const Duration(days: 1));

          if (_isSameDate(lastPostDay, today)) {
            // Streak doesn't change
          } else if (_isSameDate(lastPostDay, yesterday)) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
        } else {
          currentStreak = 1;
        }

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        final updates = <String, dynamic>{
          'xp': FieldValue.increment(10),
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'lastPostDate': Timestamp.fromDate(now),
        };
        if (questCategory != null) {
          updates['stats.$questCategory'] = FieldValue.increment(1);
        }

        transaction.set(userRef, updates, SetOptions(merge: true));
      });
      // --- 連続記録更新ロジック END ---

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("投稿エラー: $e"); // エラーログ表示
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getHintText() {
    final category = widget.dailyQuest?.category ?? _selectedMyQuest?.category;
    switch (category) {
      case 'Study':
        return '何を学びましたか？';
      case 'Physical':
        return 'どんな運動をしましたか？';
      case 'Life':
        return 'どんな素敵なことがありましたか？';
      default:
        return '今日の達成や進捗をシェア...';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canShareWisdom = (_myJobInfo?.title == '魔術師') &&
        ((widget.dailyQuest?.category == 'Study') ||
            (_selectedMyQuest?.category == 'Study'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('冒険の記録'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            16.0, 16.0, 16.0, 100.0), // FABのためのスペースを確保
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.dailyQuest != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.star_outline, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text("今日のクエスト: ${widget.dailyQuest!.title}",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _getHintText(),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 8,
            ),
            // ▼▼▼ 変更点: テキスト入力のすぐ下に操作ボタンを配置 ▼▼▼
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera_outlined),
                  tooltip: '写真を追加',
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(Icons.flag_outlined,
                      color: _selectedMyQuest != null
                          ? Theme.of(context).primaryColor
                          : null,
                      size: 20),
                  label: Text(
                    _selectedMyQuest != null
                        ? _selectedMyQuest!.title
                        : 'マイクエストに紐付ける',
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
                ),
              ],
            ),
            // ▲▲▲ 変更点終了 ▲▲▲
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
              label: const Text('投稿する'),
            ),
      // ▼▼▼ 変更点: BottomNavigationBar を削除 ▼▼▼
      // bottomNavigationBar: BottomAppBar(...),
    );
  }
}
