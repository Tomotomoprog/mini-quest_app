import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../models/ability.dart';
import '../../utils/progression.dart';
import '../../utils/ability_service.dart';
import '../../comment_screen.dart';
import '../../profile_screen.dart';

class ProfilePostsTab extends StatefulWidget {
  final String userId;
  const ProfilePostsTab({super.key, required this.userId});

  @override
  State<ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends State<ProfilePostsTab> {
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;
  List<Ability> _myAbilities = [];
  final Map<String, String> _usedAbilitiesOnPosts = {};

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
        final level = computeLevel(profile.xp);
        final jobInfo = computeJob(profile.stats, level);
        setState(() {
          _currentUserProfile = profile;
          _myAbilities = AbilityService.getAbilitiesForClass(jobInfo.title);
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

  Future<void> _useAbility(Ability ability, Post post) async {
    final targetUserRef =
        FirebaseFirestore.instance.collection('users').doc(post.uid);

    switch (ability.name) {
      case '祝福の風':
        if (post.isBlessed) return;
        final postRef =
            FirebaseFirestore.instance.collection('posts').doc(post.id);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(postRef, {'isBlessed': true});
          transaction.set(targetUserRef, {'xp': FieldValue.increment(5)},
              SetOptions(merge: true));
        });
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${post.userName}に「${ability.name}」を送りました！'),
        backgroundColor: Colors.green,
      ),
    );

    setState(() {
      _usedAbilitiesOnPosts[post.id] = ability.name;
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
        if (!snapshot.hasData || _currentUserProfile == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだ投稿がありません。'));
        }

        final posts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                    myAbilities: _myAbilities,
                    isMyPost: post.uid == _currentUserProfile?.uid,
                    usedAbilityName: _usedAbilitiesOnPosts[post.id],
                    onLike: () => _toggleLike(post.id),
                    onUseAbility: (ability) => _useAbility(ability, post),
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
              const Row(
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.deepPurpleAccent, size: 18),
                  SizedBox(width: 4),
                  Text("叡智",
                      style: TextStyle(
                          color: Colors.deepPurpleAccent,
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200)),
              child: Text('🚀 ${post.myQuestTitle}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
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
  final List<Ability> myAbilities;
  final String? usedAbilityName;
  final VoidCallback onLike;
  final Function(Ability) onUseAbility;

  const _PostActions({
    required this.post,
    required this.isLiked,
    required this.isMyPost,
    required this.myAbilities,
    this.usedAbilityName,
    required this.onLike,
    required this.onUseAbility,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.redAccent : Colors.grey[600]),
            onPressed: onLike,
          ),
          Text(post.likeCount.toString(),
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[600]),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CommentScreen(post: post))),
          ),
          Text(post.commentCount.toString(),
              style: TextStyle(color: Colors.grey[600])),
          if (!isMyPost && myAbilities.isNotEmpty) _buildAbilityButton(context),
          const Spacer(),
          Text(
            DateFormat('M/d HH:mm').format(post.createdAt.toDate()),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAbilityButton(BuildContext context) {
    final ability = myAbilities.first;
    final bool isUsed = usedAbilityName == ability.name;
    bool isDisabledByState =
        isUsed || (ability.name == '祝福の風' && post.isBlessed);

    IconData icon = ability.icon;
    Color? color;

    if (ability.name == '祝福の風' && post.isBlessed) {
      icon = Icons.star;
      color = Colors.amber;
    }

    return IconButton(
      icon: Icon(icon,
          color: isDisabledByState
              ? color ?? Colors.grey
              : Theme.of(context).colorScheme.primary),
      tooltip: ability.name,
      onPressed: isDisabledByState ? null : () => onUseAbility(ability),
    );
  }
}
