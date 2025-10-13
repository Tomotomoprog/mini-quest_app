import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの usePosts.ts を参考にしたCommentモデル
class Comment {
  final String id;
  final String uid;
  final String userName;
  final String? userAvatar;
  final String text;
  final Timestamp createdAt;

  Comment({
    required this.id,
    required this.uid,
    required this.userName,
    this.userAvatar,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      uid: data['uid'] ?? '',
      userName: data['userName'] ?? '名無しさん',
      userAvatar: data['userAvatar'],
      text: data['text'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
