// lib/profile_friends_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'profile_screen.dart';

class ProfileFriendsListScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ProfileFriendsListScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ProfileFriendsListScreen> createState() =>
      _ProfileFriendsListScreenState();
}

class _ProfileFriendsListScreenState extends State<ProfileFriendsListScreen> {
  String? _currentUserId;
  // 自分のフレンド関係マップ (相手のUID -> ステータス)
  Map<String, String> _myFriendshipStatusMap = {};
  bool _isLoadingMyFriendships = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchMyFriendships();
  }

  // 自分のフレンド関係を一括取得してマップ化する
  // (リスト表示時にN+1回のクエリが発生するのを防ぐため)
  Future<void> _fetchMyFriendships() async {
    if (_currentUserId == null) {
      setState(() => _isLoadingMyFriendships = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: _currentUserId)
          .get();

      final Map<String, String> tempMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List userIds = data['userIds'] as List;
        final String status = data['status'] as String;

        // 相手のIDを特定
        final otherId = userIds.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => null,
        );

        if (otherId != null) {
          // 申請中の場合、自分が送ったのか受け取ったのかを区別したい場合
          // ここでは単純にステータスを保存しますが、必要なら senderId もチェック可能です
          tempMap[otherId] = status;
        }
      }

      if (mounted) {
        setState(() {
          _myFriendshipStatusMap = tempMap;
          _isLoadingMyFriendships = false;
        });
      }
    } catch (e) {
      print("フレンド情報の取得エラー: $e");
      if (mounted) {
        setState(() => _isLoadingMyFriendships = false);
      }
    }
  }

  // 表示対象のユーザー（プロフィール主のフレンド）を取得
  Future<List<UserProfile>> _getDisplayUsers() async {
    // 1. プロフィール主のフレンドID一覧を取得
    final friendshipsSnapshot = await FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: widget.userId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendIds = friendshipsSnapshot.docs
        .map((doc) {
          final userIds = doc.data()['userIds'] as List;
          return userIds.firstWhere((id) => id != widget.userId,
              orElse: () => null);
        })
        .where((id) => id != null)
        .toList();

    if (friendIds.isEmpty) return [];

    // 2. IDからユーザープロフィールを取得
    // (Firestoreの limitation: whereIn は最大10件または30件制限があるため、数が多い場合は分割が必要ですが、
    //  ここでは簡易的に10件ずつ分割取得するか、件数が少ない前提で実装します。
    //  今回は安全のため、クライアントサイドでフィルタリングはせず、10件制限を考慮してチャンク分けする例、
    //  または件数が少ないと仮定してそのまま取得します)

    // ※10人以上のフレンドがいるとエラーになる可能性があるため、分割処理を入れるのが安全です
    List<UserProfile> profiles = [];
    for (var i = 0; i < friendIds.length; i += 10) {
      final chunk = friendIds.sublist(
          i, i + 10 > friendIds.length ? friendIds.length : i + 10);

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      profiles.addAll(usersSnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList());
    }

    return profiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}のフレンド'),
      ),
      body: _isLoadingMyFriendships
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<UserProfile>>(
              future: _getDisplayUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('情報の取得に失敗しました。'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('まだフレンドがいません。'));
                }

                final friends = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];

                    // 自分自身はリストに表示しない
                    if (friend.uid == _currentUserId) {
                      return const SizedBox.shrink();
                    }

                    // 自分とこのユーザーとの関係を取得
                    final myStatus = _myFriendshipStatusMap[friend.uid];

                    return _FriendListItem(
                      targetUser: friend,
                      currentUserId: _currentUserId,
                      initialStatus: myStatus,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FriendListItem extends StatefulWidget {
  final UserProfile targetUser;
  final String? currentUserId;
  final String? initialStatus;

  const _FriendListItem({
    required this.targetUser,
    required this.currentUserId,
    required this.initialStatus,
  });

  @override
  State<_FriendListItem> createState() => _FriendListItemState();
}

class _FriendListItemState extends State<_FriendListItem> {
  late String? _status;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  // フレンド申請を送る
  Future<void> _sendFriendRequest() async {
    if (widget.currentUserId == null) return;

    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // friendships ドキュメント作成
      final friendshipRef =
          FirebaseFirestore.instance.collection('friendships').doc();
      batch.set(friendshipRef, {
        'senderId': widget.currentUserId,
        'receiverId': widget.targetUser.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'userIds': [widget.currentUserId, widget.targetUser.uid],
      });

      // 通知を作成
      final notificationRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'friend_request',
        'fromUserId': widget.currentUserId,
        // ※ 自分の名前を取得して入れるのが理想ですが、ここでは簡易的に固定か、
        // 親から渡す必要があります。今回はUI更新優先で進めます。
        // (Cloud Functions側で補完する設計であればIDだけでOK)
        'targetUserId': widget.targetUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();

      if (mounted) {
        setState(() {
          _status = 'pending';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フレンド申請を送りました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    Widget trailingWidget;

    if (_isProcessing) {
      trailingWidget = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_status == 'accepted') {
      // すでにフレンドの場合
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green),
        ),
        child: const Text(
          'フレンド',
          style: TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    } else if (_status == 'pending' || _status == 'quest_pending') {
      // 申請中（または承認待ち）
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: const Text(
          '申請中',
          style: TextStyle(
              color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    } else {
      // フレンドでも申請中でもない場合 -> 申請ボタン
      trailingWidget = ElevatedButton(
        onPressed: _sendFriendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: const Size(0, 36), //高さを少し抑える
        ),
        child: const Text('申請する',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      color: Colors.grey[900],
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundImage: widget.targetUser.photoURL != null
              ? NetworkImage(widget.targetUser.photoURL!)
              : null,
          backgroundColor: Colors.grey[800],
          child: widget.targetUser.photoURL == null
              ? const Icon(Icons.person, color: Colors.white54)
              : null,
        ),
        title: Text(
          widget.targetUser.displayName ?? '名無しさん',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailingWidget,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(userId: widget.targetUser.uid),
            ),
          );
        },
      ),
    );
  }
}
