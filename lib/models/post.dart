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
  final String? photoURL;
  final int userLevel; // 追加
  final String userClass; // 追加

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
    this.photoURL,
    required this.userLevel,
    required this.userClass,
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
      photoURL: data['photoURL'],
      userLevel: data['userLevel'] ?? 1, // 追加
      userClass: data['userClass'] ?? '見習い', // 追加
    );
  }
}
