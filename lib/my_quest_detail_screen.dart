// lib/my_quest_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';
import 'models/friendship.dart'; // ◀◀◀ インポート
import 'utils/progression.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'my_quest_post_screen.dart';

class MyQuestDetailScreen extends StatefulWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  State<MyQuestDetailScreen> createState() => _MyQuestDetailScreenState();
}

// ▼▼▼ StatefulWidget に変更し、State を定義 ▼▼▼
class _MyQuestDetailScreenState extends State<MyQuestDetailScreen> {
  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;

  // ▼▼▼ 状態変数を追加 ▼▼▼
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  bool _isLoadingStatus = true;
  String? _myId;
  // ▲▲▲

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _fetchMyDataAndFriendship();
  }

  // ▼▼▼ フレンド関係も同時にチェックするロジックに変更 ▼▼▼
  Future<void> _fetchMyDataAndFriendship() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingStatus = false);
      return;
    }

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final likesFuture = FirebaseFirestore.instance
        .collectionGroup('likes')
        .where('uid', isEqualTo: user.uid)
        .get();

    final responses = await Future.wait([
      userDocFuture,
      likesFuture,
      _checkFriendshipStatus(), // ◀◀◀ フレンドステータスをチェック
    ]);

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
        _isLoadingStatus = false; // すべての読み込みが完了
      });
    }
  }

  // フレンドステータスを確認する関数
  Future<FriendshipStatus> _checkFriendshipStatus() async {
    final otherId = widget.quest.uid;

    if (_myId == null) return FriendshipStatus.none;
    if (_myId == otherId) return FriendshipStatus.accepted; // 自分のクエスト

    final db = FirebaseFirestore.instance;
    final query = db
        .collection('friendships')
        .where('userIds', arrayContains: _myId)
        // .where('userIds', arrayContains: otherId) // whereIn/arrayContainsは1回まで
        .get();

    final results = await query;

    FriendshipStatus status = FriendshipStatus.none;

    for (var doc in results.docs) {
      final userIds = doc.data()['userIds'] as List;
      if (userIds.contains(otherId)) {
        final docStatus = doc.data()['status'] as String;
        if (docStatus == 'accepted') {
          status = FriendshipStatus.accepted;
          break; // 承認済みが最優先
        } else if (docStatus == 'pending' || docStatus == 'quest_pending') {
          status = FriendshipStatus.pending; // 申請中
        }
      }
    }

    if (mounted) {
      setState(() {
        _friendshipStatus = status;
      });
    }
    return status;
  }
  // ▲▲▲

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

  // ▼▼▼ クエスト経由のフレンド申請ロジック ▼▼▼
  Future<void> _sendQuestFriendRequest() async {
    if (_myId == null) return;

    setState(() => _isLoadingStatus = true); // ボタンをローディング中に

    try {
      await FirebaseFirestore.instance.collection('friendships').add({
        'senderId': _myId,
        'receiverId': widget.quest.uid,
        'status': 'quest_pending', // ◀◀◀ クエスト経由の申請
        'createdAt': FieldValue.serverTimestamp(),
        'userIds': [_myId, widget.quest.uid],
      });

      if (mounted) {
        setState(() {
          _friendshipStatus = FriendshipStatus.pending; // 申請中ステータスに変更
          _isLoadingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フレンド申請を送信しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('申請に失敗しました: $e')),
        );
      }
    }
  }
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ 自分のクエストかどうかを判定 ▼▼▼
    final bool isMyQuest = widget.quest.uid == _myId;
    final bool isFriendOrMyQuest =
        isMyQuest || _friendshipStatus == FriendshipStatus.accepted;
    // ▲▲▲

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quest.title),
        actions: [
          // ▼▼▼ 自分のクエストの場合のみ削除ボタンを表示 ▼▼▼
          if (isMyQuest)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'クエストを削除',
              onPressed: _deleteQuest,
            )
          // ▲▲▲
        ],
      ),
      body: _isLoadingStatus // 読み込み中は全体をローダーにする
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ▼▼▼ ヘッダーに状態を渡す ▼▼▼
                      _QuestDetailHeader(
                        quest: widget.quest,
                        isFriendOrMyQuest: isFriendOrMyQuest,
                        friendshipStatus: _friendshipStatus,
                        onSendRequest: _sendQuestFriendRequest,
                      ),
                      // ▲▲▲
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('myQuestId', isEqualTo: widget.quest.id)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child:
                                    Text('投稿の読み込みに失敗しました: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
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
                                          // ▼▼▼ ポストヘッダーにも状態を渡す ▼▼▼
                                          _PostHeader(
                                            post: post,
                                            isFriendOrMyQuest:
                                                isFriendOrMyQuest,
                                          ),
                                          // ▲▲▲
                                          _PostContent(post: post),
                                          if (_currentUserProfile != null)
                                            _PostActions(
                                              post: post,
                                              isLiked: _likedPostIds
                                                  .contains(post.id),
                                              onLike: () =>
                                                  _toggleLike(post.id),
                                            ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),

      // ▼▼▼ 自分のクエストの場合のみ FAB を表示 ▼▼▼
      floatingActionButton: isMyQuest
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(widget.quest.id)
                  .snapshots(),
              builder: (context, questSnapshot) {
                if (!questSnapshot.hasData) return const SizedBox.shrink();
                final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);

                if (currentQuest.status == 'active') {
                  return FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              MyQuestPostScreen(initialQuest: widget.quest)));
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('進捗を記録'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  );
                } else {
                  return const SizedBox.shrink();
                }
              })
          : null, // 自分のクエストでなければ null
      // ▲▲▲

      // ▼▼▼ 自分のクエストの場合のみボトムバーを表示 ▼▼▼
      bottomNavigationBar: isMyQuest
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(widget.quest.id)
                  .snapshots(),
              builder: (context, questSnapshot) {
                if (!questSnapshot.hasData) return const SizedBox.shrink();
                final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);

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
                  return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                          child: Chip(
                        label: Text('🎉 この目標は達成済みです！',
                            style: TextStyle(color: Colors.green[100])),
                        backgroundColor: Colors.green[800]?.withOpacity(0.5),
                        avatar:
                            Icon(Icons.emoji_events, color: Colors.green[100]),
                      )));
                }
              })
          : null, // 自分のクエストでなければ null
      // ▲▲▲
    );
  }
}

// --- ヘッダーウィジェット ---

class _QuestDetailHeader extends StatelessWidget {
  final MyQuest quest;
  // ▼▼▼ 引数を追加 ▼▼▼
  final bool isFriendOrMyQuest;
  final FriendshipStatus friendshipStatus;
  final VoidCallback onSendRequest;
  // ▲▲▲
  const _QuestDetailHeader({
    required this.quest,
    required this.isFriendOrMyQuest,
    required this.friendshipStatus,
    required this.onSendRequest,
  });

  Color _getColorForCategory(String category, BuildContext context) {
    switch (category) {
      case 'Life':
        return Colors.green.shade400;
      case 'Study':
        return Colors.blue.shade400;
      case 'Physical':
        return Colors.red.shade400;
      case 'Social':
        return Colors.pink.shade400;
      case 'Creative':
        return Colors.purple.shade400;
      case 'Mental':
        return Colors.indigo.shade400;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(quest.category, context);
    final icon = _getIconForCategory(quest.category);
    final secondaryTextColor = Colors.grey[400]!;

    final startDate = DateTime.tryParse(quest.startDate) ?? DateTime.now();
    final endDate = DateTime.tryParse(quest.endDate) ?? DateTime.now();
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDuration =
        DateTime.now().difference(startDate).inDays.clamp(0, totalDuration);
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ▼▼▼ 投稿者情報とフレンド申請ボタン ▼▼▼
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    (isFriendOrMyQuest && quest.userPhotoURL != null)
                        ? NetworkImage(quest.userPhotoURL!)
                        : null,
                child: (!isFriendOrMyQuest || quest.userPhotoURL == null)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFriendOrMyQuest ? quest.userName : '匿名の冒険者',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isFriendOrMyQuest
                            ? Colors.white
                            : secondaryTextColor,
                        fontWeight: isFriendOrMyQuest
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                ),
              ),
              // フレンド申請ボタン
              if (!isFriendOrMyQuest)
                ElevatedButton.icon(
                  icon: Icon(
                      friendshipStatus == FriendshipStatus.none
                          ? Icons.person_add_alt_1
                          : Icons.check,
                      size: 16),
                  label: Text(
                      friendshipStatus == FriendshipStatus.none ? '申請' : '申請中'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friendshipStatus == FriendshipStatus.none
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: friendshipStatus == FriendshipStatus.none
                      ? onSendRequest // 申請中でなければ押せる
                      : null, // 申請中なら押せない
                ),
            ],
          ),
          // ▲▲▲
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(quest.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  if (quest.status == 'active') {
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: secondaryTextColor)),
                            Text(
                                remainingDays >= 0
                                    ? '残り $remainingDays 日'
                                    : '期間終了',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text(quest.endDate.replaceAll('-', '/'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: secondaryTextColor)),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Text(
                      '期間: ${quest.startDate.replaceAll('-', '/')} 〜 ${quest.endDate.replaceAll('-', '/')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: secondaryTextColor),
                    );
                  }
                }

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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: secondaryTextColor)),
                          Text(
                              remainingDays >= 0
                                  ? '残り $remainingDays 日'
                                  : '期間終了',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(quest.endDate.replaceAll('-', '/'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: secondaryTextColor)),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Text(
                    '期間: ${quest.startDate.replaceAll('-', '/')} 〜 ${quest.endDate.replaceAll('-', '/')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryTextColor),
                  );
                }
              }),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('意気込み:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                    )),
                const SizedBox(height: 4),
                Text(quest.motivation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    )),
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

// --- 投稿カードウィジェット ---

class _PostHeader extends StatelessWidget {
  final Post post;
  // ▼▼▼ 引数を追加 ▼▼▼
  final bool isFriendOrMyQuest;
  // ▲▲▲
  const _PostHeader({required this.post, required this.isFriendOrMyQuest});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // ▼▼▼ フレンドか自分ならプロフィールに飛べる ▼▼▼
      onTap: isFriendOrMyQuest
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: post.uid)),
              );
            }
          : null, // ▲▲▲
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              // ▼▼▼ 匿名化対応 ▼▼▼
              backgroundImage: (isFriendOrMyQuest && post.userAvatar != null)
                  ? NetworkImage(post.userAvatar!)
                  : null,
              child: (!isFriendOrMyQuest || post.userAvatar == null)
                  ? const Icon(Icons.person)
                  : null,
              // ▲▲▲
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      // ▼▼▼ 匿名化対応 ▼▼▼
                      isFriendOrMyQuest ? post.userName : '匿名の冒険者',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  // レベルとジョブはフレンドでなくても表示する
                  Text('Lv.${post.userLevel}・${post.userClass}',
                      style: Theme.of(context).textTheme.bodySmall),
                  // ▲▲▲
                ],
              ),
            ),
            if (post.isWisdomShared)
              Row(
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.deepPurpleAccent.shade100, size: 18),
                  SizedBox(width: 4),
                  Text("叡智",
                      style: TextStyle(
                          color: Colors.deepPurpleAccent.shade100,
                          fontWeight: FontWeight.bold)),
                ],
              )
            else if (post.timeSpentHours != null && post.timeSpentHours! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${post.timeSpentHours}時間',
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
  final VoidCallback onLike;

  const _PostActions({
    required this.post,
    required this.isLiked,
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
