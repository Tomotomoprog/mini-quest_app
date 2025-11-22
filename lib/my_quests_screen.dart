// lib/my_quests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'create_my_quest_screen.dart';
import 'my_quest_detail_screen.dart';
import 'my_quest_post_screen.dart';
import 'models/user_profile.dart';
import 'profile_screen.dart';
import 'motivation_columns_screen.dart'; // ◀◀◀ 追加: コラム画面をインポート

class MyQuestsScreen extends StatelessWidget {
  const MyQuestsScreen({super.key});

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
        // ▼▼▼ 追加: コラム画面への遷移ボタン ▼▼▼
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: '冒険の書（コラム）',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MotivationColumnsScreen(),
                ),
              );
            },
          ),
        ],
        // ▲▲▲
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- アクションボタン群 ---
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.add,
                      label: '長期目標の設定',
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _ActionButton(
                icon: Icons.campaign,
                label: '今日頑張ったことを一言で！',
                color: Colors.orange,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) =>
                        const MyQuestPostScreen(isShortPost: true),
                  ));
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'マイクエスト一覧',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),

            // --- クエスト一覧 ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .where(
                    Filter.or(
                      Filter('uid', isEqualTo: user.uid),
                      Filter('participantIds', arrayContains: user.uid),
                    ),
                  )
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map<String, List<MyQuest>> activeQuestsMap = {};
                final Map<String, List<MyQuest>> completedQuestsMap = {};

                for (var category in categoryOrder) {
                  activeQuestsMap[category] = [];
                  completedQuestsMap[category] = [];
                }

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  for (var doc in snapshot.data!.docs) {
                    final quest = MyQuest.fromFirestore(doc);
                    if (!activeQuestsMap.containsKey(quest.category)) continue;

                    if (quest.status == 'completed') {
                      completedQuestsMap[quest.category]!.add(quest);
                    } else if (quest.status == 'active') {
                      activeQuestsMap[quest.category]!.add(quest);
                    }
                  }
                }

                return Column(
                  children: categoryOrder.map((category) {
                    final activeList = activeQuestsMap[category]!;
                    final completedList = completedQuestsMap[category]!;

                    return _CategoryExpansionCard(
                      categoryName: category,
                      activeQuests: activeList,
                      completedQuests: completedList,
                      icon: _getIconForCategory(category),
                      color: _getColorForCategory(category),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    super.key,
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
        side: BorderSide(color: Colors.grey[800]!),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
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

class _CategoryExpansionCard extends StatelessWidget {
  final String categoryName;
  final List<MyQuest> activeQuests;
  final List<MyQuest> completedQuests;
  final IconData icon;
  final Color color;

  const _CategoryExpansionCard({
    required this.categoryName,
    required this.activeQuests,
    required this.completedQuests,
    required this.icon,
    required this.color,
  });

  Widget _buildQuestStats(String myQuestId) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .where('myQuestId', isEqualTo: myQuestId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2));
        }

        int totalCheers = 0;
        double totalHours = 0.0;

        if (snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final likeCount = data['likeCount'] as num? ?? 0;
            totalCheers += likeCount.toInt();
            final timeSpent = data['timeSpentHours'] as num? ?? 0.0;
            totalHours += timeSpent.toDouble();
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department,
                color: Colors.pink[200], size: 16),
            const SizedBox(width: 4),
            Text(
              '$totalCheers',
              style: TextStyle(
                color: Colors.pink[200],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.timer_outlined, color: Colors.orange[300], size: 16),
            const SizedBox(width: 4),
            Text(
              '${totalHours.toStringAsFixed(1)}h',
              style: TextStyle(
                color: Colors.orange[300],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int activeCount = activeQuests.length;
    final int completedCount = completedQuests.length;
    final bool isEmpty = activeQuests.isEmpty && completedQuests.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        elevation: 0,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isEmpty ? Colors.grey[800]! : color.withOpacity(0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(icon, color: isEmpty ? Colors.grey : color),
            title: Text(
              categoryName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isEmpty ? Colors.grey : color,
                fontSize: 16,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isEmpty ? Colors.grey[800] : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(
                  color: isEmpty ? Colors.grey : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'このジャンルのクエストはまだありません',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    )
                  ]
                : [
                    if (activeQuests.isNotEmpty)
                      ...activeQuests.map((quest) {
                        return _MyQuestCard(
                          quest: quest,
                          color: color,
                          statsWidget: _buildQuestStats(quest.id),
                        );
                      }),
                    if (completedQuests.isNotEmpty) ...[
                      if (activeQuests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey[800])),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: Colors.amber[200], size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "達成済み ($completedCount)",
                                      style: TextStyle(
                                          color: Colors.amber[200],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey[800])),
                            ],
                          ),
                        ),
                      ...completedQuests.map((quest) {
                        return _MyQuestCard(
                          quest: quest,
                          color: color,
                          isCompletedSection: true,
                          statsWidget: _buildQuestStats(quest.id),
                        );
                      }),
                    ],
                  ],
          ),
        ),
      ),
    );
  }
}

class _MyQuestCard extends StatelessWidget {
  final MyQuest quest;
  final Color color;
  final Widget statsWidget;
  final bool isCompletedSection;

  const _MyQuestCard({
    required this.quest,
    required this.color,
    required this.statsWidget,
    this.isCompletedSection = false,
  });

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

    final BorderSide borderSide = isCompletedSection
        ? BorderSide(color: Colors.amber.withOpacity(0.6), width: 1.5)
        : BorderSide(color: Colors.grey[800]!);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MyQuestDetailScreen(quest: quest),
        ));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[850]!.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(borderSide),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (quest.type != 'personal') ...[
                  Icon(
                    quest.type == 'battle' ? Icons.emoji_events : Icons.group,
                    size: 16,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    quest.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (quest.status == 'completed')
                  const Icon(Icons.workspace_premium,
                      color: Colors.amber, size: 20)
                else
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.grey[700], size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                statsWidget,
                const Spacer(),
                if (isCompletedSection)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.5))),
                    child: Row(
                      children: const [
                        Icon(Icons.check, size: 12, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 10),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    '残り ${totalDuration - elapsedDuration} 日',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: isCompletedSection ? 1.0 : progress,
              backgroundColor: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              minHeight: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isCompletedSection ? Colors.amber : color),
            ),
          ],
        ),
      ),
    );
  }
}
