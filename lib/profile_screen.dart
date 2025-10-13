import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/ability.dart';
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';
import 'sanctuary_screen.dart'; // SanctuaryScreenをインポート
import 'utils/ability_service.dart';
import 'utils/progression.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

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

  bool get _isMyProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('ユーザーが見つかりません。'));
          }

          final userProfile = UserProfile.fromFirestore(snapshot.data!);
          final progress = computeXpProgress(userProfile.xp);
          final level = progress['level']!;
          final xpInCurrentLevel = progress['xpInCurrentLevel']!;
          final xpNeededForNextLevel = progress['xpNeededForNextLevel']!;
          final classInfo = computeClass(userProfile.stats, level);
          final abilities =
              AbilityService.getAbilitiesForClass(classInfo.title);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text('プロフィール'),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  actions: [
                    if (_isMyProfile)
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      )
                  ],
                  expandedHeight: 300.0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _ProfileHeader(
                      userProfile: userProfile,
                      level: level,
                      classInfo: classInfo,
                      xpInLevel: xpInCurrentLevel,
                      xpNeeded: xpNeededForNextLevel,
                    ),
                  ),
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
            body: TabBarView(
              controller: _tabController,
              children: [
                _ProfileStatsTab(
                    userProfile: userProfile, abilities: abilities),
                _ProfilePostsTab(userId: widget.userId),
                _ProfileMyQuestsTab(userId: widget.userId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final ClassResult classInfo;
  final int xpInLevel;
  final int xpNeeded;

  const _ProfileHeader({
    required this.userProfile,
    required this.level,
    required this.classInfo,
    required this.xpInLevel,
    required this.xpNeeded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
        child: Column(
          children: [
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('レベル', style: Theme.of(context).textTheme.bodySmall),
                    Text(level.toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                Column(
                  children: [
                    Text('クラス', style: Theme.of(context).textTheme.bodySmall),
                    Text(classInfo.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressBar(
              value: xpInLevel,
              max: xpNeeded,
              label: '次のレベルまで',
              color: Colors.amber,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatsTab extends StatelessWidget {
  final UserProfile userProfile;
  final List<Ability> abilities;

  const _ProfileStatsTab({required this.userProfile, required this.abilities});

  static const categoryColors = {
    'Life': Color(0xFF22C55E),
    'Study': Color(0xFF3B82F6),
    'Physical': Color(0xFFEF4444),
    'Social': Color(0xFFEC4899),
    'Creative': Color(0xFFA855F7),
    'Mental': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ▼▼▼ サンクチュアリへのボタンを追加 ▼▼▼
          ElevatedButton.icon(
            icon: const Icon(Icons.fort),
            label: const Text('サンクチュアリへ'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const SanctuaryScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ProgressBar(
                      label: 'Life',
                      value: userProfile.stats.life,
                      max: 10,
                      color: categoryColors['Life']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Study',
                      value: userProfile.stats.study,
                      max: 10,
                      color: categoryColors['Study']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Physical',
                      value: userProfile.stats.physical,
                      max: 10,
                      color: categoryColors['Physical']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Social',
                      value: userProfile.stats.social,
                      max: 10,
                      color: categoryColors['Social']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Creative',
                      value: userProfile.stats.creative,
                      max: 10,
                      color: categoryColors['Creative']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Mental',
                      value: userProfile.stats.mental,
                      max: 10,
                      color: categoryColors['Mental']!),
                ],
              ),
            ),
          ),
          if (abilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('アビリティ', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...abilities.map((ability) => Card(
                        child: ListTile(
                          leading: Icon(ability.icon,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(ability.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(ability.description),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _ProgressBar(
      {required this.label,
      required this.value,
      required this.max,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$value / $max'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / max,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

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
