// lib/widgets/friends/notifications_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification.dart';

class NotificationsTab extends StatelessWidget {
  final TabController tabController;

  const NotificationsTab({super.key, required this.tabController});

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}日前';
    if (diff.inHours > 0) return '${diff.inHours}時間前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分前';
    return 'たった今';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Center(child: Text("ログインしてください"));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUid)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('お知らせの読み込みエラー: ${snapshot.error}'),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('新しいお知らせはありません。'));
        }

        final notifications = snapshot.data!.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];

            IconData icon;
            Color color;
            String message;
            String subtitle;
            VoidCallback? onTap;

            switch (notification.type) {
              case 'like':
              case 'cheer':
                icon = Icons.local_fire_department;
                color = Theme.of(context).colorScheme.primary;
                message = 'あなたの頑張りを応援しています！';
                subtitle = '投稿: "${notification.postTextSnippet ?? ''}"';
                onTap = () {
                  // TODO: タップしたら投稿詳細画面に遷移する
                };
                break;
              case 'comment':
                icon = Icons.chat_bubble;
                color = Colors.blueAccent;
                message = 'あなたの投稿にコメントしました';
                subtitle = '投稿: "${notification.postTextSnippet ?? ''}"';
                onTap = () {
                  // TODO: タップしたら投稿詳細画面に遷移する
                };
                break;
              case 'friend_request':
                icon = Icons.person_add;
                color = Colors.green;
                message = 'あなたにフレンド申請を送信しました';
                subtitle = '「フレンド」タブで承認できます。';
                onTap = () {
                  tabController
                      .animateTo(0); // ◀◀◀ コンストラクタで受け取ったTabControllerを使用
                };
                break;
              default:
                icon = Icons.notifications;
                color = Colors.grey;
                message = '新しいお知らせがあります';
                subtitle = '';
                onTap = null;
            }

            return ListTile(
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundImage: notification.fromUserAvatar != null
                        ? NetworkImage(notification.fromUserAvatar!)
                        : null,
                    child: notification.fromUserAvatar == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 12),
                  )
                ],
              ),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: notification.fromUserName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: 'さん$message'),
                  ],
                ),
              ),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatRelativeTime(notification.createdAt.toDate()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: onTap,
            );
          },
        );
      },
    );
  }
}
