import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String uid;
  final String text;
  final Timestamp createdAt;
  final String? myQuestId;
  final String? myQuestTitle;
  final String userName;
  final String? userAvatar;
  final int likeCount;
  final int commentCount;
  final String? photoURL;
  final int userLevel;
  final String userClass;
  final String? questId;
  final String? questTitle;
  final String? questCategory;
  final bool isBlessed;
  final bool isWisdomShared;
  // ▼▼▼ フィールド名と型を変更 ▼▼▼
  final double? timeSpentHours;
  // ▲▲▲ フィールド名と型を変更 ▲▲▲

  Post({
    required this.id,
    required this.uid,
    required this.text,
    required this.createdAt,
    this.myQuestId,
    this.myQuestTitle,
    required this.userName,
    this.userAvatar,
    required this.likeCount,
    required this.commentCount,
    this.photoURL,
    required this.userLevel,
    required this.userClass,
    this.questId,
    this.questTitle,
    this.questCategory,
    required this.isBlessed,
    required this.isWisdomShared,
    // ▼▼▼ コンストラクタを修正 ▼▼▼
    this.timeSpentHours,
    // ▲▲▲ コンストラクタを修正 ▲▲▲
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // ▼▼▼ timeSpentHours の読み込みを追加 (int から double へのキャストも考慮) ▼▼▼
    double? hours;
    if (data['timeSpentHours'] != null) {
      if (data['timeSpentHours'] is int) {
        hours = (data['timeSpentHours'] as int).toDouble();
      } else if (data['timeSpentHours'] is double) {
        hours = data['timeSpentHours'] as double;
      }
    }
    // ▲▲▲ timeSpentHours の読み込みを追加 ▲▲▲

    return Post(
      id: doc.id,
      uid: data['uid'] ?? '',
      text: data['text'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      myQuestId: data['myQuestId'],
      myQuestTitle: data['myQuestTitle'],
      userName: data['userName'] ?? '名無しさん',
      userAvatar: data['userAvatar'],
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      photoURL: data['photoURL'],
      userLevel: data['userLevel'] ?? 1,
      userClass: data['userClass'] ?? '見習い',
      questId: data['questId'],
      questTitle: data['questTitle'],
      questCategory: data['questCategory'],
      isBlessed: data['isBlessed'] ?? false,
      isWisdomShared: data['isWisdomShared'] ?? false,
      // ▼▼▼ 修正した hours 変数を使用 ▼▼▼
      timeSpentHours: hours,
      // ▲▲▲ 修正した hours 変数を使用 ▲▲▲
    );
  }
}
