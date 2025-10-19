// lib/my_quests_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'create_my_quest_screen.dart';
import 'my_quest_detail_screen.dart';
// import 'post_screen.dart'; // ← PostScreenのimportは削除またはコメントアウト
import 'my_quest_post_screen.dart'; // ← 新しい画面をインポート

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("ログインしてください")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'あなたの冒険のコンパス',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '長期的な目標を設定して、日々の記録を特別な冒険に変えましょう。クエストの進捗を記録することで、あなたのジョブはさらに成長します。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                // ▼▼▼ タップ時の遷移先を変更 ▼▼▼
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) =>
                            const MyQuestPostScreen()), // initialQuestなしで開く
                  );
                },
                // ▲▲▲ タップ時の遷移先を変更 ▲▲▲
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, // アイコンも変更推奨
                          color: Theme.of(context).primaryColor,
                          size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          // ▼▼▼ ラベルを変更 ▼▼▼
                          'マイクエストの進捗を記録',
                          // ▲▲▲ ラベルを変更 ▲▲▲
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .where('uid', isEqualTo: user.uid)
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'まだマイクエストがありません。',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '右下のボタンから新しい目標を立てて、\n冒険を始めましょう！',
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
                    final startDate =
                        DateTime.tryParse(quest.startDate) ?? DateTime.now();
                    final endDate =
                        DateTime.tryParse(quest.endDate) ?? DateTime.now();
                    final totalDuration = endDate.difference(startDate).inDays;
                    final elapsedDuration =
                        DateTime.now().difference(startDate).inDays;
                    final progress = (totalDuration > 0)
                        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
                        : 0.0;

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
                              builder: (context) =>
                                  MyQuestDetailScreen(quest: quest),
                            ),
                          );
                        },
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
                                        color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      quest.title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                        quest.status == 'active'
                                            ? '挑戦中'
                                            : '達成済み',
                                        style: const TextStyle(fontSize: 12)),
                                    backgroundColor: quest.status == 'active'
                                        ? Colors.blue.shade100
                                        : Colors.green.shade100,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (quest.status == 'active')
                                Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            quest.startDate
                                                .replaceAll('-', '/'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                        Text(quest.endDate.replaceAll('-', '/'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ],
                                    ),
                                  ],
                                ),
                              if (quest.status != 'active')
                                Text(
                                  '期間: ${quest.startDate.replaceAll('-', '/')} 〜 ${quest.endDate.replaceAll('-', '/')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // ▼▼▼ FABはマイクエスト作成画面への遷移に変更 ▼▼▼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const CreateMyQuestScreen()),
          );
        },
        tooltip: '新しいマイクエストを作成',
        child: const Icon(Icons.add),
      ),
      // ▲▲▲ FABはマイクエスト作成画面への遷移に変更 ▲▲▲
    );
  }
}
