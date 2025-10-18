import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'profile_screen.dart';
import 'models/friendship.dart'; // FriendshipStatus を使うためにインポート

class ProfileFriendsListScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ProfileFriendsListScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  // Firestoreからユーザーのフレンド情報を取得する
  Future<List<UserProfile>> _getFriends() async {
    final friendshipsSnapshot = await FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: userId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendIds = friendshipsSnapshot.docs
        .map((doc) {
          final userIds = doc.data()['userIds'] as List;
          // 相手のIDを取得 (自分ではない方のID)
          return userIds.firstWhere((id) => id != userId, orElse: () => null);
        })
        .where((id) => id != null)
        .toList(); // nullを除外

    if (friendIds.isEmpty) return [];

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    return usersSnapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${userName}のフレンド'),
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _getFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('フレンド情報の取得に失敗しました。'));
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
              // ログイン中のユーザー自身は表示しない
              if (friend.uid == FirebaseAuth.instance.currentUser?.uid) {
                return const SizedBox.shrink(); // 何も表示しない
              }
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend.photoURL != null
                        ? NetworkImage(friend.photoURL!)
                        : null,
                    child: friend.photoURL == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(friend.displayName ?? '名無しさん',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  // ユーザー検索カードにあった申請ボタンなどは不要なので削除
                  onTap: () {
                    // タップしたらそのフレンドのプロフィール画面へ遷移
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        // ProfileScreenに正しい引数を渡す
                        builder: (context) => ProfileScreen(userId: friend.uid),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
