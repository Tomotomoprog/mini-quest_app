// lib/friends_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/friendship.dart';
import 'models/user_profile.dart';
import 'models/notification.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Stream<List<UserProfile>>? _searchResultsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResultsStream = null);
      return;
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _searchResultsStream = FirebaseFirestore.instance
          .collection('users')
          .where('accountName', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('accountName',
              isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => UserProfile.fromFirestore(doc))
              .where((user) => user.uid != currentUser.uid)
              .toList());
    });
  }

// lib/friends_screen.dart の _FriendsScreenState クラスの末尾に追加

  // ▼▼▼ この関数を追加 ▼▼▼
  Widget _buildSearchUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              // ▼▼▼ 検索ヒントを accountName に変更 ▼▼▼
              labelText: 'アカウント名で検索',
              hintText: '例: tomoyasu_dev',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, // ◀◀◀ ダークモード用の設定
              fillColor: Colors.grey[850], // ◀◀◀
            ),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _searchResultsStream == null
                ? const Center(child: Text('アカウント名を入力して検索してください。'))
                : StreamBuilder<List<UserProfile>>(
                    stream: _searchResultsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('ユーザーが見つかりません。'));
                      }
                      final users = snapshot.data!;
                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _UserSearchCard(user: user);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'フレンド'),
              Tab(text: 'お知らせ'),
              Tab(text: '探す'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsListTab(),
                _buildNotificationsTab(),
                _buildSearchUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Center(child: Text("ログインしてください"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('新しいお知らせはありません。'));
        }

        final notifications = snapshot.data!.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final icon = notification.type == 'like'
                ? Icons.favorite
                : Icons.chat_bubble;
            final color = notification.type == 'like'
                ? Theme.of(context).colorScheme.primary
                : Colors.blueAccent;
            final message = notification.type == 'like'
                ? 'あなたの投稿に「いいね！」しました'
                : 'あなたの投稿にコメントしました';

            return ListTile(
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundImage: notification.fromUserAvatar != null
                        ? NetworkImage(notification.fromUserAvatar!)
                        : null,
                    child: notification.fromUserAvatar == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 12),
                  )
                ],
              ),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: notification.fromUserName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: 'さんが$message'),
                  ],
                ),
              ),
              subtitle: Text(
                '投稿: "${notification.postTextSnippet}"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatRelativeTime(notification.createdAt.toDate()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () {
                // TODO: タップしたら投稿詳細画面に遷移する
              },
            );
          },
        );
      },
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}日前';
    if (diff.inHours > 0) return '${diff.inHours}時間前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分前';
    return 'たった今';
  }

  // ▼▼▼ フレンドリストタブのレイアウトを修正 ▼▼▼
  Widget _buildFriendsListTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 探す欄からのフレンド申請
          Text('探す欄からのフレンド申請', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(
              FriendshipStatus.quest_pending), // ◀◀◀ 'quest_pending'

          const SizedBox(height: 24),

          // 2. 通常のフレンド申請
          Text('フレンド申請', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(FriendshipStatus.pending), // ◀◀◀ 'pending'

          const SizedBox(height: 24),

          // 3. フレンド一覧
          Text('フレンド', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(FriendshipStatus.accepted), // ◀◀◀ 'accepted'
        ],
      ),
    );
  }
  // ▲▲▲

  Widget _buildFriendsList(FriendshipStatus status) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    // ▼▼▼ クエリを status に応じて変更 ▼▼▼
    late Query streamQuery;

    if (status == FriendshipStatus.accepted) {
      streamQuery = FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: currentUid)
          .where('status', isEqualTo: 'accepted');
    } else {
      // 'pending' と 'quest_pending' を status で分岐
      streamQuery = FirebaseFirestore.instance
          .collection('friendships')
          .where('receiverId', isEqualTo: currentUid)
          .where('status', isEqualTo: status.name); // ◀◀◀ .name で文字列に
    }
    // ▲▲▲

    return StreamBuilder<QuerySnapshot>(
      stream: streamQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(status == FriendshipStatus.accepted
                ? 'まだフレンドがいません。'
                : '新しい申請はありません。'),
          );
        }

        return FutureBuilder<List<UserProfile>>(
          future: _getUsersFromFriendships(docs, currentUid),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const SizedBox.shrink();
            final users = userSnapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final friendshipId = docs[index].id;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user.displayName ?? '名無しさん',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("@${user.accountName ?? ''}"),
                    trailing: status != FriendshipStatus.accepted // 申請系の場合
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                onPressed: () => _updateFriendshipStatus(
                                    friendshipId, 'accepted'),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _updateFriendshipStatus(
                                    friendshipId, 'declined'),
                              ),
                            ],
                          )
                        : null, // 承認済みの場合はボタンなし
                    onTap: status == FriendshipStatus.accepted
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(userId: user.uid),
                              ),
                            );
                          }
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<UserProfile>> _getUsersFromFriendships(
      List<QueryDocumentSnapshot> docs, String currentUid) async {
    final userIds = docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          if (data.containsKey('userIds')) {
            final List<dynamic> userIdsList = data['userIds'];
            return userIdsList.firstWhere((id) => id != currentUid,
                orElse: () => null);
          } else {
            return data['senderId'];
          }
        })
        .where((id) => id != null)
        .toList();

    if (userIds.isEmpty) return [];

    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    return userDocs.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
  }

  Future<void> _updateFriendshipStatus(
      String friendshipId, String status) async {
    final friendshipRef =
        FirebaseFirestore.instance.collection('friendships').doc(friendshipId);
    if (status == 'accepted') {
      final doc = await friendshipRef.get();
      final senderId = doc.data()!['senderId'];
      final receiverId = doc.data()!['receiverId'];
      await friendshipRef.update({
        'status': 'accepted',
        'userIds': [senderId, receiverId]
      });
    } else {
      await friendshipRef.delete();
    }
  }
}

class _UserSearchCard extends StatefulWidget {
  final UserProfile user;
  const _UserSearchCard({required this.user});

  @override
  State<_UserSearchCard> createState() => _UserSearchCardState();
}

class _UserSearchCardState extends State<_UserSearchCard> {
  FriendshipStatus? _friendshipStatus;

  @override
  void initState() {
    super.initState();
    _checkFriendshipStatus();
  }

  @override
  void didUpdateWidget(covariant _UserSearchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.uid != oldWidget.user.uid) {
      _checkFriendshipStatus();
    }
  }

  Future<void> _checkFriendshipStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final myId = currentUser.uid;
    final otherId = widget.user.uid;

    final query1 = FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', isEqualTo: [myId, otherId]).get();

    final query2 = FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', isEqualTo: [otherId, myId]).get();

    final query3 = FirebaseFirestore.instance
        .collection('friendships')
        .where('senderId', whereIn: [myId, otherId]).where('receiverId',
            whereIn: [myId, otherId]).get();

    final results = await Future.wait([query1, query2, query3]);
    final docs = [...results[0].docs, ...results[1].docs, ...results[2].docs];

    final uniqueDocs = {for (var doc in docs) doc.id: doc}.values.toList();

    if (mounted) {
      if (uniqueDocs.isEmpty) {
        setState(() => _friendshipStatus = FriendshipStatus.none);
      } else {
        final data = uniqueDocs.first.data();
        final status = data['status'];
        if (status == 'accepted') {
          setState(() => _friendshipStatus = FriendshipStatus.accepted);
        } else if (status == 'pending' || status == 'quest_pending') {
          // ◀◀◀ quest_pending も考慮
          setState(() =>
              _friendshipStatus = FriendshipStatus.pending); // 申請中は「申請中」でまとめる
        } else {
          setState(() => _friendshipStatus = FriendshipStatus.none);
        }
      }
    }
  }

  // ▼▼▼ 申請ロジックを修正 ▼▼▼
  Future<void> _sendFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance.collection('friendships').add({
      'senderId': currentUser.uid,
      'receiverId': widget.user.uid,
      'status': 'pending', // ◀◀◀ 通常の 'pending' を使用
      'createdAt': FieldValue.serverTimestamp(),
      'userIds': [currentUser.uid, widget.user.uid],
    });

    setState(() => _friendshipStatus = FriendshipStatus.pending);
  }
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: widget.user.photoURL != null
              ? NetworkImage(widget.user.photoURL!)
              : null,
          child: widget.user.photoURL == null ? const Icon(Icons.person) : null,
        ),
        title: Text(widget.user.displayName ?? '名無しさん',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("@${widget.user.accountName ?? ''}"),
        trailing: _buildTrailingButton(),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.user.uid),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrailingButton() {
    if (_friendshipStatus == null)
      return const SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator());

    switch (_friendshipStatus!) {
      case FriendshipStatus.accepted:
        return Chip(
            label: Text('フレンド', style: TextStyle(color: Colors.green[100])),
            backgroundColor: Colors.green[800]?.withOpacity(0.5),
            avatar: Icon(Icons.check, size: 16, color: Colors.green[100]));
      case FriendshipStatus.pending: // 'pending' と 'quest_pending' 両方
        return const Chip(label: Text('申請中'));
      case FriendshipStatus.none:
        return ElevatedButton(
          onPressed: _sendFriendRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('申請'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
