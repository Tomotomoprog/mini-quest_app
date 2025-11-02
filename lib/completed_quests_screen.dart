// lib/completed_quests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'my_quest_detail_screen.dart';

class CompletedQuestsScreen extends StatelessWidget {
  const CompletedQuestsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("ログインしてください")));
    }

    final Color secondaryTextColor = Colors.grey[400]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('達成済みのクエスト'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('my_quests')
            .where('uid', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed') // 達成済みのもののみ
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 60, color: secondaryTextColor),
                    const SizedBox(height: 16),
                    Text(
                      'まだ達成済みのクエストはありません。',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final myQuests = snapshot.data!.docs
              .map((doc) => MyQuest.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: myQuests.length,
            itemBuilder: (context, index) {
              final quest = myQuests[index];
              final categoryColor = _getColorForCategory(quest.category);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MyQuestDetailScreen(quest: quest),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: categoryColor, width: 5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(
                                  _getIconForCategory(quest.category),
                                  color: categoryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  quest.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 達成済みチップ
                              Chip(
                                label: const Text(
                                  '達成済み',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.green.withOpacity(0.7),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 期間
                          Text(
                            '期間: ${quest.startDate.replaceAll('-', '/')} 〜 ${quest.endDate.replaceAll('-', '/')}',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
