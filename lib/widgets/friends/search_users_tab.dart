// lib/widgets/friends/search_users_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friendship.dart';
import '../../models/user_profile.dart';
import '../../profile_screen.dart';

class SearchUsersTab extends StatefulWidget {
  const SearchUsersTab({super.key});

  @override
  State<SearchUsersTab> createState() => _SearchUsersTabState();
}

class _SearchUsersTabState extends State<SearchUsersTab> {
  final _searchController = TextEditingController();
  Stream<List<UserProfile>>? _searchResultsStream;

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'アカウント名で検索',
              hintText: '例: tomoyasu_dev',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[850],
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
}

// (ここから下は _UserSearchCard とそのロジック)

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
          setState(() => _friendshipStatus = FriendshipStatus.pending);
        } else {
          setState(() => _friendshipStatus = FriendshipStatus.none);
        }
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final friendshipRef =
        FirebaseFirestore.instance.collection('friendships').doc();
    batch.set(friendshipRef, {
      'senderId': currentUser.uid,
      'receiverId': widget.user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'userIds': [currentUser.uid, widget.user.uid],
    });

    final notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc();
    batch.set(notificationRef, {
      'type': 'friend_request',
      'fromUserId': currentUser.uid,
      'fromUserName': currentUser.displayName ?? '名無しさん',
      'fromUserAvatar': currentUser.photoURL,
      'targetUserId': widget.user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'postId': null,
      'postTextSnippet': null,
    });

    await batch.commit();

    setState(() => _friendshipStatus = FriendshipStatus.pending);
  }

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
      case FriendshipStatus.pending:
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
