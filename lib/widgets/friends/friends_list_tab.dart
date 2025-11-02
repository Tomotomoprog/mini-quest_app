// lib/widgets/friends/friends_list_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/friendship.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../profile_screen.dart';
import '../../utils/progression.dart'; // レベル計算用

// ランキング表示用のヘルパークラス
class RankingEntry {
  final UserProfile user;
  final double totalHours;
  RankingEntry({required this.user, required this.totalHours});
}

class FriendsListTab extends StatefulWidget {
  const FriendsListTab({super.key});

  @override
  State<FriendsListTab> createState() => _FriendsListTabState();
}

class _FriendsListTabState extends State<FriendsListTab> {
  late Future<List<RankingEntry>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _fetchWeeklyRanking();
  }

  // (ここからランキング用ロジック)

  DateTime _getStartOfWeek() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday - 1;
    final startOfDay = DateTime(now.year, now.month, now.day);
    return startOfDay.subtract(Duration(days: daysToSubtract));
  }

  Future<List<UserProfile>> _getAllFriendProfiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final myId = user.uid;
    List<UserProfile> allProfiles = [];

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(myId).get();
      if (userDoc.exists) {
        allProfiles.add(UserProfile.fromFirestore(userDoc));
      }
    } catch (e) {
      print("自分のプロフィールの取得に失敗: $e");
    }

    final friendshipsSnapshot = await FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: myId)
        .where('status', isEqualTo: 'accepted')
        .get();
    final friendIds = friendshipsSnapshot.docs
        .map((doc) {
          final userIds = doc.data()['userIds'] as List;
          return userIds.firstWhere((id) => id != myId, orElse: () => null);
        })
        .where((id) => id != null)
        .toList();

    if (friendIds.isEmpty) return allProfiles;

    for (var i = 0; i < friendIds.length; i += 10) {
      final batchIds = friendIds.sublist(
          i, i + 10 > friendIds.length ? friendIds.length : i + 10);
      try {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        allProfiles.addAll(
            usersSnapshot.docs.map((doc) => UserProfile.fromFirestore(doc)));
      } catch (e) {
        print("フレンドプロフィールのバッチ取得に失敗: $e");
      }
    }
    return allProfiles;
  }

  Future<List<RankingEntry>> _fetchWeeklyRanking() async {
    final allProfiles = await _getAllFriendProfiles();
    if (allProfiles.isEmpty) return [];

    final startOfWeek = _getStartOfWeek();
    final Map<String, double> userHours = {};

    for (var profile in allProfiles) {
      userHours[profile.uid] = 0.0;
      try {
        final postsSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('uid', isEqualTo: profile.uid)
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
            .get();
        double hoursForThisUser = 0.0;
        for (final doc in postsSnapshot.docs) {
          final post = Post.fromFirestore(doc);
          hoursForThisUser += (post.timeSpentHours ?? 0.0);
        }
        userHours[profile.uid] = hoursForThisUser;
      } catch (e) {
        print("投稿の取得エラー (User: ${profile.uid}): $e");
        if (e is FirebaseException && e.code == 'failed-precondition') {
          rethrow;
        }
      }
    }

    final rankingEntries = allProfiles.map((profile) {
      return RankingEntry(
        user: profile,
        totalHours: userHours[profile.uid] ?? 0.0,
      );
    }).toList();

    rankingEntries.sort((a, b) => b.totalHours.compareTo(a.totalHours));
    return rankingEntries.take(10).toList();
  }

  Widget _buildRankingSection() {
    return FutureBuilder<List<RankingEntry>>(
      future: _rankingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (snapshot.hasError) {
          if (snapshot.error is FirebaseException &&
              (snapshot.error as FirebaseException).code ==
                  'failed-precondition') {
            return Card(
              color: Colors.red[900]?.withOpacity(0.5),
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'ランキングの表示に失敗しました。\n必要なデータベースインデックスがありません。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '（エラーコード: ${(snapshot.error as FirebaseException).message}）',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('ランキングの読み込みエラー: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('ランキングデータがありません。'));
        }

        final ranking = snapshot.data!;

        return Card(
          elevation: 0,
          color: Colors.grey[900],
          margin: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '今週の努力時間ランキング',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListView.builder(
                itemCount: ranking.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final entry = ranking[index];
                  final level = computeLevel(entry.user.xp);
                  final jobInfo = computeJob(entry.user.stats, level);

                  Widget leadingWidget;
                  if (index == 0) {
                    leadingWidget =
                        const Icon(Icons.emoji_events, color: Colors.amber);
                  } else if (index == 1) {
                    leadingWidget =
                        Icon(Icons.emoji_events, color: Colors.grey[400]);
                  } else if (index == 2) {
                    leadingWidget =
                        Icon(Icons.emoji_events, color: Colors.brown[400]);
                  } else {
                    leadingWidget = CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey[700],
                      child: Text(
                        (index + 1).toString(),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  return ListTile(
                    leading: SizedBox(
                        width: 24, child: Center(child: leadingWidget)),
                    title: Text(entry.user.displayName ?? '名無しさん',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Lv.$level・${jobInfo.title}'),
                    trailing: Text(
                      '${entry.totalHours.toStringAsFixed(1)} h',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userId: entry.user.uid),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // (ここからフレンドリスト用ロジック)

  Widget _buildFriendsList(FriendshipStatus status) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    late Query streamQuery;

    if (status == FriendshipStatus.accepted) {
      streamQuery = FirebaseFirestore.instance
          .collection('friendships')
          .where('userIds', arrayContains: currentUid)
          .where('status', isEqualTo: 'accepted');
    } else {
      streamQuery = FirebaseFirestore.instance
          .collection('friendships')
          .where('receiverId', isEqualTo: currentUid)
          .where('status', isEqualTo: status.name);
    }

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
                    trailing: status != FriendshipStatus.accepted
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
                        : null,
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

    List<UserProfile> users = [];
    for (var i = 0; i < userIds.length; i += 10) {
      final batchIds =
          userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();
      users.addAll(userDocs.docs.map((doc) => UserProfile.fromFirestore(doc)));
    }
    return users;
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

  // ▼▼▼ ここから build メソッド ▼▼▼
  @override
  Widget build(BuildContext context) {
    // ▼▼▼ SingleChildScrollView で全体をラップしてスクロール可能に ▼▼▼
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▼▼▼ ランキングの表示位置をフレンド申請の下に変更 ▼▼▼

          // 1. 探す欄からのフレンド申請
          Text('探す欄からのフレンド申請', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(FriendshipStatus.quest_pending),
          const SizedBox(height: 24),

          // 2. 通常のフレンド申請
          Text('フレンド申請', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(FriendshipStatus.pending),
          const SizedBox(height: 24),

          // 3. ランキングセクション
          _buildRankingSection(), // ◀◀◀ ランキングをここに移動
          const SizedBox(height: 24),

          // 4. フレンド一覧
          Text('フレンド', style: Theme.of(context).textTheme.titleLarge),
          _buildFriendsList(FriendshipStatus.accepted),
          // ▲▲▲
        ],
      ),
    );
  }
}
