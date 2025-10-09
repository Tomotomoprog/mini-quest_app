import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの useFriends.ts を参考にしたFriendshipモデル
class Friendship {
  final String id;
  final List<String> userIds;
  final String requesterId;
  final String recipientId;
  final String status; // "pending", "accepted", "declined"

  Friendship({
    required this.id,
    required this.userIds,
    required this.requesterId,
    required this.recipientId,
    required this.status,
  });

  factory Friendship.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Friendship(
      id: doc.id,
      userIds: List<String>.from(data['userIds'] ?? []),
      requesterId: data['requesterId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}
