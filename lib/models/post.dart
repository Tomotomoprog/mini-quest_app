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
  final bool isBlessed; // 追加

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
    required this.isBlessed, // 追加
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
      isBlessed: data['isBlessed'] ?? false, // 追加
    );
  }
}
