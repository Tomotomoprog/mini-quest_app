import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';
import 'models/ability.dart';
import 'utils/progression.dart';
import 'utils/ability_service.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';

class MyQuestDetailScreen extends StatefulWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  State<MyQuestDetailScreen> createState() => _MyQuestDetailScreenState();
}

class _MyQuestDetailScreenState extends State<MyQuestDetailScreen> {
  // タイムライン画面と同様に、ユーザー情報や「いいね」の状態を管理
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;
  JobResult? _myJobInfo;
  List<Ability> _myAbilities = [];
  final Map<String, String> _usedAbilitiesOnPosts = {};

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  // ログインユーザーの情報を取得する
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

  // いいねを切り替える処理
  Future<void> _toggleLike(String postId) async {
    // (timeline_screen.dartから処理を移植)
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

  // アビリティを使用する処理
  Future<void> _useAbility(Ability ability, Post post) async {
    // (timeline_screen.dartから処理を移植)
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quest.title),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _QuestDetailHeader(quest: widget.quest),
          ),
          // 冒険の記録（投稿リスト）
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('myQuestId', isEqualTo: widget.quest.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('このクエストに関する投稿はまだありません。'),
                )));
              }

              final posts = snapshot.data!.docs
                  .map((doc) => Post.fromFirestore(doc))
                  .toList();
              posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];
                    // ▼▼▼ タイムラインと同様のカードデザインに変更 ▼▼▼
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PostHeader(post: post),
                          _PostContent(post: post),
                          if (_currentUserProfile != null)
                            _PostActions(
                              post: post,
                              isLiked: _likedPostIds.contains(post.id),
                              myAbilities: _myAbilities,
                              isMyPost: post.uid == _currentUserProfile?.uid,
                              usedAbilityName: _usedAbilitiesOnPosts[post.id],
                              onLike: () => _toggleLike(post.id),
                              onUseAbility: (ability) =>
                                  _useAbility(ability, post),
                            ),
                        ],
                      ),
                    );
                    // ▲▲▲ タイムラインと同様のカードデザインに変更 ▲▲▲
                  },
                  childCount: posts.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- 以下、クエスト詳細と投稿カードを構成するウィジェット ---

class _QuestDetailHeader extends StatelessWidget {
  final MyQuest quest;
  const _QuestDetailHeader({required this.quest});

  // (中身は変更なし)
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Life':
        return Icons.home_outlined;
      case 'Study':
        return Icons.school_outlined;
      case 'Physical':
        return Icons.fitness_center_outlined;
      case 'Social':
        return Icons.people_outline;
      case 'Creative':
        return Icons.palette_outlined;
      case 'Mental':
        return Icons.self_improvement_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  Color _getColorForCategory(String category, BuildContext context) {
    switch (category) {
      case 'Life':
        return Colors.green;
      case 'Study':
        return Colors.blue;
      case 'Physical':
        return Colors.red;
      case 'Social':
        return Colors.pink;
      case 'Creative':
        return Colors.purple;
      case 'Mental':
        return Colors.indigo;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(quest.category, context);
    final icon = _getIconForCategory(quest.category);

    final startDate = DateTime.tryParse(quest.startDate) ?? DateTime.now();
    final endDate = DateTime.tryParse(quest.endDate) ?? DateTime.now();
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDuration = DateTime.now().difference(startDate).inDays;
    final progress = (totalDuration > 0)
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (quest.status == 'active')
            Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(quest.startDate.replaceAll('-', '/'),
                        style: Theme.of(context).textTheme.bodySmall),
                    Text('残り ${totalDuration - elapsedDuration} 日',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(quest.endDate.replaceAll('-', '/'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('意気込み:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text(quest.motivation,
                    style: const TextStyle(
                        fontSize: 16, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('冒険の記録',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- タイムラインから移植した投稿カード用ウィジェット ---

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
