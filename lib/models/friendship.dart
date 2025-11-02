// lib/models/friendship.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ▼▼▼ このenum定義を修正 ▼▼▼
enum FriendshipStatus {
  pending, // 通常の申請中
  quest_pending, // 探す欄からの申請中 ◀◀◀ 追加
  accepted, // 承認済み
  declined, // 拒否
  none, // 関係なし
}
// ▲▲▲

class Friendship {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // "pending", "quest_pending", "accepted", "declined"
  final Timestamp createdAt;

  Friendship({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Friendship(
      id: doc.id,
      senderId: data['senderId'],
      receiverId: data['receiverId'],
      status: data['status'],
      createdAt: data['createdAt'],
    );
  }
}
