// lib/my_quest_detail_screen.dart
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
import 'my_quest_post_screen.dart'; // ← 新しい画面をインポート

class MyQuestDetailScreen extends StatefulWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  State<MyQuestDetailScreen> createState() => _MyQuestDetailScreenState();
}

class _MyQuestDetailScreenState extends State<MyQuestDetailScreen> {
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
      final postSnapshot = await transaction.get(postRef); // Postデータを取得
      if (!postSnapshot.exists) return;
      final post = Post.fromFirestore(postSnapshot);
      final shouldNotify = !isLiked && post.uid != user.uid; // 通知が必要か判断

      if (isLiked) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        transaction.set(likeRef,
            {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
        // 通知を作成 (shouldNotifyがtrueの場合)
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
            'targetUserId': post.uid, // 投稿主のID
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
      // 他のアビリティの処理が必要な場合はここに追加
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

  Future<void> _completeQuest() async {
    try {
      await FirebaseFirestore.instance
          .collection('my_quests')
          .doc(widget.quest.id)
          .update({'status': 'completed'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('クエスト達成！おめでとうございます！'), backgroundColor: Colors.green),
      );
      // setStateは不要（StreamBuilderが自動で更新するため）
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _deleteQuest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('クエストを削除'),
          content: const Text('このマイクエストを本当に削除しますか？\n関連する投稿は削除されません。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('削除', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('my_quests')
            .doc(widget.quest.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('クエストを削除しました。')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除中にエラーが発生しました: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quest.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'クエストを削除',
            onPressed: _deleteQuest,
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80), // ボタンの高さを考慮
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QuestDetailHeader(quest: widget.quest), // ヘッダー
                // ポストリストを表示するためのStreamBuilder
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('myQuestId', isEqualTo: widget.quest.id)
                      .orderBy('createdAt', descending: true) // 新しい順にソート
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      // エラーハンドリングを追加
                      return Center(
                          child: Text('投稿の読み込みに失敗しました: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('このクエストに関する投稿はまだありません。'),
                        ),
                      );
                    }

                    final posts = snapshot.data!.docs
                        .map((doc) => Post.fromFirestore(doc))
                        .toList();
                    // posts.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Firestore側でソートするので不要

                    // Columnを使って複数の投稿カードを表示
                    return Column(
                      children: posts
                              .map((post) => Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 8.0),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _PostHeader(post: post),
                                        _PostContent(post: post),
                                        if (_currentUserProfile != null)
                                          _PostActions(
                                            post: post,
                                            isLiked:
                                                _likedPostIds.contains(post.id),
                                            myAbilities: _myAbilities,
                                            isMyPost: post.uid ==
                                                _currentUserProfile?.uid,
                                            usedAbilityName:
                                                _usedAbilitiesOnPosts[post.id],
                                            onLike: () => _toggleLike(post.id),
                                            onUseAbility: (ability) =>
                                                _useAbility(ability, post),
                                          ),
                                      ],
                                    ),
                                  ))
                              .toList() ?? // postsがnullの場合も考慮 (Firestore streamでは通常不要だが念のため)
                          [],
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),

      // ▼▼▼ FABを追加 ▼▼▼
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('my_quests')
              .doc(widget.quest.id)
              .snapshots(),
          builder: (context, questSnapshot) {
            if (!questSnapshot.hasData) return const SizedBox.shrink();
            final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);
            // 挑戦中の場合のみ記録ボタンを表示
            if (currentQuest.status == 'active') {
              return FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => MyQuestPostScreen(
                          initialQuest: widget.quest) // このクエストを渡す
                      ));
                },
                icon: const Icon(Icons.add_task),
                label: const Text('進捗を記録'),
              );
            } else {
              return const SizedBox.shrink(); // 達成済みならボタン非表示
            }
          }),
      // ▲▲▲ FABを追加 ▲▲▲

      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('my_quests')
              .doc(widget.quest.id)
              .snapshots(),
          builder: (context, questSnapshot) {
            if (!questSnapshot.hasData)
              return const SizedBox.shrink(); // データがない場合は何も表示しない
            final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);

            // 挑戦中の場合のみ達成ボタンを表示
            if (currentQuest.status == 'active') {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('目標を達成済みにする'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _completeQuest,
                ),
              );
            } else {
              // 達成済みの場合はメッセージ表示
              return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                      child: Chip(
                    label: Text('🎉 この目標は達成済みです！',
                        style: TextStyle(color: Colors.green[800])),
                    backgroundColor: Colors.green[100],
                    avatar: Icon(Icons.emoji_events, color: Colors.green[800]),
                  )));
            }
          }),
    );
  }
}

// --- 以下、変更なしのウィジェット ---

class _QuestDetailHeader extends StatelessWidget {
  final MyQuest quest;
  const _QuestDetailHeader({required this.quest});

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
    final elapsedDuration = DateTime.now()
        .difference(startDate)
        .inDays
        .clamp(0, totalDuration); // 経過日数が負または合計を超えないように
    final progress = (totalDuration > 0)
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;
    final remainingDays = totalDuration - elapsedDuration;

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
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(quest.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final currentQuest = MyQuest.fromFirestore(snapshot.data!);
                if (currentQuest.status == 'active') {
                  return Column(
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
                          Text(
                              remainingDays >= 0
                                  ? '残り $remainingDays 日'
                                  : '期間終了', // 終了日を過ぎていたら表示変更
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(quest.endDate.replaceAll('-', '/'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Text(
                    '期間: ${quest.startDate.replaceAll('-', '/')} 〜 ${quest.endDate.replaceAll('-', '/')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
              }),
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
            if (post.isWisdomShared) // 叡智の共有アイコン表示
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
            // 時間表示を追加
            else if (post.timeSpentHours != null && post.timeSpentHours! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post.timeSpentHours}分',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
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
          // myQuestTitleの表示は削除（詳細画面なので不要）
          // if (post.myQuestTitle != null) ...
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
          // 自分の投稿でなく、かつ自分がアビリティを持っている場合のみボタン表示
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
    // 使えるアビリティが複数ある場合、選択式にする必要があるが、
    // 現状は各クラス1つなので、最初のものを表示する
    if (myAbilities.isEmpty) return const SizedBox.shrink();

    final ability = myAbilities.first;
    final bool isUsed = usedAbilityName == ability.name;
    // アビリティ使用不可条件
    bool isDisabledByState =
        isUsed || (ability.name == '祝福の風' && post.isBlessed);

    IconData icon = ability.icon;
    Color? color;

    // 祝福済みの場合の表示調整
    if (ability.name == '祝福の風' && post.isBlessed) {
      icon = Icons.star; // 祝福済みアイコン
      color = Colors.amber; // 祝福済み色
      isDisabledByState = true; // 祝福済みなら押せない
    }

    return IconButton(
      icon: Icon(icon,
          color: isDisabledByState
              ? color ?? Colors.grey // 無効状態の色
              : Theme.of(context).colorScheme.primary), // 有効状態の色
      tooltip: ability.name,
      onPressed:
          isDisabledByState ? null : () => onUseAbility(ability), // 無効なら押せない
    );
  }
}
