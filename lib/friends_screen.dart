import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/friendship.dart';
import 'models/user_profile.dart';

// ユーザーとのフレンド状況を示すためのenum
enum FriendshipStatus {
  friends,
  pendingSent,
  pendingReceived,
  notFriends,
  self
}

// メインとなるFriendsScreen
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フレンド'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'フレンド一覧'),
            Tab(text: '届いた申請'),
            Tab(text: '探す'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FriendListTab(),
          FriendRequestsTab(),
          UserSearchTab(),
        ],
      ),
    );
  }
}

// --- 1. フレンド一覧タブ ---
class FriendListTab extends StatelessWidget {
  const FriendListTab({super.key});

  Future<void> _removeFriend(String friendshipId) async {
    await FirebaseFirestore.instance
        .collection('friendships')
        .doc(friendshipId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text("ログインしてください"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだフレンドがいません。'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final friendshipDoc = snapshot.data!.docs[index];
            final friendship = Friendship.fromFirestore(friendshipDoc);

            final friendId =
                friendship.userIds.firstWhere((id) => id != currentUser.uid);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const ListTile();
                final userProfile =
                    UserProfile.fromFirestore(userSnapshot.data!);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userProfile.photoURL != null
                        ? NetworkImage(userProfile.photoURL!)
                        : null,
                    child: userProfile.photoURL == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(userProfile.displayName ?? '名無しさん'),
                  trailing: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('フレンド解除'),
                            content: Text(
                                '${userProfile.displayName ?? '名無しさん'}とのフレンドを解除しますか？'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('キャンセル'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: const Text('解除',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  _removeFriend(friendship.id);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child:
                        const Text('解除', style: TextStyle(color: Colors.red)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- 2. 届いた申請タブ ---
class FriendRequestsTab extends StatelessWidget {
  const FriendRequestsTab({super.key});

  Future<void> _acceptRequest(String friendshipId) async {
    await FirebaseFirestore.instance
        .collection('friendships')
        .doc(friendshipId)
        .update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _declineRequest(String friendshipId) async {
    await FirebaseFirestore.instance
        .collection('friendships')
        .doc(friendshipId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text("ログインしてください"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .where('recipientId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('届いた申請はありません。'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final friendshipDoc = snapshot.data!.docs[index];
            final friendship = Friendship.fromFirestore(friendshipDoc);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(friendship.requesterId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const ListTile();
                final userProfile =
                    UserProfile.fromFirestore(userSnapshot.data!);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userProfile.photoURL != null
                        ? NetworkImage(userProfile.photoURL!)
                        : null,
                    child: userProfile.photoURL == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(userProfile.displayName ?? '名無しさん'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _declineRequest(friendship.id),
                        child: const Text('拒否'),
                      ),
                      ElevatedButton(
                        onPressed: () => _acceptRequest(friendship.id),
                        child: const Text('承認'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- 3. フレンドを探すタブ ---
class UserSearchTab extends StatefulWidget {
  const UserSearchTab({super.key});

  @override
  State<UserSearchTab> createState() => _UserSearchTabState();
}

class _UserSearchTabState extends State<UserSearchTab> {
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String searchTerm) async {
    if (searchTerm.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isLoading = true);
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: searchTerm)
        .where('displayName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
        .limit(10)
        .get();
    final users =
        snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
    if (mounted)
      setState(() {
        _searchResults = users;
        _isLoading = false;
      });
  }

  Future<void> _sendFriendRequest(String recipientId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid == recipientId) return;
    final friendshipData = {
      'userIds': [user.uid, recipientId]..sort(),
      'requesterId': user.uid,
      'recipientId': recipientId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('friendships')
        .add(friendshipData);
    _searchUsers(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
                labelText: 'ユーザー名で検索...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: _searchUsers,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? const Center(child: Text('検索結果はありません。'))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return FutureBuilder<FriendshipStatus>(
                          future: _getFriendshipStatus(user.uid),
                          builder: (context, snapshot) {
                            final status =
                                snapshot.data ?? FriendshipStatus.notFriends;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.photoURL != null
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                                child: user.photoURL == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user.displayName ?? '名無しさん'),
                              trailing:
                                  _buildFriendshipButton(status, user.uid),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<FriendshipStatus> _getFriendshipStatus(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return FriendshipStatus.notFriends;
    if (currentUser.uid == otherUserId) return FriendshipStatus.self;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: currentUser.uid)
        .get();
    for (var doc in querySnapshot.docs) {
      final userIds = List<String>.from(doc.data()['userIds']);
      if (userIds.contains(otherUserId)) {
        final status = doc.data()['status'];
        if (status == 'accepted') return FriendshipStatus.friends;
        if (status == 'pending')
          return doc.data()['requesterId'] == currentUser.uid
              ? FriendshipStatus.pendingSent
              : FriendshipStatus.pendingReceived;
      }
    }
    return FriendshipStatus.notFriends;
  }

  Widget _buildFriendshipButton(FriendshipStatus status, String userId) {
    switch (status) {
      case FriendshipStatus.friends:
        return const Text('フレンド', style: TextStyle(color: Colors.green));
      case FriendshipStatus.pendingSent:
        return const Text('申請済み');
      case FriendshipStatus.pendingReceived:
        return const Text('要承認');
      case FriendshipStatus.self:
        return const SizedBox.shrink();
      case FriendshipStatus.notFriends:
      default:
        return ElevatedButton(
            onPressed: () => _sendFriendRequest(userId),
            child: const Text('申請'));
    }
  }
}
