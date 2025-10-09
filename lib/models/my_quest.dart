import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの useMyQuests.ts を参考にしたMyQuestモデル
class MyQuest {
  final String id;
  final String uid;
  final String title;
  final String motivation;
  final String category;
  final String status;
  final String startDate;
  final String endDate;
  final Timestamp createdAt;

  MyQuest({
    required this.id,
    required this.uid,
    required this.title,
    required this.motivation,
    required this.category,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory MyQuest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MyQuest(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      motivation: data['motivation'] ?? '',
      category: data['category'] ?? 'Life',
      status: data['status'] ?? 'active',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
