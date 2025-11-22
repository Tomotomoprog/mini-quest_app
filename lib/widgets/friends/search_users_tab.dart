// lib/widgets/friends/search_users_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../profile_screen.dart';

class SearchUsersTab extends StatefulWidget {
  const SearchUsersTab({super.key});

  @override
  State<SearchUsersTab> createState() => _SearchUsersTabState();
}

class _SearchUsersTabState extends State<SearchUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // 検索結果
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;

  // おすすめユーザー
  List<UserProfile> _recommendedUsers = [];
  bool _isLoadingRecommendations = true;

  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _searchController.addListener(_onSearchChanged);
    // 初期化時におすすめユーザーを取得
    _fetchRecommendations();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchText = _searchController.text.trim();
    });
    if (_searchText.isNotEmpty) {
      _performSearch();
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // ▼▼▼ おすすめユーザー（フレンドのフレンド）を取得するロジック ▼▼▼
  Future<void> _fetchRecommendations() async {
    if (_currentUserId == null) return;

    try {
      final db = FirebaseFirestore.instance;

      // 1. まず自分のフレンドIDリストを取得 (除外用 + 検索起点用)
      final myFriendships = await db
          .collection('friendships')
          .where('userIds', arrayContains: _currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final Set<String> myFriendIds = {};
      for (var doc in myFriendships.docs) {
        final List userIds = doc.data()['userIds'];
        final friendId = userIds.firstWhere((id) => id != _currentUserId,
            orElse: () => null);
        if (friendId != null) myFriendIds.add(friendId);
      }

      // 除外リスト（自分 + 既にフレンド）
      final Set<String> excludeIds = {_currentUserId!, ...myFriendIds};
      final Set<String> candidateIds = {};

      // 2. フレンドのフレンドを探す (読み取り量を抑えるため、自分のフレンド先頭5人くらいまでを調査)
      // ※ 本格的なSNSではこの処理はサーバーサイド(Cloud Functions)で行うのが一般的です
      int checkCount = 0;
      for (var friendId in myFriendIds) {
        if (checkCount >= 5) break; // 制限

        final friendsOfFriend = await db
            .collection('friendships')
            .where('userIds', arrayContains: friendId)
            .where('status', isEqualTo: 'accepted')
            .limit(10) // 各フレンドにつき10人まで
            .get();

        for (var doc in friendsOfFriend.docs) {
          final List userIds = doc.data()['userIds'];
          final targetId =
              userIds.firstWhere((id) => id != friendId, orElse: () => null);

          // 除外リストに含まれていなければ候補に追加
          if (targetId != null && !excludeIds.contains(targetId)) {
            candidateIds.add(targetId);
          }
        }
        checkCount++;
      }

      // 3. もし候補が少なければ、最近登録されたユーザーを補充する (フォールバック)
      if (candidateIds.length < 5) {
        final recentUsers = await db
            .collection('users')
            .orderBy('totalEffortHours', descending: true) // 努力している人を優先表示
            .limit(10)
            .get();

        for (var doc in recentUsers.docs) {
          if (!excludeIds.contains(doc.id)) {
            candidateIds.add(doc.id);
          }
        }
      }

      // 4. 候補IDからプロフィールを取得 (最大10件)
      final List<String> finalIds = candidateIds.take(10).toList();

      if (finalIds.isEmpty) {
        if (mounted) setState(() => _isLoadingRecommendations = false);
        return;
      }

      // whereIn は最大10件まで
      final profilesSnapshot = await db
          .collection('users')
          .where(FieldPath.documentId, whereIn: finalIds)
          .get();

      final profiles = profilesSnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _recommendedUsers = profiles;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      print('おすすめ取得エラー: $e');
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }
  // ▲▲▲

  Future<void> _performSearch() async {
    if (_searchText.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      // アカウント名での検索 (完全一致または前方一致)
      // ※ Firestoreで前方一致検索をするための定石テクニック
      final endText = '$_searchText\uf8ff';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountName', isGreaterThanOrEqualTo: _searchText)
          .where('accountName', isLessThan: endText)
          .limit(20)
          .get();

      // もしアカウント名でヒットしなければ、表示名でも検索（クライアントサイドフィルタ推奨だが、簡易的に）
      // ここではアカウント名優先とします

      final results = snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .where((user) => user.uid != _currentUserId) // 自分は除外
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('検索エラー: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSearchMode = _searchText.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // キーボードを閉じる
      child: Scaffold(
        resizeToAvoidBottomInset: false, // キーボードでレイアウトが崩れるのを防ぐ
        body: Column(
          children: [
            // 検索バー
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'アカウント名で検索 (例: tomo_dev)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            // フォーカスを外しておすすめを表示
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
              ),
            ),

            // リスト表示部分
            Expanded(
              child: isSearchMode
                  ? _buildSearchResults()
                  : _buildRecommendations(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text('ユーザーが見つかりませんでした'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _UserListItem(
          userProfile: _searchResults[index],
          currentUserId: _currentUserId,
        );
      },
    );
  }

  Widget _buildRecommendations() {
    if (_isLoadingRecommendations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recommendedUsers.isEmpty) {
      // おすすめが全くない場合
      return const Center(
        child: Text(
          'おすすめのユーザーが見つかりませんでした。\nまずはフレンドを増やしてみましょう！',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'おすすめの冒険者',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recommendedUsers.length,
            itemBuilder: (context, index) {
              return _UserListItem(
                userProfile: _recommendedUsers[index],
                currentUserId: _currentUserId,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ▼▼▼ 共通のユーザーリストアイテムウィジェット ▼▼▼
class _UserListItem extends StatefulWidget {
  final UserProfile userProfile;
  final String? currentUserId;

  const _UserListItem({
    required this.userProfile,
    required this.currentUserId,
  });

  @override
  State<_UserListItem> createState() => _UserListItemState();
}

class _UserListItemState extends State<_UserListItem> {
  String _status = 'none'; // 'none', 'pending', 'accepted'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFriendStatus();
  }

  // このユーザーとのフレンド状態を確認
  Future<void> _checkFriendStatus() async {
    if (widget.currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: widget.currentUserId)
          .get();

      String newStatus = 'none';
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List userIds = data['userIds'];
        if (userIds.contains(widget.userProfile.uid)) {
          newStatus = data['status']; // 'pending' or 'accepted'
          break;
        }
      }

      if (mounted) {
        setState(() {
          _status = newStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    if (widget.currentUserId == null) return;

    setState(() => _status = 'loading'); // 一時的にローディング表示

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Friendships
      final friendshipRef =
          FirebaseFirestore.instance.collection('friendships').doc();
      batch.set(friendshipRef, {
        'senderId': widget.currentUserId,
        'receiverId': widget.userProfile.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'userIds': [widget.currentUserId, widget.userProfile.uid],
      });

      // Notifications
      final notificationRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'friend_request',
        'fromUserId': widget.currentUserId,
        'targetUserId': widget.userProfile.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();

      if (mounted) {
        setState(() => _status = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フレンド申請を送りました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'none');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget trailingWidget;

    if (_isLoading || _status == 'loading') {
      trailingWidget = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_status == 'accepted') {
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green),
        ),
        child: const Text('フレンド',
            style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      );
    } else if (_status == 'pending' || _status == 'quest_pending') {
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey),
        ),
        child: const Text('申請中',
            style: TextStyle(
                color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      );
    } else {
      // 申請ボタン
      trailingWidget = ElevatedButton(
        onPressed: _sendFriendRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          minimumSize: const Size(0, 32),
        ),
        child: const Text('申請する', style: TextStyle(fontSize: 12)),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundImage: widget.userProfile.photoURL != null
              ? NetworkImage(widget.userProfile.photoURL!)
              : null,
          backgroundColor: Colors.grey[800],
          child: widget.userProfile.photoURL == null
              ? const Icon(Icons.person, color: Colors.white54)
              : null,
        ),
        title: Text(
          widget.userProfile.displayName ?? '名無しさん',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: widget.userProfile.accountName != null
            ? Text('@${widget.userProfile.accountName}',
                style: TextStyle(color: Colors.grey[500]))
            : null,
        trailing: trailingWidget,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ProfileScreen(userId: widget.userProfile.uid),
            ),
          );
        },
      ),
    );
  }
}
