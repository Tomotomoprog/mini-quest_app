// lib/widgets/profile/profile_status_panel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../utils/progression.dart';
import '../../profile_friends_list_screen.dart';
import '../../effort_history_screen.dart';
import '../../streak_calendar_screen.dart';
import '../../level_detail_screen.dart';
import '../../job_selection_screen.dart';

class ProfileStatusPanel extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final bool isMyProfile;

  const ProfileStatusPanel({
    super.key,
    required this.userProfile,
    required this.level,
    required this.isMyProfile,
  });

  String _formatDuration(double totalHours) {
    if (totalHours <= 0) return '0.0h';
    return '${totalHours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final Color panelColor = Colors.grey[900]!;
    final Color panelBorderColor = Colors.grey[800]!;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    final List<Color> iconColors = [
      accentColor.withOpacity(0.9),
      accentColor.withOpacity(0.9),
      accentColor.withOpacity(0.8),
      accentColor.withOpacity(0.8),
      accentColor.withOpacity(0.7),
      accentColor.withOpacity(0.7),
    ];

    final String jobTitle = userProfile.selectedJob ?? '見習い';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: panelBorderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPanelRow(
              context: context,
              icon1: Icons.star_border_purple500_outlined,
              label1: 'レベル',
              valueWidget1: _AnimatedCounter(
                value: level,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              iconColor1: iconColors[0],
              onTap1: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      LevelDetailScreen(currentXp: userProfile.xp),
                ));
              },
              icon2: Progression.getJobIcon(jobTitle),
              label2: 'ジョブ',
              valueWidget2: Text(
                jobTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              iconColor2: iconColors[1],
              onTap2: isMyProfile
                  ? () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            JobSelectionScreen(userProfile: userProfile),
                      ));
                    }
                  : null,
            ),
            Divider(
                color: Colors.white.withOpacity(0.1),
                height: 24,
                thickness: 1.0),
            _buildPanelRow(
              context: context,
              icon1: Icons.local_fire_department_outlined,
              label1: '連続記録',
              valueWidget1: _AnimatedCounter(
                value: userProfile.currentStreak,
                suffix: ' 日',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              iconColor1: iconColors[2],
              onTap1: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const StreakCalendarScreen(),
                ));
              },
              icon2: Icons.timer_outlined,
              label2: '総努力時間',
              valueWidget2: _AnimatedCounter(
                value: userProfile.totalEffortHours,
                isDecimal: true,
                suffix: 'h',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              iconColor2: iconColors[3],
              onTap2: () {
                // ▼▼▼ 修正: プロフィールのユーザーIDを渡して遷移する ▼▼▼
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      EffortHistoryScreen(userId: userProfile.uid),
                ));
                // ▲▲▲
              },
            ),
            Divider(
                color: Colors.white.withOpacity(0.1),
                height: 24,
                thickness: 1.0),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('uid', isEqualTo: userProfile.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildSingleStatItem(
                          context: context,
                          icon: Icons.note_alt_outlined,
                          label: '総記録数',
                          valueWidget: const Text('...',
                              style: TextStyle(color: Colors.white)),
                          iconColor: iconColors[4],
                        );
                      }
                      final int count = snapshot.data!.docs.length;
                      return _buildSingleStatItem(
                        context: context,
                        icon: Icons.note_alt_outlined,
                        label: '総記録数',
                        valueWidget: _AnimatedCounter(
                          value: count,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                        ),
                        iconColor: iconColors[4],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friendships')
                        .where('userIds', arrayContains: userProfile.uid)
                        .where('status', isEqualTo: 'accepted')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final friendCount = snapshot.data?.docs.length ?? 0;
                      return _buildSingleStatItem(
                        context: context,
                        icon: Icons.people_alt_outlined,
                        label: 'フレンド',
                        valueWidget: _AnimatedCounter(
                          value: friendCount,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                        ),
                        iconColor: iconColors[5],
                        onTap: friendCount > 0
                            ? () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileFriendsListScreen(
                                    userId: userProfile.uid,
                                    userName:
                                        userProfile.displayName ?? '名無しさん',
                                  ),
                                ));
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelRow({
    required BuildContext context,
    required IconData icon1,
    required String label1,
    required Widget valueWidget1,
    required Color iconColor1,
    required IconData icon2,
    required String label2,
    required Widget valueWidget2,
    required Color iconColor2,
    VoidCallback? onTap1,
    VoidCallback? onTap2,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSingleStatItem(
            context: context,
            icon: icon1,
            label: label1,
            valueWidget: valueWidget1,
            iconColor: iconColor1,
            onTap: onTap1,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSingleStatItem(
            context: context,
            icon: icon2,
            label: label2,
            valueWidget: valueWidget2,
            iconColor: iconColor2,
            onTap: onTap2,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget valueWidget,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final Color labelColor = Colors.grey[400]!;

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: labelColor)),
            valueWidget,
          ],
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(4.0), child: content),
      );
    } else {
      return Padding(padding: const EdgeInsets.all(4.0), child: content);
    }
  }
}

class _AnimatedCounter extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String suffix;
  final bool isDecimal;

  const _AnimatedCounter({
    required this.value,
    this.style,
    this.suffix = '',
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween<num>(begin: 0, end: value),
      duration: const Duration(seconds: 2),
      curve: Curves.easeOutExpo,
      builder: (context, animatedValue, child) {
        String text;
        if (isDecimal) {
          text = animatedValue.toStringAsFixed(1);
        } else {
          text = animatedValue.toInt().toString();
        }
        return Text(
          '$text$suffix',
          style: style,
        );
      },
    );
  }
}
