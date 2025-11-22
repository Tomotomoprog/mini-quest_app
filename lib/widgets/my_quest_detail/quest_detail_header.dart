// lib/widgets/my_quest_detail/quest_detail_header.dart
import 'package:flutter/material.dart';
import '../../models/my_quest.dart';
import '../../models/friendship.dart';

class QuestDetailHeader extends StatelessWidget {
  final MyQuest quest;
  final bool isFriendOrMyQuest;
  final FriendshipStatus friendshipStatus;
  final VoidCallback onSendRequest;
  // ▼▼▼ 追加: 編集・削除用コールバック ▼▼▼
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  // ▲▲▲

  const QuestDetailHeader({
    super.key,
    required this.quest,
    required this.isFriendOrMyQuest,
    required this.friendshipStatus,
    required this.onSendRequest,
    // ▼▼▼ 追加 ▼▼▼
    this.onEdit,
    this.onDelete,
    // ▲▲▲
  });

  Color _getColorForCategory(String category, BuildContext context) {
    switch (category) {
      case 'Life':
        return Colors.green.shade400;
      case 'Study':
        return Colors.blue.shade400;
      case 'Physical':
        return Colors.red.shade400;
      case 'Social':
        return Colors.pink.shade400;
      case 'Creative':
        return Colors.purple.shade400;
      case 'Mental':
        return Colors.indigo.shade400;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Life':
        return Icons.home_outlined;
      case 'Study':
        return Icons.school_outlined;
      case 'Physical':
        return Icons.fitness_center_outlined;
      case 'Social':
        return Icons.people_outline;
      case 'Creative':
        return Icons.palette_outlined;
      case 'Mental':
        return Icons.self_improvement_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForCategory(quest.category, context);
    final icon = _getIconForCategory(quest.category);
    final secondaryTextColor = Colors.grey[400]!;

    final startDate = DateTime.tryParse(quest.startDate) ?? DateTime.now();
    final endDate = DateTime.tryParse(quest.endDate) ?? DateTime.now();
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDuration =
        DateTime.now().difference(startDate).inDays.clamp(0, totalDuration);
    final progress = (totalDuration > 0)
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;
    final remainingDays = totalDuration - elapsedDuration;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quest.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              // ▼▼▼ 追加: 編集・削除メニューボタン ▼▼▼
              if (onEdit != null && onDelete != null)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit!();
                    } else if (value == 'delete') {
                      onDelete!();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('編集する'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 20),
                          SizedBox(width: 8),
                          Text('クエスト削除',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              // ▲▲▲
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    (isFriendOrMyQuest && quest.userPhotoURL != null)
                        ? NetworkImage(quest.userPhotoURL!)
                        : null,
                child: (!isFriendOrMyQuest || quest.userPhotoURL == null)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFriendOrMyQuest ? quest.userName : '匿名の冒険者',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isFriendOrMyQuest
                            ? Colors.white
                            : secondaryTextColor,
                        fontWeight: isFriendOrMyQuest
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                ),
              ),
              if (!isFriendOrMyQuest)
                ElevatedButton.icon(
                  icon: Icon(
                      friendshipStatus == FriendshipStatus.none
                          ? Icons.person_add_alt_1
                          : Icons.check,
                      size: 16),
                  label: Text(
                      friendshipStatus == FriendshipStatus.none ? '申請' : '申請中'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friendshipStatus == FriendshipStatus.none
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: friendshipStatus == FriendshipStatus.none
                      ? onSendRequest
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 期間とプログレスバー
          if (quest.status == 'active') ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(quest.startDate.replaceAll('-', '/'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryTextColor)),
                Text(remainingDays >= 0 ? '残り $remainingDays 日' : '期間終了',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(quest.endDate.replaceAll('-', '/'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: secondaryTextColor)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: color, width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('意気込み:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                    )),
                const SizedBox(height: 4),
                Text(quest.motivation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
