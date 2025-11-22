// lib/widgets/profile/profile_my_quests_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/my_quest.dart';
import '../../my_quest_detail_screen.dart';

class ProfileMyQuestsTab extends StatelessWidget {
  final String userId;
  const ProfileMyQuestsTab({super.key, required this.userId});

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
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'クエスト一覧',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('my_quests')
              .where(
                Filter.or(
                  Filter('uid', isEqualTo: userId),
                  Filter('participantIds', arrayContains: userId),
                ),
              )
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

            final docs = snapshot.hasData ? snapshot.data!.docs : [];

            final Map<String, List<MyQuest>> activeQuestsMap = {};
            final Map<String, List<MyQuest>> completedQuestsMap = {};

            for (var category in categoryOrder) {
              activeQuestsMap[category] = [];
              completedQuestsMap[category] = [];
            }

            for (var doc in docs) {
              final quest = MyQuest.fromFirestore(doc);
              if (!activeQuestsMap.containsKey(quest.category)) continue;

              if (quest.status == 'completed') {
                completedQuestsMap[quest.category]!.add(quest);
              } else if (quest.status == 'active') {
                activeQuestsMap[quest.category]!.add(quest);
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
      ],
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
  final bool isCompletedSection;

  const _MyQuestCard({
    required this.quest,
    required this.color,
    this.isCompletedSection = false,
  });

  // 順位の色を返すヘルパー
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade700; // 金
      case 2:
        return Colors.blueGrey.shade400; // 銀
      case 3:
        return Colors.brown.shade400; // 銅
      default:
        return Colors.grey.shade600;
    }
  }

  // 参加者と順位を表示するウィジェット
  Widget _buildParticipants(BuildContext context, Map<String, int> rankingMap) {
    if (quest.participantIds.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId,
                whereIn: quest.participantIds.take(5).toList())
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final users = snapshot.data!.docs;

          return Row(
            children: [
              SizedBox(
                height: 24,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final photoURL = data['photoURL'] as String?;
                    final uid = users[index].id;
                    final rank = rankingMap[uid];

                    return Align(
                      widthFactor: 0.8,
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[850],
                            child: CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.grey[700],
                              backgroundImage: photoURL != null
                                  ? NetworkImage(photoURL)
                                  : null,
                              child: photoURL == null
                                  ? const Icon(Icons.person,
                                      size: 12, color: Colors.white54)
                                  : null,
                            ),
                          ),
                          // ▼▼▼ 順位バッジ (バトルの場合のみ) ▼▼▼
                          if (quest.type == 'battle' && rank != null)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getRankColor(rank),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  '$rank',
                                  style: const TextStyle(
                                      fontSize: 6,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          // ▲▲▲
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (quest.participantIds.length > 5)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '+${quest.participantIds.length - 5}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

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

    // ▼▼▼ 投稿データを取得して統計とランキングを計算 ▼▼▼
    return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .where('myQuestId', isEqualTo: quest.id)
            .get(),
        builder: (context, snapshot) {
          int totalCheers = 0;
          double totalHours = 0.0;
          Map<String, int> rankingMap = {};

          if (snapshot.hasData) {
            Map<String, double> scores = {};
            // 初期化
            for (var uid in quest.participantIds) {
              scores[uid] = 0.0;
            }

            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final uid = data['uid'] as String? ?? '';

              final likeCount = (data['likeCount'] as num? ?? 0).toInt();
              final timeSpent =
                  (data['timeSpentHours'] as num? ?? 0.0).toDouble();

              totalCheers += likeCount;
              totalHours += timeSpent;

              // スコア計算 (ランキング用)
              if (scores.containsKey(uid)) {
                scores[uid] =
                    (scores[uid] ?? 0) + (timeSpent * 10) + 5 + (likeCount * 2);
              }
            }

            // ランキング生成
            if (quest.type == 'battle') {
              var sortedEntries = scores.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              for (int i = 0; i < sortedEntries.length; i++) {
                rankingMap[sortedEntries[i].key] = i + 1;
              }
            }
          }

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
                          quest.type == 'battle'
                              ? Icons.emoji_events
                              : Icons.group,
                          size: 16,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          quest.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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

                  const SizedBox(height: 4),
                  // 参加者表示 (ランキング情報付き)
                  _buildParticipants(context, rankingMap),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 統計情報 (応援数 & 時間)
                      Icon(Icons.local_fire_department,
                          color: Colors.pink[200], size: 16),
                      const SizedBox(width: 4),
                      Text('$totalCheers',
                          style: TextStyle(
                              color: Colors.pink[200],
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(Icons.timer_outlined,
                          color: Colors.orange[300], size: 16),
                      const SizedBox(width: 4),
                      Text('${totalHours.toStringAsFixed(1)}h',
                          style: TextStyle(
                              color: Colors.orange[300],
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),

                      const Spacer(),
                      if (isCompletedSection)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.5))),
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
                          style: TextStyle(
                              color: secondaryTextColor, fontSize: 12),
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
        });
  }
}
