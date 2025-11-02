// lib/widgets/my_quest_detail/post_card_widgets.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/post.dart';
import '../../profile_screen.dart';
import '../../comment_screen.dart';
import '../../cheer_list_screen.dart'; // ◀◀◀ cheer_list_screen をインポート

// --- 投稿カードウィジェット ---

class PostHeader extends StatelessWidget {
  final Post post;
  final bool isFriendOrMyQuest;
  const PostHeader({
    super.key,
    required this.post,
    required this.isFriendOrMyQuest,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isFriendOrMyQuest
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: post.uid)),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: (isFriendOrMyQuest && post.userAvatar != null)
                  ? NetworkImage(post.userAvatar!)
                  : null,
              child: (!isFriendOrMyQuest || post.userAvatar == null)
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isFriendOrMyQuest ? post.userName : '匿名の冒険者',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Lv.${post.userLevel}・${post.userClass}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (post.isWisdomShared)
              Row(
                children: [
                  Icon(Icons.lightbulb,
                      color: Colors.deepPurpleAccent.shade100, size: 18),
                  const SizedBox(width: 4),
                  Text("叡智",
                      style: TextStyle(
                          color: Colors.deepPurpleAccent.shade100,
                          fontWeight: FontWeight.bold)),
                ],
              )
            else if (post.timeSpentHours != null && post.timeSpentHours! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${post.timeSpentHours}時間',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class PostContent extends StatelessWidget {
  final Post post;
  const PostContent({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(post.text,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          if (post.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(post.photoURL!,
                    width: double.infinity, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}

// ▼▼▼ PostActions ウィジェットを修正 (UIのみ) ▼▼▼
class PostActions extends StatelessWidget {
  final Post post;
  final bool isLiked; // (変数名はそのまま)
  final VoidCallback onLike; // (コールバック名はそのまま)

  const PostActions({
    super.key,
    required this.post,
    required this.isLiked,
    required this.onLike,
  });

  void _showLikeList(BuildContext context) {
    // (DB構造は 'likeCount' のまま)
    if (post.likeCount > 0) {
      Navigator.of(context).push(MaterialPageRoute(
        // ▼▼▼ CheerListScreen に変更 ▼▼▼
        builder: (context) => CheerListScreen(postId: post.id),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Colors.grey[500]!;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            // ▼▼▼ アイコンを応援 (炎) に変更 ▼▼▼
            icon: Icon(
                isLiked
                    ? Icons.local_fire_department // 押されている
                    : Icons.local_fire_department_outlined, // 押されていない
                color: isLiked ? accentColor : iconColor),
            onPressed: onLike,
          ),
          InkWell(
            onTap: () => _showLikeList(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              // ▼▼▼ post.likeCount を参照 (DB構造はそのまま) ▼▼▼
              child: Text(post.likeCount.toString(),
                  style: TextStyle(color: iconColor)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: iconColor),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => CommentScreen(post: post))),
          ),
          Text(post.commentCount.toString(),
              style: TextStyle(color: iconColor)),
          const Spacer(),
          Text(
            DateFormat('M/d HH:mm').format(post.createdAt.toDate()),
            style: TextStyle(color: iconColor, fontSize: 12),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
