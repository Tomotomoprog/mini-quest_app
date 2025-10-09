import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'create_my_quest_screen.dart';

class MyQuestsScreen extends StatelessWidget {
  const MyQuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("ログインしてください")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイクエスト一覧'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('my_quests')
            .where('uid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- ここからが変更箇所 ---
          // エラーが発生した場合、その内容を画面に表示する
          if (snapshot.hasError) {
            // デバッグコンソールにもエラーを出力する
            print(' Firestore Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('エラーが発生しました:\n\n${snapshot.error}'),
              ),
            );
          }
          // --- ここまでが変更箇所 ---

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'まだマイクエストがありません。\n右下のボタンから新しい目標を立てて、冒険を始めましょう！',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final myQuests = snapshot.data!.docs
              .map((doc) => MyQuest.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: myQuests.length,
            itemBuilder: (context, index) {
              final quest = myQuests[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(quest.title),
                  subtitle: Text('${quest.startDate} 〜 ${quest.endDate}'),
                  trailing: Chip(
                    label: Text(quest.status == 'active' ? '挑戦中' : '達成済み'),
                    backgroundColor: quest.status == 'active'
                        ? Colors.blue.shade100
                        : Colors.green.shade100,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const CreateMyQuestScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '新しいマイクエストを作成',
      ),
    );
  }
}
