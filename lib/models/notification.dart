import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // 'like' or 'comment'
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatar;
  final String postId;
  final String postTextSnippet;
  final String targetUserId; // 通知を受け取るユーザーのID
  final Timestamp createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserAvatar,
    required this.postId,
    required this.postTextSnippet,
    required this.targetUserId,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '名無しさん',
      fromUserAvatar: data['fromUserAvatar'],
      postId: data['postId'] ?? '',
      postTextSnippet: data['postTextSnippet'] ?? '',
      targetUserId: data['targetUserId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}
