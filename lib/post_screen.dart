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

  @override
  void initState() {
    super.initState();
    _fetchActiveQuests();
  }

  Future<void> _fetchActiveQuests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('my_quests')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();
    if (mounted) {
      final quests =
          snapshot.docs.map((doc) => MyQuest.fromFirestore(doc)).toList();
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
    if (user == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userProfile = userDoc.exists
          ? UserProfile.fromFirestore(userDoc)
          : UserProfile(uid: user.uid, xp: 0, stats: UserStats());
      final level = computeLevel(userProfile.xp);
      final classInfo = computeClass(userProfile.stats, level);

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
        'userClass': classInfo.title,
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
        'isBlessed': false, // isBlessedの初期値を追加
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
      print('投稿エラー: $e');
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
