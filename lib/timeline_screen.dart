import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;

  List<String> _friendIds = [];
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  Future<void> _fetchMyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingFriends = false);
      return;
    }

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final likesFuture = FirebaseFirestore.instance
        .collectionGroup('likes')
        .where('uid', isEqualTo: user.uid)
        .get();

    final friendsFuture = FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: user.uid)
        .where('status', isEqualTo: 'accepted')
        .get();

    final responses =
        await Future.wait([userDocFuture, likesFuture, friendsFuture]);

    final userDoc = responses[0] as DocumentSnapshot;
    final likesSnapshot = responses[1] as QuerySnapshot;
    final friendsSnapshot = responses[2] as QuerySnapshot;

    if (mounted) {
      if (userDoc.exists) {
        final profile = UserProfile.fromFirestore(userDoc);
        setState(() {
          _currentUserProfile = profile;
        });
      }

      setState(() {
        _likedPostIds = likesSnapshot.docs
            .map((doc) => doc.reference.parent.parent!.id)
            .toSet();
      });

      final friendIds = friendsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>; // data() をキャスト
            final userIds = data['userIds'] as List;
            return userIds.firstWhere((id) => id != user.uid,
                orElse: () => null);
          })
          .where((id) => id != null)
          .toList();

      setState(() {
        _friendIds = friendIds.cast<String>();
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _toggleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);
    final isLiked = _likedPostIds.contains(postId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;

      final post = Post.fromFirestore(postSnapshot);
      final shouldNotify = !isLiked && post.uid != user.uid;

      if (isLiked) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        transaction.set(likeRef,
            {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});

        if (shouldNotify) {
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          transaction.set(notificationRef, {
            'type': 'like',
            'fromUserId': user.uid,
            'fromUserName': user.displayName ?? '名無しさん',
            'fromUserAvatar': user.photoURL,
            'postId': post.id,
            'postTextSnippet': post.text.length > 50
                ? '${post.text.substring(0, 50)}...'
                : post.text,
            'targetUserId': post.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_isLoadingFriends ||
        _currentUserProfile == null ||
        currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MiniQuest'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ▼▼▼ 自分のIDとフレンドIDをSet(集合)にする ▼▼▼
    // Set を使うことで .contains() のチェックが高速になります
    final Set<String> feedUserIdsSet = {currentUserId, ..._friendIds};
    // ▲▲▲

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ▼▼▼ クエリを単純な「最新順」のみに変更 ▼▼▼
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(100) // 投稿が多すぎるとアプリが重くなるため、最新100件に制限
            .snapshots(),
        // ▲▲▲
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("タイムライン エラー: ${snapshot.error}");
            return const Center(child: Text('投稿の取得に失敗しました'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('まだ投稿がありません。'));
          }

          // ▼▼▼ 取得した全投稿を、クライアント側でフィルタリング ▼▼▼
          final allPosts = snapshot.data!.docs
              .map((doc) => Post.fromFirestore(doc))
              .toList();

          final posts = allPosts.where((post) {
            // 投稿のUIDが、自分またはフレンドのIDセットに含まれているか
            return feedUserIdsSet.contains(post.uid);
          }).toList();
          // ▲▲▲

          // ▼▼▼ フィルタリング後の投稿が0件の場合の表示 ▼▼▼
          if (posts.isEmpty) {
            return const Center(child: Text('フレンドの投稿はまだありません。'));
          }
          // ▲▲▲

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            itemCount: posts.length, // フィルタリング後のリストを使用
            itemBuilder: (context, index) {
              final post = posts[index]; // フィルタリング後のリストを使用
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostHeader(post: post),
                    _PostContent(post: post),
                    _PostActions(
                      post: post,
                      isLiked: _likedPostIds.contains(post.id),
                      isMyPost: post.uid == _currentUserProfile?.uid,
                      onLike: () => _toggleLike(post.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// (これ以下の _PostHeader, _PostContent, _PostActions ウィジェットは変更ありません)
class _PostHeader extends StatelessWidget {
  final Post post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: post.uid)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: post.userAvatar != null
                  ? NetworkImage(post.userAvatar!)
                  : null,
              child: post.userAvatar == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Lv.${post.userLevel}・${post.userClass}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (post.isWisdomShared)
              Row(
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.deepPurpleAccent.shade100, size: 18),
                  const SizedBox(width: 4),
                  Text("叡智",
                      style: TextStyle(
                          color: Colors.deepPurpleAccent.shade100,
                          fontWeight: FontWeight.bold)),
                ],
              )
          ],
        ),
      ),
    );
  }
}

class _PostContent extends StatelessWidget {
  final Post post;
  const _PostContent({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.myQuestTitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: Colors.blue.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade700)),
              child: Text('🚀 ${post.myQuestTitle}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade100,
                      fontSize: 12)),
            ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(post.text,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          if (post.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(post.photoURL!,
                    width: double.infinity, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final bool isMyPost;
  final VoidCallback onLike;

  const _PostActions({
    required this.post,
    required this.isLiked,
    required this.isMyPost,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Colors.grey[500]!;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? accentColor : iconColor),
            onPressed: onLike,
          ),
          Text(post.likeCount.toString(), style: TextStyle(color: iconColor)),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: iconColor),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CommentScreen(post: post))),
          ),
          Text(post.commentCount.toString(),
              style: TextStyle(color: iconColor)),
          const Spacer(),
          Text(
            DateFormat('M/d HH:mm').format(post.createdAt.toDate()),
            style: TextStyle(color: iconColor, fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
