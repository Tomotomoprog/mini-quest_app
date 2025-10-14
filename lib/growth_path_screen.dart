import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';
import 'artisan_workshop_screen.dart';

// 成長の道に表示する各機能のモデル
class GrowthMilestone {
  final String title;
  final String description;
  final IconData icon;
  final int unlockLevel;
  final Widget? destination; // 遷移先の画面

  GrowthMilestone({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockLevel,
    this.destination,
  });
}

class GrowthPathScreen extends StatelessWidget {
  const GrowthPathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("ログインしてください")));

    // 設計案に基づいたマイルストーンのリスト
    final milestones = [
      GrowthMilestone(
          title: "思い出の噴水",
          description: "過去の投稿がランダムで表示され、頑張りを振り返れます。",
          icon: Icons.water_drop,
          unlockLevel: 5),
      GrowthMilestone(
          title: "やすらぎの庭園",
          description: "種を植えて素材やコインを収穫できます。",
          icon: Icons.yard,
          unlockLevel: 8),
      GrowthMilestone(
          title: "ギルドハウス",
          description: "フレンドとギルドを結成し、協力クエストに挑戦できます。",
          icon: Icons.shield,
          unlockLevel: 10),
      GrowthMilestone(
          title: "職人の工房",
          description: "素材を使ってアバターの装備（スキン）を作成できます。",
          icon: Icons.construction,
          unlockLevel: 15,
          destination: const ArtisanWorkshopScreen()),
      GrowthMilestone(
          title: "旅人たちの交易所",
          description: "他のプレイヤーと素材やアイテムを交換できます。",
          icon: Icons.store,
          unlockLevel: 20),
      GrowthMilestone(
          title: "英雄の記念碑",
          description: "あなたの功績を飾り、二次職への転職を行えます。",
          icon: Icons.military_tech,
          unlockLevel: 25),
      GrowthMilestone(
          title: "知の図書館",
          description: "過去の記録を分析し、AIが月間レポートを生成します。",
          icon: Icons.menu_book,
          unlockLevel: 30),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('成長の道'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userProfile = UserProfile.fromFirestore(snapshot.data!);
          final currentLevel = computeLevel(userProfile.xp);

          List<Widget> pathItems = [];

          pathItems.add(_NoviceIntroductionCard(currentLevel: currentLevel));

          for (var milestone in milestones) {
            if (milestone.unlockLevel == 10) {
              pathItems.add(_JobIntroductionCard(currentLevel: currentLevel));
            }
            pathItems.add(_MilestoneCard(
                milestone: milestone, currentLevel: currentLevel));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: pathItems,
          );
        },
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestone,
    required this.currentLevel,
  });

  final GrowthMilestone milestone;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final isUnlocked = currentLevel >= milestone.unlockLevel;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isUnlocked ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnlocked
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: (isUnlocked && milestone.destination != null)
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => milestone.destination!),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isUnlocked
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey.shade200,
                child: Icon(
                  isUnlocked ? milestone.icon : Icons.lock_outline,
                  color: isUnlocked
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? null : Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text('Lv', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    '${milestone.unlockLevel}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isUnlocked
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoviceIntroductionCard extends StatelessWidget {
  final int currentLevel;
  const _NoviceIntroductionCard({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    const unlockLevel = 1;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.brown.withOpacity(0.1),
                  // ▼▼▼ アイコンを修正 ▼▼▼
                  child: Icon(Icons.explore, color: Colors.brown.shade700),
                  // ▲▲▲ アイコンを修正 ▲▲▲
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'すべての冒険のはじまり',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  children: [
                    Text('Lv', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '$unlockLevel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.brown.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ようこそ、冒険者よ！\nすべてのプレイヤーは、無限の可能性を秘めた「見習い」からその一歩を踏み出します。日々の挑戦を記録し、レベル10に到達すると、あなたの努力に応じた専門的な職業への道が開かれます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobIntroductionCard extends StatelessWidget {
  final int currentLevel;
  const _JobIntroductionCard({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    const unlockLevel = 10;
    final isUnlocked = currentLevel >= unlockLevel;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isUnlocked ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnlocked
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isUnlocked
                      ? Colors.amber.withOpacity(0.1)
                      : Colors.grey.shade200,
                  child: Icon(
                    isUnlocked ? Icons.star_outline : Icons.lock_outline,
                    color: isUnlocked
                        ? Colors.amber.shade700
                        : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '一次職への転職',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? null : Colors.grey.shade600,
                        ),
                  ),
                ),
                Column(
                  children: [
                    Text('Lv', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '$unlockLevel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: isUnlocked
                                ? Colors.amber.shade700
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'レベル10に到達すると、これまでのあなたの「挑戦の記録」に応じて、専門的な職業（ジョブ）に転職できます。あなたの冒険は、ここから新たな章へ進みます。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Divider(height: 24),
            Text(
              'どんな職業があるの？',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const _JobDescription(
                job: '戦士',
                description: '運動(Physical)の記録に特化することで転職。身体を鍛える記録で成長します。'),
            const _JobDescription(
                job: '魔術師',
                description:
                    '学習(Study)と内省(Mental)の記録をバランス良く行うことで転職。知的な活動で成長します。'),
            const _JobDescription(
                job: '治癒士',
                description:
                    '交流(Social)と生活(Life)の記録をバランス良く行うことで転職。人との交流や丁寧な暮らしで成長します。'),
            const _JobDescription(
                job: '芸術家',
                description: '創造(Creative)の記録に特化することで転職。創作活動の記録で成長します。'),
            const _JobDescription(
                job: '冒険家',
                description:
                    '生活(Life)と運動(Physical)の記録をバランス良く行うことで転職。日常の探求活動で成長します。'),
          ],
        ),
      ),
    );
  }
}

class _JobDescription extends StatelessWidget {
  final String job;
  final String description;
  const _JobDescription({required this.job, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('・$job: ',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(description,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
