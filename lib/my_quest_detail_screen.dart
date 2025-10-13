import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/my_quest.dart';
import 'models/post.dart';

class MyQuestDetailScreen extends StatelessWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(quest.title),
      ),
      body: CustomScrollView(
        slivers: [
          // クエストの詳細情報を表示するヘッダー部分
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(quest.category)),
                  const SizedBox(height: 8),
                  Text(quest.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('${quest.startDate} 〜 ${quest.endDate}',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 16),
                  const Text('意気込み:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(quest.motivation),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text('冒険の記録',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // 関連する投稿をリスト表示する部分
          StreamBuilder<QuerySnapshot>(
            // myQuestIdが一致する投稿のみを取得する
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('myQuestId', isEqualTo: quest.id)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('このクエストに関する投稿はまだありません。'),
                )));
              }

              final posts = snapshot.data!.docs
                  .map((doc) => Post.fromFirestore(doc))
                  .toList();

              // SliverListを使うことで、ヘッダーとリストが一体となってスクロールする
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: post.photoURL != null
                            ? Image.network(post.photoURL!,
                                width: 50, height: 50, fit: BoxFit.cover)
                            : null,
                        title: Text(post.text),
                        subtitle: Text(DateFormat('MM/dd HH:mm')
                            .format(post.createdAt.toDate())),
                      ),
                    );
                  },
                  childCount: posts.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
