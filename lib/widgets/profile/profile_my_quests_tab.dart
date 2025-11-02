// lib/widgets/profile/profile_my_quests_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/my_quest.dart';
import '../../my_quest_detail_screen.dart';
import '../../completed_quests_screen.dart'; // ◀◀◀ 達成済み画面をインポート

// ▼▼▼ my_quests_screen.dart から必要なウィジェット/メソッドを移植 ▼▼▼

// アクションボタン（達成済みボタン）
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
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

// カテゴリごとのクエストをまとめるカード
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
          side: BorderSide(color: Colors.grey[800]!),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
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

// 個別のクエストを表示するカード
class _MyQuestCard extends StatelessWidget {
  final MyQuest quest;
  final Color color;

  const _MyQuestCard({required this.quest, required this.color});

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = Colors.grey[400]!;

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
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quest.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
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
// ▲▲▲ ここまで移植 ▲▲▲

class ProfileMyQuestsTab extends StatelessWidget {
  final String userId;
  const ProfileMyQuestsTab({super.key, required this.userId});

  // ▼▼▼ メソッドを移植 ▼▼▼
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

  final List<String> categoryOrder = const [
    'Life',
    'Study',
    'Physical',
    'Social',
    'Creative',
    'Mental',
  ];
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ my_quests_screen.dart の build ロジックを移植・修正 ▼▼▼
    final Color secondaryTextColor = Colors.grey[400]!;

    // プロフィールタブ内はスクロール不要な場合が多いため、
    // SingleChildScrollView ではなく ListView を使用
    return ListView(
      children: [
        // 「達成済みのマイクエスト」ボタンのみ配置
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _ActionButton(
            icon: Icons.check_circle_outline,
            label: '達成済みのクエスト',
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                // ◀◀◀ 遷移先を CompletedQuestsScreen に修正
                builder: (context) => const CompletedQuestsScreen(),
              ));
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            '挑戦中のクエスト',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('my_quests')
              .where('uid', isEqualTo: userId) // ◀◀◀ 引数の userId を使用
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ));
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
                        // ◀◀◀ ログインユーザーか否かでテキストを変更
                        userId == FirebaseAuth.instance.currentUser?.uid
                            ? '挑戦中のクエストはありません'
                            : '挑戦中のクエストはありません',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

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

            // ListView の中に Column を直接入れると描画エラーになるため、
            // Column ではなく ListView.builder や Column(shrinkWrap: true) を使う
            return Column(
              children: categoryOrder.map((category) {
                final questsInCategory = groupedQuests[category]!;
                if (questsInCategory.isEmpty) {
                  return const SizedBox.shrink();
                }
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
        const SizedBox(height: 20),
      ],
    );
    // ▲▲▲
  }
}
