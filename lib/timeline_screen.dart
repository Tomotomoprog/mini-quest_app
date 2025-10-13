import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'models/user_profile.dart'; // UserProfileモデルをインポート
import 'utils/progression.dart'; // progressionロジックをインポート

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  Future<void> _fetchMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 自分の「いいね」とプロフィール情報を並行して取得
    await Future.wait([
      FirebaseFirestore.instance
          .collectionGroup('likes')
          .where('uid', isEqualTo: user.uid)
          .get()
          .then((snapshot) {
        if (mounted)
          setState(() => _likedPostIds = snapshot.docs
              .map((doc) => doc.reference.parent.parent!.id)
              .toSet());
      }),
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((snapshot) {
        if (mounted && snapshot.exists)
          setState(
              () => _currentUserProfile = UserProfile.fromFirestore(snapshot));
      }),
    ]);
  }

  Future<void> _toggleLike(String postId) async {
    // ... (この部分は変更なし)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);
    final isLiked = _likedPostIds.contains(postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      if (isLiked) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        transaction.set(likeRef,
            {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
    setState(() {
      if (isLiked) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
    });
  }

  // ▼▼▼ 「祝福の風」アビリティを使用する処理 ▼▼▼
  Future<void> _useBlessingWind(Post post) async {
    if (post.isBlessed) return; // すでに祝福済みなら何もしない

    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final targetUserRef =
        FirebaseFirestore.instance.collection('users').doc(post.uid);

    // トランザクションで安全に更新
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(postRef, {'isBlessed': true});
      // 設計案通り、XPを50%増やす（基本が10XPなので+5XP）
      transaction.set(targetUserRef, {'xp': FieldValue.increment(5)},
          SetOptions(merge: true));
    });

    // TODO: アビリティに使用回数制限などを設ける場合はここに追加
  }

  void _navigateToProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('タイムライン')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _currentUserProfile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだ投稿がありません。'));
          }

          final posts = snapshot.data!.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();
          final myLevel = computeLevel(_currentUserProfile!.xp);
          final myClassInfo = computeClass(_currentUserProfile!.stats, myLevel);

          // 自分がヒーラー系のクラスか判定
          final canUseBlessing = ['Healer', 'Priest', 'Bard']
              .any((c) => myClassInfo.title.contains(c));

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isLikedByMe = _likedPostIds.contains(post.id);
              final isMyPost = post.uid == _currentUserProfile!.uid;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(post.uid),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: post.userAvatar != null
                                  ? NetworkImage(post.userAvatar!)
                                  : null,
                              child: post.userAvatar == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.userName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Text('Lv.${post.userLevel}・${post.userClass}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // (投稿内容の表示部分は変更なし)
                      if (post.myQuestTitle != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('🚀 ${post.myQuestTitle}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800)),
                        ),
                      if (post.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(post.text,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ),
                      if (post.photoURL != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(post.photoURL!,
                              width: double.infinity, fit: BoxFit.cover),
                        ),

                      const Divider(height: 24),

                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: isLikedByMe
                                    ? Colors.red
                                    : Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color),
                            icon: Icon(isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border),
                            label: Text(post.likeCount.toString()),
                            onPressed: () => _toggleLike(post.id),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(post.commentCount.toString()),
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        CommentScreen(post: post))),
                          ),

                          // ▼▼▼ アビリティボタンの表示ロジック ▼▼▼
                          if (canUseBlessing && !isMyPost)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: post.isBlessed
                                      ? Colors.amber
                                      : Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color),
                              icon: Icon(post.isBlessed
                                  ? Icons.star
                                  : Icons.star_border),
                              label: Text(post.isBlessed ? '祝福済み' : '祝福'),
                              onPressed: post.isBlessed
                                  ? null
                                  : () => _useBlessingWind(post),
                            ),

                          const Spacer(),
                          Text(
                              DateFormat('MM/dd HH:mm')
                                  .format(post.createdAt.toDate()),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
