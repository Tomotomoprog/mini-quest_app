import 'package:cloud_firestore/cloud_firestore.dart';

// ▼▼▼ このenum定義を追加 ▼▼▼
enum FriendshipStatus {
  pending, // 申請中
  accepted, // 承認済み
  declined, // 拒否
  none, // 関係なし
}
// ▲▲▲ このenum定義を追加 ▲▲▲

class Friendship {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // "pending", "accepted", "declined"
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
