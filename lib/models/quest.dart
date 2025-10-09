import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの useQuests.ts を参考にしたQuestモデル
class Quest {
  final String id;
  final String title;
  final String description;
  final String tag;
  final String category;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.tag,
    required this.category,
  });

  // FirestoreのデータからQuestオブジェクトを作成するためのファクトリコンストラクタ
  factory Quest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Quest(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      tag: data['tag'] ?? '',
      category: data['category'] ?? 'Life',
    );
  }
}