// lib/cheer_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'profile_screen.dart';

// ▼▼▼ クラス名を CheerListScreen に変更 ▼▼▼
class CheerListScreen extends StatefulWidget {
  final String postId;
  const CheerListScreen({super.key, required this.postId});

  @override
  State<CheerListScreen> createState() => _CheerListScreenState();
}

class _CheerListScreenState extends State<CheerListScreen> {
  late Future<List<UserProfile>> _likingUsersFuture;

  @override
  void initState() {
    super.initState();
    _likingUsersFuture = _fetchLikingUsers();
  }

  Future<List<UserProfile>> _fetchLikingUsers() async {
    try {
      // (構造は変えないので 'likes' のまま読み込む)
      final likesSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .get();

      if (likesSnapshot.docs.isEmpty) {
        return [];
      }

      final userIds = likesSnapshot.docs.map((doc) => doc.id).toList();

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return usersSnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error fetching liking users: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ▼▼▼ UIテキストを変更 ▼▼▼
        title: const Text('応援した人'),
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _likingUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            // ▼▼▼ UIテキストを変更 ▼▼▼
            return const Center(child: Text('応援したユーザーはいません。'));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child:
                        user.photoURL == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(user.displayName ?? '名無しさん',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("@${user.accountName ?? ''}"),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: user.uid),
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
