import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/my_quest.dart';
import 'models/quest.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';

class PostScreen extends StatefulWidget {
  final Quest? dailyQuest;
  const PostScreen({super.key, this.dailyQuest});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;
  String? _selectedMyQuestId;
  List<MyQuest> _activeQuests = [];
  File? _imageFile;
  UserProfile? _currentUserProfile;
  JobResult? _myJobInfo;
  bool _shareWisdom = false; // 「叡智の共有」を使うかどうかのフラグ

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ユーザー情報とアクティブなクエストを並行して取得
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
        final profile = UserProfile.fromFirestore(userDoc);
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

  Future<void> _addPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUserProfile == null || _myJobInfo == null)
      return;
    final text = _textController.text.trim();
    if (text.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final level = computeLevel(_currentUserProfile!.xp);
      final jobInfo = _myJobInfo!;

      String? myQuestTitle;
      String? questCategory = widget.dailyQuest?.category;
      if (_selectedMyQuestId != null) {
        final quest =
            _activeQuests.firstWhere((q) => q.id == _selectedMyQuestId);
        myQuestTitle = quest.title;
        questCategory = quest.category;
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
        'myQuestId': _selectedMyQuestId,
        'myQuestTitle': myQuestTitle,
        'questId': widget.dailyQuest?.id,
        'questTitle': widget.dailyQuest?.title,
        'questCategory': questCategory,
        'isBlessed': false,
        'isWisdomShared': _shareWisdom, // 「叡智の共有」フラグを保存
      });

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updates = <String, dynamic>{'xp': FieldValue.increment(10)};
      if (questCategory != null) {
        updates['stats.$questCategory'] = FieldValue.increment(1);
      }
      await userRef.set(updates, SetOptions(merge: true));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
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
    // 魔術師かつ学習カテゴリの場合のみ「叡智の共有」チェックボックスを表示
    bool canShareWisdom = (_myJobInfo?.title == '魔術師') &&
        ((widget.dailyQuest?.category == 'Study') ||
            (_activeQuests
                    .firstWhere((q) => q.id == _selectedMyQuestId,
                        orElse: () => MyQuest(
                            id: '',
                            uid: '',
                            title: '',
                            motivation: '',
                            category: '',
                            status: '',
                            startDate: '',
                            endDate: '',
                            createdAt: Timestamp.now()))
                    .category ==
                'Study'));

    return Scaffold(
      appBar: AppBar(title: const Text('達成を投稿')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.dailyQuest != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(widget.dailyQuest!.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                  hintText: '今日の達成や進捗をシェア...', border: OutlineInputBorder()),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            if (_activeQuests.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedMyQuestId,
                decoration: const InputDecoration(
                    labelText: 'マイクエストに進捗を記録', border: OutlineInputBorder()),
                hint: const Text('（紐付けない）'),
                isExpanded: true,
                items: _activeQuests.map((MyQuest quest) {
                  return DropdownMenuItem<String>(
                    value: quest.id,
                    child: Text(quest.title, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedMyQuestId = newValue);
                },
              ),
            // ▼▼▼ 「叡智の共有」チェックボックス ▼▼▼
            if (canShareWisdom)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CheckboxListTile(
                  title: const Text("叡智の共有を有効にする"),
                  subtitle: const Text("他の人がこの投稿を見ると、獲得コインが増えます。"),
                  value: _shareWisdom,
                  onChanged: (newValue) {
                    setState(() {
                      _shareWisdom = newValue!;
                    });
                  },
                  secondary: const Icon(Icons.lightbulb_outline),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera)),
                const Spacer(),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _addPost, child: const Text('投稿する')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
