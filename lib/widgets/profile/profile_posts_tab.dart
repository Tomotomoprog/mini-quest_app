// lib/widgets/profile/profile_posts_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../comment_screen.dart';
import '../../cheer_list_screen.dart';
import '../post_content_widget.dart'; // 共通ウィジェット

class ProfilePostsTab extends StatefulWidget {
  final String userId;
  const ProfilePostsTab({super.key, required this.userId});

  @override
  State<ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends State<ProfilePostsTab> {
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

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final likesFuture = FirebaseFirestore.instance
        .collectionGroup('likes')
        .where('uid', isEqualTo: user.uid)
        .get();

    final responses = await Future.wait([userDocFuture, likesFuture]);

    final userDoc = responses[0] as DocumentSnapshot;
    final likesSnapshot = responses[1] as QuerySnapshot;

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

  // タブごとのリストを構築するメソッド
  Widget _buildPostList(bool showShortPostsOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _currentUserProfile == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(showShortPostsOnly ? '一言投稿はありません' : '投稿はありません'),
          );
        }

        // 全データを取得してからフィルタリング
        final allPosts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        final posts = allPosts.where((post) {
          if (showShortPostsOnly) {
            return post.isShortPost;
          } else {
            return !post.isShortPost;
          }
        }).toList();

        if (posts.isEmpty) {
          return Center(
            child: Text(showShortPostsOnly ? '一言投稿はありません' : '投稿はありません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isMyPost = post.uid == _currentUserProfile?.uid;
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
                  PostContentWidget(post: post), // 共通ウィジェット
                  _PostActions(
                    post: post,
                    isLiked: _likedPostIds.contains(post.id),
                    isMyPost: isMyPost,
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

  @override
  Widget build(BuildContext context) {
    // タブコントローラーを埋め込む
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'メイン'),
              Tab(text: '一言'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPostList(false), // メイン投稿
                _buildPostList(true), // 一言投稿
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Post post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: null, // プロフィール内なのでタップ無効でOK（遷移先が自分になるため）
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
