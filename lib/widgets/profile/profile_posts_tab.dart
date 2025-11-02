// lib/widgets/profile/profile_posts_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/post.dart';
import '../../comment_screen.dart';
import '../../profile_screen.dart';
import '../../models/user_profile.dart';
// import 'utils/ability_service.dart'; // 削除済
import '../../utils/progression.dart';
// import 'models/ability.dart'; // 削除済

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

  @override
  Widget build(BuildContext context) {
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
          return const Center(child: Text('まだ投稿がありません。'));
        }

        final posts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

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
                  _PostContent(post: post),
                  _PostActions(
                    post: post,
                    isLiked: _likedPostIds.contains(post.id),
                    isMyPost: true,
                    onLike: () => _toggleLike(post.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Post post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: null,
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
                // ▼▼▼ ここが修正点です ▼▼▼
                child: Image.network(post.photoURL!,
                    width: double.infinity,
                    // height: 200, // ◀◀◀ この行を削除
                    fit: BoxFit.cover),
                // ▲▲▲
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
