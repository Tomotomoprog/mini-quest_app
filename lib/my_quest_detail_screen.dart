// lib/my_quest_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';
import 'models/friendship.dart';
import 'my_quest_post_screen.dart';
import 'widgets/my_quest_detail/quest_detail_header.dart';
import 'profile_screen.dart';
import 'comment_screen.dart';
import 'cheer_list_screen.dart';
import 'widgets/post_content_widget.dart';
import 'edit_my_quest_screen.dart';

class MyQuestDetailScreen extends StatefulWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  State<MyQuestDetailScreen> createState() => _MyQuestDetailScreenState();
}

class _MyQuestDetailScreenState extends State<MyQuestDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _myId;

  List<Map<String, dynamic>> _rankingData = [];
  bool _isLoadingRanking = false;

  Set<String> _likedPostIds = {};
  UserProfile? _currentUserProfile;

  late MyQuest _displayQuest;

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _displayQuest = widget.quest;

    int tabCount = (widget.quest.type == 'battle') ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);

    if (widget.quest.type == 'battle') {
      _calculateRanking();
    }
    _fetchMyDataAndLikes();
  }

  Future<void> _fetchMyDataAndLikes() async {
    if (_myId == null) return;

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(_myId).get();
    final likesFuture = FirebaseFirestore.instance
        .collectionGroup('likes')
        .where('uid', isEqualTo: _myId)
        .get();

    final results = await Future.wait([userDocFuture, likesFuture]);

    if (mounted) {
      final userDoc = results[0] as DocumentSnapshot;
      final likesSnapshot = results[1] as QuerySnapshot;

      if (userDoc.exists) {
        setState(() {
          _currentUserProfile = UserProfile.fromFirestore(userDoc);

          if (_displayQuest.uid == _myId) {
            _displayQuest = _displayQuest.copyWith(
              userName: _currentUserProfile!.displayName ?? '名無しさん',
              userPhotoURL: _currentUserProfile!.photoURL,
            );
          }
        });
      }

      setState(() {
        _likedPostIds = likesSnapshot.docs
            .map((doc) => doc.reference.parent.parent!.id)
            .toSet();
      });
    }
  }

  Future<void> _navigateToEditScreen() async {
    final bool? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditMyQuestScreen(myQuest: _displayQuest),
      ),
    );

    if (result == true) {
      final doc = await FirebaseFirestore.instance
          .collection('my_quests')
          .doc(_displayQuest.id)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _displayQuest = MyQuest.fromFirestore(doc);
          if (_displayQuest.uid == _myId && _currentUserProfile != null) {
            _displayQuest = _displayQuest.copyWith(
              userName: _currentUserProfile!.displayName,
              userPhotoURL: _currentUserProfile!.photoURL,
            );
          }
        });
      }
    }
  }

  Future<void> _deleteQuest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クエストを削除'),
        content: const Text('本当に削除しますか？関連する投稿は削除されませんが、クエストは参加者全員から削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('my_quests')
          .doc(_displayQuest.id)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クエストを削除しました')),
        );
      }
    }
  }

  Future<void> _calculateRanking() async {
    setState(() => _isLoadingRanking = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('myQuestId', isEqualTo: widget.quest.id)
          .get();

      Map<String, Map<String, dynamic>> stats = {};

      for (var uid in widget.quest.participantIds) {
        stats[uid] = {
          'uid': uid,
          'name': 'Loading...',
          'effort': 0.0,
          'posts': 0,
          'cheers': 0,
          'score': 0.0,
        };
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['uid'];
        final time = (data['timeSpentHours'] as num? ?? 0).toDouble();
        final cheers = (data['likeCount'] as num? ?? 0).toInt();
        final name = data['userName'] ?? 'Unknown';

        if (stats.containsKey(uid)) {
          stats[uid]!['name'] = name;
          stats[uid]!['effort'] += time;
          stats[uid]!['posts'] += 1;
          stats[uid]!['cheers'] += cheers;
        }
      }

      for (var uid in stats.keys) {
        final s = stats[uid]!;
        s['score'] = (s['effort'] * 10) + (s['posts'] * 5) + (s['cheers'] * 2);
      }

      final ranking = stats.values.toList();
      ranking.sort((a, b) => b['score'].compareTo(a['score']));

      if (mounted) {
        setState(() {
          _rankingData = ranking;
          _isLoadingRanking = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRanking = false);
    }
  }

  Future<void> _toggleLike(Post post) async {
    if (_myId == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final likeRef = postRef.collection('likes').doc(_myId);
    final isLiked = _likedPostIds.contains(post.id);

    setState(() {
      if (isLiked)
        _likedPostIds.remove(post.id);
      else
        _likedPostIds.add(post.id);
    });

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;

      if (isLiked) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        transaction.set(
            likeRef, {'uid': _myId, 'createdAt': FieldValue.serverTimestamp()});
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
        if (post.uid != _myId) {
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          transaction.set(notificationRef, {
            'type': 'cheer',
            'fromUserId': _myId,
            'fromUserName': _currentUserProfile?.displayName ?? '名無しさん',
            'fromUserAvatar': _currentUserProfile?.photoURL,
            'postId': post.id,
            'postTextSnippet': post.text,
            'targetUserId': post.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    });
  }

  Future<void> _deletePost(String postId, String? photoURL) async {
    try {
      if (photoURL != null && photoURL.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(photoURL).delete();
      }
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
    } catch (e) {/* error */}
  }

  // ▼▼▼ 修正: 参加メンバー表示ウィジェット (順位バッジ付き) ▼▼▼
  Widget _buildParticipantsSection() {
    if (_displayQuest.type == 'personal') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text('参加メンバー',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId,
                  whereIn: _displayQuest.participantIds.take(10).toList())
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            if (!snapshot.hasData) return const Text('読み込み失敗');

            final users = snapshot.data!.docs
                .map((doc) => UserProfile.fromFirestore(doc))
                .toList();

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: users.map((user) {
                // ▼▼▼ バトルの場合、順位を取得 ▼▼▼
                int? rank;
                if (_displayQuest.type == 'battle' && _rankingData.isNotEmpty) {
                  final index = _rankingData
                      .indexWhere((data) => data['uid'] == user.uid);
                  if (index != -1) {
                    rank = index + 1;
                  }
                }
                // ▲▲▲

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userId: user.uid)),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.topRight, // 右上にバッジを表示
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            backgroundColor: Colors.grey[800],
                            child: user.photoURL == null
                                ? const Icon(Icons.person,
                                    size: 20, color: Colors.grey)
                                : null,
                          ),
                          // ▼▼▼ 順位バッジ ▼▼▼
                          if (rank != null)
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _getRankColor(rank), // 順位に応じた色
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                '$rank',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // ▲▲▲
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          user.displayName ?? '名無し',
                          style: const TextStyle(
                              fontSize: 10, overflow: TextOverflow.ellipsis),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const Divider(height: 32),
      ],
    );
  }

  // 順位の色を返すヘルパー
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade700; // 金
      case 2:
        return Colors.blueGrey.shade400; // 銀
      case 3:
        return Colors.brown.shade400; // 銅
      default:
        return Colors.grey.shade600;
    }
  }
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    final bool isParticipant = _displayQuest.participantIds.contains(_myId);
    final bool isOwner = _displayQuest.uid == _myId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayQuest.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: '詳細'),
            const Tab(text: 'みんなの記録'),
            if (_displayQuest.type == 'battle') const Tab(text: 'ランキング'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // タブ1: 詳細情報
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestDetailHeader(
                  quest: _displayQuest,
                  isFriendOrMyQuest: true,
                  friendshipStatus: FriendshipStatus.accepted,
                  onSendRequest: () {},
                  onEdit: isOwner ? _navigateToEditScreen : null,
                  onDelete: isOwner ? _deleteQuest : null,
                ),
                _buildParticipantsSection(),
                if (_displayQuest.schedule.isNotEmpty)
                  _InfoTile(
                      icon: Icons.schedule,
                      title: 'いつやる？',
                      content: _displayQuest.schedule),
                if (_displayQuest.minimumStep.isNotEmpty)
                  _InfoTile(
                      icon: Icons.directions_walk,
                      title: '最低目標',
                      content: _displayQuest.minimumStep),
                if (_displayQuest.reward.isNotEmpty)
                  _InfoTile(
                      icon: Icons.card_giftcard,
                      title: 'ご褒美',
                      content: _displayQuest.reward),
              ],
            ),
          ),

          // タブ2: タイムライン
          _buildTimelineTab(),

          // タブ3: ランキング
          if (_displayQuest.type == 'battle') _buildRankingTab(),
        ],
      ),
      floatingActionButton: isParticipant && _displayQuest.status == 'active'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        MyQuestPostScreen(initialQuest: _displayQuest)));
              },
              icon: const Icon(Icons.add_task),
              label: const Text('進捗を記録'),
            )
          : null,
    );
  }

  Widget _buildTimelineTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('myQuestId', isEqualTo: widget.quest.id)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだ記録がありません'));
        }

        final posts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final bool isLiked = _likedPostIds.contains(post.id);
            final bool isMyPost = post.uid == _myId;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(userId: post.uid)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text('Lv.${post.userLevel}・${post.userClass}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PostContentWidget(post: post),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                              isLiked
                                  ? Icons.local_fire_department
                                  : Icons.local_fire_department_outlined,
                              color: isLiked
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                          onPressed: () => _toggleLike(post),
                        ),
                        Text('${post.likeCount}',
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: Colors.grey),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      CommentScreen(post: post))),
                        ),
                        Text('${post.commentCount}',
                            style: const TextStyle(color: Colors.grey)),
                        if (isMyPost)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.grey),
                            onPressed: () =>
                                _deletePost(post.id, post.photoURL),
                          ),
                        const Spacer(),
                        Text(
                          DateFormat('M/d HH:mm')
                              .format(post.createdAt.toDate()),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRankingTab() {
    if (_isLoadingRanking)
      return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: _rankingData.length,
      itemBuilder: (context, index) {
        final data = _rankingData[index];
        final rank = index + 1;
        Color rankColor = Colors.grey;
        if (rank == 1) rankColor = Colors.amber;
        if (rank == 2) rankColor = Colors.grey.shade300;
        if (rank == 3) rankColor = Colors.brown.shade300;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: rankColor,
            child: Text('$rank',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          title: Text(data['name']),
          subtitle: Text(
              '努力: ${data['effort']}h / 記録: ${data['posts']}回 / 応援: ${data['cheers']}'),
          trailing: Text(
            '${(data['score'] as double).toStringAsFixed(0)} pt',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _InfoTile(
      {required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(content, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
