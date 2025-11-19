// lib/timeline_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';
import 'cheer_list_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'widgets/post_content_widget.dart'; // 既存のインポートを確認してください

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
            final data = doc.data() as Map<String, dynamic>;
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
            'type': 'cheer',
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

  Future<void> _showDeleteConfirmDialog(String postId, String? photoURL) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('投稿の削除'),
          content: const Text('この投稿を本当に削除しますか？この操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('削除', style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deletePost(postId, photoURL);
    }
  }

  Future<void> _deletePost(String postId, String? photoURL) async {
    try {
      if (photoURL != null && photoURL.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(photoURL).delete();
      }
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を削除しました')),
        );
      }
    } catch (e) {
      print('投稿の削除に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  // ▼▼▼ タブの中身を生成するヘルパーメソッド ▼▼▼
  Widget _buildTimeline(BuildContext context,
      {required bool showShortPostsOnly}) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    final Set<String> feedUserIdsSet = {currentUserId, ..._friendIds};

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('投稿の取得に失敗しました'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだ投稿がありません。'));
        }

        // 全投稿をリスト化
        final allPosts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        // フィルタリング（フレンド かつ タブに応じた種類）
        final posts = allPosts.where((post) {
          // 1. フレンドかどうか
          if (!feedUserIdsSet.contains(post.uid)) return false;

          // 2. タブのフィルタ
          if (showShortPostsOnly) {
            // 「一言」タブ: isShortPost が true のものだけ
            return post.isShortPost;
          } else {
            // 「メイン」タブ: isShortPost が false (またはnull) のものだけ
            // ※ nullは false 扱いになっているはずですが念のため
            return !post.isShortPost;
          }
        }).toList();

        if (posts.isEmpty) {
          return Center(
            child: Text(showShortPostsOnly ? '一言投稿はまだありません' : '投稿はまだありません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
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
                  PostContentWidget(post: post),
                  _PostActions(
                    post: post,
                    isLiked: _likedPostIds.contains(post.id),
                    isMyPost: post.uid == _currentUserProfile?.uid,
                    onLike: () => _toggleLike(post.id),
                    onDelete: () =>
                        _showDeleteConfirmDialog(post.id, post.photoURL),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_isLoadingFriends ||
        _currentUserProfile == null ||
        currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MiniQuest')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ▼▼▼ DefaultTabController でラップしてタブを実装 ▼▼▼
    return DefaultTabController(
      length: 2, // タブの数
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MiniQuest'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'メイン'),
              Tab(text: '一言'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // タブ1: メイン（通常投稿）
            _buildTimeline(context, showShortPostsOnly: false),
            // タブ2: 一言（ショート投稿）
            _buildTimeline(context, showShortPostsOnly: true),
          ],
        ),
      ),
    );
    // ▲▲▲
  }
}

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

class _PostActions extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final bool isMyPost;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _PostActions({
    required this.post,
    required this.isLiked,
    required this.isMyPost,
    required this.onLike,
    required this.onDelete,
  });

  void _showLikeList(BuildContext context) {
    if (post.likeCount > 0) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CheerListScreen(postId: post.id),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Colors.grey[500]!;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                isLiked
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                color: isLiked ? accentColor : iconColor),
            onPressed: onLike,
          ),
          InkWell(
            onTap: () => _showLikeList(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(post.likeCount.toString(),
                  style: TextStyle(color: iconColor)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: iconColor),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CommentScreen(post: post))),
          ),
          Text(post.commentCount.toString(),
              style: TextStyle(color: iconColor)),
          if (isMyPost)
            IconButton(
              icon: Icon(Icons.more_vert, color: iconColor),
              onPressed: onDelete,
              tooltip: 'オプション',
            ),
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
