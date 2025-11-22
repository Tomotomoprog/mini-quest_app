// lib/models/my_quest.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MyQuest {
  final String id;
  final String uid; // 作成者のUID
  final String title;
  final String description;
  final String motivation;
  final String category;
  final String status;
  final String startDate;
  final String endDate;
  final Timestamp createdAt;
  final Timestamp? completedAt;
  final String userName;
  final String? userPhotoURL;

  final String schedule;
  final String minimumStep;
  final String reward;

  // ▼▼▼ 追加: フレンドクエスト・バトル用 ▼▼▼
  final String type; // 'personal', 'friend', 'battle'
  final List<String> participantIds; // 参加者のUIDリスト（自分含む）
  // ▲▲▲

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
    required this.userName,
    this.userPhotoURL,
    this.schedule = '',
    this.minimumStep = '',
    this.reward = '',
    // ▼▼▼ 追加 ▼▼▼
    this.type = 'personal',
    this.participantIds = const [],
    // ▲▲▲
  });

  factory MyQuest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    // participantIds の読み込み（古いデータ互換のため、ない場合はuidのみのリストにする）
    List<String> participants = [];
    if (data['participantIds'] != null) {
      participants = List<String>.from(data['participantIds']);
    } else if (data['uid'] != null) {
      participants = [data['uid']];
    }

    return MyQuest(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      motivation: data['motivation'] ?? '',
      category: data['category'] ?? 'Life',
      status: data['status'] ?? 'active',
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      completedAt: data['completedAt'],
      userName: data['userName'] ?? '名無しさん',
      userPhotoURL: data['userPhotoURL'],
      schedule: data['schedule'] ?? '',
      minimumStep: data['minimumStep'] ?? '',
      reward: data['reward'] ?? '',
      // ▼▼▼ 追加 ▼▼▼
      type: data['type'] ?? 'personal',
      participantIds: participants,
      // ▲▲▲
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
    String? userName,
    String? userPhotoURL,
    String? schedule,
    String? minimumStep,
    String? reward,
    // ▼▼▼ 追加 ▼▼▼
    String? type,
    List<String>? participantIds,
    // ▲▲▲
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
      userName: userName ?? this.userName,
      userPhotoURL: userPhotoURL ?? this.userPhotoURL,
      schedule: schedule ?? this.schedule,
      minimumStep: minimumStep ?? this.minimumStep,
      reward: reward ?? this.reward,
      // ▼▼▼ 追加 ▼▼▼
      type: type ?? this.type,
      participantIds: participantIds ?? this.participantIds,
      // ▲▲▲
    );
  }
}
