// lib/my_quests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'create_my_quest_screen.dart';
import 'my_quest_detail_screen.dart';
import 'my_quest_post_screen.dart';
import 'completed_quests_screen.dart';

class MyQuestsScreen extends StatelessWidget {
  const MyQuestsScreen({super.key});

  // カテゴリごとのアイコンを取得
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Life':
        return Icons.home_outlined;
      case 'Study':
        return Icons.school_outlined;
      case 'Physical':
        return Icons.fitness_center_outlined;
      case 'Social':
        return Icons.people_outline;
      case 'Creative':
        return Icons.palette_outlined;
      case 'Mental':
        return Icons.self_improvement_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  // カテゴリごとの色を取得
  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Life':
        return Colors.green;
      case 'Study':
        return Colors.blue;
      case 'Physical':
        return Colors.red;
      case 'Social':
        return Colors.pink;
      case 'Creative':
        return Colors.purple;
      case 'Mental':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // カテゴリの定義順
  final List<String> categoryOrder = const [
    'Life',
    'Study',
    'Physical',
    'Social',
    'Creative',
    'Mental',
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("ログインしてください")));
    }

    final Color primaryAccent = Theme.of(context).colorScheme.primary;
    final Color secondaryTextColor = Colors.grey[400]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ▼▼▼ 3つのアクションボタン（コンパクト版） ▼▼▼
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add,
                          label: '新規作成',
                          color: primaryAccent,
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const CreateMyQuestScreen(),
                            ));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.edit_note,
                          label: '進捗を記録',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const MyQuestPostScreen(),
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.check_circle_outline,
                    label: '達成済みのクエスト',
                    color: Colors.green,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const CompletedQuestsScreen(),
                      ));
                    },
                  ),
                ],
              ),
            ),
            // ▲▲▲

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), // ボタンとの間隔を調整
              child: Text(
                '挑戦中のクエスト',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            // ▼▼▼ 挑戦中のクエスト一覧 (カテゴリ分類) ▼▼▼
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .where('uid', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'active') // 挑戦中のもののみ
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('エラーが発生しました'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 60, color: secondaryTextColor),
                          const SizedBox(height: 16),
                          Text(
                            '挑戦中のクエストはありません',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // クエストをカテゴリごとに分類
                final Map<String, List<MyQuest>> groupedQuests = {};
                for (var category in categoryOrder) {
                  groupedQuests[category] = [];
                }

                for (var doc in snapshot.data!.docs) {
                  final quest = MyQuest.fromFirestore(doc);
                  if (groupedQuests.containsKey(quest.category)) {
                    groupedQuests[quest.category]!.add(quest);
                  }
                }

                // カテゴリカードのリストを作成
                return Column(
                  children: categoryOrder.map((category) {
                    final questsInCategory = groupedQuests[category]!;
                    if (questsInCategory.isEmpty) {
                      return const SizedBox.shrink(); // クエストがなければ何も表示しない
                    }
                    // カテゴリごとのカードを返す
                    return _CategoryQuestCard(
                      categoryName: category,
                      quests: questsInCategory,
                      icon: _getIconForCategory(category),
                      color: _getColorForCategory(category),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20), // スクロール領域の確保
          ],
        ),
      ),
    );
  }
}

// ▼▼▼ [修正] アクションボタン用のウィジェット（コンパクト版） ▼▼▼
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      // カード自体の背景色を少し明るく
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!), // 枠線
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color), // アイコン
              const SizedBox(width: 10),
              // テキストがはみ出ないように Expanded で囲む
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // 文字を少し小さく
                  ),
                  overflow: TextOverflow.ellipsis, // はみ出たら...
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ▲▲▲

// ▼▼▼ [変更なし] カテゴリごとのクエストをまとめるカード ▼▼▼
class _CategoryQuestCard extends StatelessWidget {
  final String categoryName;
  final List<MyQuest> quests;
  final IconData icon;
  final Color color;

  const _CategoryQuestCard({
    required this.categoryName,
    required this.quests,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[800]!), // 枠線を少しつける
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // カテゴリヘッダー
            Container(
              color: color.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const Spacer(),
                  // クエスト数バッジ
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: color,
                    child: Text(
                      quests.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),
            ),
            // クエストリスト
            Column(
              children: quests.map((quest) {
                return _MyQuestCard(quest: quest, color: color);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
// ▲▲▲

// ▼▼▼ [変更なし] 個別のクエストを表示するカード（_CategoryQuestCard の子ウィジェット）▼▼▼
class _MyQuestCard extends StatelessWidget {
  final MyQuest quest;
  final Color color; // カテゴリ色

  const _MyQuestCard({required this.quest, required this.color});

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = Colors.grey[400]!;

    // 日付計算
    final startDate = DateTime.tryParse(quest.startDate) ?? DateTime.now();
    final endDate = DateTime.tryParse(quest.endDate) ?? DateTime.now();
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDuration =
        DateTime.now().difference(startDate).inDays.clamp(0, totalDuration);
    final progress = (totalDuration > 0)
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MyQuestDetailScreen(quest: quest),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          // 2つ目以降のクエストの上に線を入れる
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // クエストタイトル
            Text(
              quest.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            // プログレスバー
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            // 日付
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quest.startDate.replaceAll('-', '/'),
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                Text(
                  quest.endDate.replaceAll('-', '/'),
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ▲▲▲
