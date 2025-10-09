import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';

// メインのプロフィール画面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// ▼▼▼ ここに `with SingleTickerProviderStateMixin` を追加しました ▼▼▼
class _ProfileScreenState extends State<ProfileScreen>
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

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // レベル計算ロジック
  int _computeLevel(int xp) => (xp / 100).floor() + 1;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('ログインしていません。')));
    }

    return Scaffold(
      // NestedScrollViewを使うことで、プロフィールヘッダーをスクロールすると一緒に隠れるAppBarを実現
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: const Text('プロフィール'),
              pinned: true,
              floating: true,
              actions: [
                IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ステータス'),
                  Tab(text: '投稿'),
                  Tab(text: 'マイクエスト'),
                ],
              ),
            ),
          ];
        },
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            UserProfile userProfile;
            if (!snapshot.data!.exists) {
              // データがない場合のデフォルト値
              userProfile = UserProfile(
                  uid: user.uid,
                  displayName: user.displayName,
                  photoURL: user.photoURL,
                  xp: 0,
                  stats: UserStats());
            } else {
              userProfile = UserProfile.fromFirestore(snapshot.data!);
            }

            final level = _computeLevel(userProfile.xp);
            final xpInCurrentLevel = userProfile.xp - ((level - 1) * 100);
            final progressPercentage = xpInCurrentLevel / 100.0;

            return TabBarView(
              controller: _tabController,
              children: [
                // 各タブの中身
                _ProfileStatsTab(
                    userProfile: userProfile,
                    level: level,
                    progress: progressPercentage,
                    xpInLevel: xpInCurrentLevel),
                _ProfilePostsTab(userId: user.uid),
                _ProfileMyQuestsTab(userId: user.uid),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- ステータスタブ ---
class _ProfileStatsTab extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final double progress;
  final int xpInLevel;

  const _ProfileStatsTab(
      {required this.userProfile,
      required this.level,
      required this.progress,
      required this.xpInLevel});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // プロフィールヘッダー
          CircleAvatar(
            radius: 40,
            backgroundImage: userProfile.photoURL != null
                ? NetworkImage(userProfile.photoURL!)
                : null,
            child: userProfile.photoURL == null
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          const SizedBox(height: 12),
          Text(userProfile.displayName ?? '名無しさん',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          // レベルと進捗
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level $level',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('$xpInLevel / 100 XP'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // 各ステータス
          _StatRow(
              label: 'Life',
              value: userProfile.stats.life,
              color: Colors.green),
          _StatRow(
              label: 'Study',
              value: userProfile.stats.study,
              color: Colors.blue),
          _StatRow(
              label: 'Physical',
              value: userProfile.stats.physical,
              color: Colors.red),
          _StatRow(
              label: 'Social',
              value: userProfile.stats.social,
              color: Colors.pink),
          _StatRow(
              label: 'Creative',
              value: userProfile.stats.creative,
              color: Colors.purple),
          _StatRow(
              label: 'Mental',
              value: userProfile.stats.mental,
              color: Colors.indigo),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.shield, color: color),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value.toString(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- 自分の投稿一覧タブ ---
class _ProfilePostsTab extends StatelessWidget {
  final String userId;
  const _ProfilePostsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('まだ投稿がありません。'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = Post.fromFirestore(snapshot.data!.docs[index]);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(title: Text(post.text)),
            );
          },
        );
      },
    );
  }
}

// --- 自分のマイクエスト一覧タブ ---
class _ProfileMyQuestsTab extends StatelessWidget {
  final String userId;
  const _ProfileMyQuestsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('my_quests')
          .where('uid', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('マイクエストはまだありません。'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final quest = MyQuest.fromFirestore(snapshot.data!.docs[index]);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(title: Text(quest.title)),
            );
          },
        );
      },
    );
  }
}
