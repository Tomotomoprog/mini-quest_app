import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'models/user_profile.dart';
import 'utils/ability_service.dart';
import 'utils/progression.dart';
import 'models/ability.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;
  JobResult? _myJobInfo;
  List<Ability> _myAbilities = [];

  // どの投稿にどのアビリティを使ったかを管理するMap
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
          _myJobInfo = jobInfo;
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

  // アビリティを使用する汎用的な関数
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
      case '不屈の激励':
        // TODO: 本来は相手のユーザーデータにバフをかける
        break;
      case '彩りの霊感':
        // TODO: 本来は相手に素材を付与する
        break;
      case '発見のコンパス':
        // TODO: 本来は相手のユーザーデータにバフをかける
        break;
      default:
        return;
    }

    // 画面に成功メッセージを表示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${post.userName}に「${ability.name}」を送りました！'),
        backgroundColor: Colors.green,
      ),
    );

    // アビリティ使用済みとしてUIを更新
    setState(() {
      _usedAbilitiesOnPosts[post.id] = ability.name;
    });
  }

  void _navigateToProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  // アビリティボタンを生成するウィジェット
  Widget _buildAbilityButton(Post post) {
    if (post.uid == _currentUserProfile?.uid || _myAbilities.isEmpty) {
      return const SizedBox.shrink();
    }

    final ability = _myAbilities.first; // 各ジョブのアビリティは1つと仮定
    final isAbilityUsed = _usedAbilitiesOnPosts.containsKey(post.id);

    // アビリティごとの特殊な状態を判定
    bool isDisabled =
        isAbilityUsed || (ability.name == '祝福の風' && post.isBlessed);
    String buttonText = isAbilityUsed ? '使用済み' : ability.name;
    IconData buttonIcon = ability.icon;
    Color? buttonColor;

    if (ability.name == '祝福の風' && post.isBlessed) {
      buttonText = '祝福済み';
      buttonIcon = Icons.star;
      buttonColor = Colors.amber;
    }

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: isDisabled
            ? buttonColor ?? Colors.grey
            : Theme.of(context).textTheme.bodySmall?.color,
      ),
      icon: Icon(buttonIcon),
      label: Text(buttonText),
      onPressed: isDisabled ? null : () => _useAbility(ability, post),
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

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isLikedByMe = _likedPostIds.contains(post.id);

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
                            // 魔術師の「叡智の共有」が使われている投稿にアイコンを表示
                            if (post.isWisdomShared) ...[
                              const Spacer(),
                              const Icon(Icons.lightbulb,
                                  color: Colors.deepPurple, size: 20),
                              const SizedBox(width: 4),
                              Text("叡智",
                                  style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ... (投稿内容の表示部分は変更なし)
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
                          _buildAbilityButton(post),
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
