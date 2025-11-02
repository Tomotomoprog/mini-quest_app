// lib/models/my_quest.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの useMyQuests.ts を参考にしたMyQuestモデル
class MyQuest {
  final String id;
  final String uid;
  final String title;
  final String description; // 詳細画面で使うため追加
  final String motivation;
  final String category;
  final String status;
  final String startDate;
  final String endDate;
  final Timestamp createdAt;
  final Timestamp? completedAt; // 達成日時
  // ▼▼▼ 以下の2フィールドを追加 ▼▼▼
  final String userName;
  final String? userPhotoURL;
  // ▲▲▲ 以下の2フィールドを追加 ▲▲▲

  MyQuest({
    required this.id,
    required this.uid,
    required this.title,
    required this.description,
    required this.motivation,
    required this.category,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.completedAt,
    // ▼▼▼ コンストラクタを修正 ▼▼▼
    required this.userName,
    this.userPhotoURL,
    // ▲▲▲ コンストラクタを修正 ▲▲▲
  });

  factory MyQuest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MyQuest(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '', // description を読み込む
      motivation: data['motivation'] ?? '',
      category: data['category'] ?? 'Life',
      status: data['status'] ?? 'active',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      completedAt: data['completedAt'], // completedAt を読み込む
      // ▼▼▼ 読み込み処理を追加 ▼▼▼
      userName: data['userName'] ?? '名無しさん',
      userPhotoURL: data['userPhotoURL'],
      // ▲▲▲ 読み込み処理を追加 ▲▲▲
    );
  }

  MyQuest copyWith({
    String? id,
    String? uid,
    String? title,
    String? description,
    String? motivation,
    String? category,
    String? status,
    String? startDate,
    String? endDate,
    Timestamp? createdAt,
    Timestamp? completedAt,
    // ▼▼▼ copyWith を修正 ▼▼▼
    String? userName,
    String? userPhotoURL,
    // ▲▲▲ copyWith を修正 ▲▲▲
  }) {
    return MyQuest(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      description: description ?? this.description,
      motivation: motivation ?? this.motivation,
      category: category ?? this.category,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      // ▼▼▼ copyWith を修正 ▼▼▼
      userName: userName ?? this.userName,
      userPhotoURL: userPhotoURL ?? this.userPhotoURL,
      // ▲▲▲ copyWith を修正 ▲▲▲
    );
  }
}
