// lib/widgets/profile/profile_header.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../utils/progression.dart';
import '../../profile_friends_list_screen.dart';
import 'dart:ui'; // BackdropFilterのために必要

class ProfileHeader extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final JobResult jobInfo;
  final bool isMyProfile;
  final VoidCallback onEditPicture;

  const ProfileHeader({
    super.key,
    required this.userProfile,
    required this.level,
    required this.jobInfo,
    required this.isMyProfile,
    required this.onEditPicture,
  });

  Widget _buildAvatar(BuildContext context) {
    const double avatarRadius = 90;

    if (userProfile.photoURL != null && userProfile.photoURL!.isNotEmpty) {
      return CircleAvatar(
        radius: avatarRadius,
        backgroundImage: NetworkImage(userProfile.photoURL!),
      );
    }

    if (userProfile.avatar != null) {
      IconData getHairIcon(String style) {
        switch (style) {
          case 'curly':
            return Icons.waves;
          case 'straight':
            return Icons.straighten;
          default:
            return Icons.person;
        }
      }

      return Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
              radius: avatarRadius,
              backgroundColor: userProfile.avatar!.skinColor),
          Positioned(
            top: 0,
            child: Icon(
              getHairIcon(userProfile.avatar!.hairStyle),
              color: userProfile.avatar!.hairColor,
              size: avatarRadius * 1.2,
            ),
          ),
        ],
      );
    }

    return CircleAvatar(
      radius: avatarRadius,
      child: Icon(Icons.person, size: avatarRadius),
    );
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0.0h';
    }
    final hours = totalMinutes / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    // === ▼▼▼ パネルの色とテキスト/アイコンの色を調整 ▼▼▼ ===
    final panelColor = Colors.lightBlue.shade100.withOpacity(0.8); // 淡い青 + 透明度
    // final panelGradient = LinearGradient( // グラデーションも可能
    //   begin: Alignment.topLeft,
    //   end: Alignment.bottomRight,
    //   colors: [
    //     Colors.blue.shade200.withOpacity(0.85),
    //     Colors.lightBlue.shade100.withOpacity(0.75),
    //   ],
    // );
    // final textColor = Colors.blue.shade900; // 濃い青色のテキスト
    final textColor = Colors.black87; // 黒に近い色で見やすく
    final iconColor = Colors.blue.shade600; // アイコンの色
    // === ▲▲▲ パネルの色とテキスト/アイコンの色を調整 ▲▲▲ ===

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          SizedBox(height: 20),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAvatar(context),
              if (isMyProfile)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Material(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: onEditPicture,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),
          Text(userProfile.displayName ?? '名無しさん',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // === ▼▼▼ 透明感のあるパネルデザイン ▼▼▼ ===
          ClipRRect(
            // BackdropFilterのために必要
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              // すりガラス効果
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: panelColor, // 半透明の淡い青
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3)), // 白い枠線
                    // gradient: panelGradient, // グラデーションを使う場合
                  ),
                  child: Column(
                    children: [
                      _buildPanelRow(
                        context: context,
                        icon1: Icons.star_border_purple500_outlined,
                        label1: 'レベル',
                        value1: level.toString(),
                        iconColor1: iconColor,
                        textColor1: textColor,
                        icon2: Icons.work_outline,
                        label2: 'ジョブ',
                        value2: jobInfo.title,
                        iconColor2: iconColor,
                        textColor2: textColor,
                        isJob: true,
                      ),
                      Divider(color: Colors.white.withOpacity(0.2), height: 24),
                      _buildPanelRow(
                        context: context,
                        icon1: Icons.local_fire_department_outlined,
                        label1: '連続記録',
                        value1: '${userProfile.currentStreak} 日',
                        iconColor1: iconColor,
                        textColor1: textColor,
                        icon2: Icons.timer_outlined,
                        label2: '総努力時間',
                        value2: _formatDuration(userProfile.totalEffortMinutes),
                        iconColor2: iconColor,
                        textColor2: textColor,
                      ),
                      Divider(color: Colors.white.withOpacity(0.2), height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('my_quests')
                                  .where('uid', isEqualTo: userProfile.uid)
                                  .where('status', isEqualTo: 'completed')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                String achievementCount = '...';
                                if (snapshot.connectionState ==
                                        ConnectionState.active &&
                                    snapshot.hasData) {
                                  achievementCount =
                                      (snapshot.data?.docs.length ?? 0)
                                          .toString();
                                } else if (snapshot.hasError) {
                                  achievementCount = '0';
                                }
                                return _buildSingleStatItem(
                                    context: context,
                                    icon: Icons.emoji_events_outlined,
                                    label: '総達成数',
                                    value: achievementCount,
                                    iconColor: iconColor,
                                    textColor: textColor);
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('friendships')
                                  .where('userIds',
                                      arrayContains: userProfile.uid)
                                  .where('status', isEqualTo: 'accepted')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final friendCount =
                                    snapshot.data?.docs.length ?? 0;
                                return InkWell(
                                  onTap: friendCount > 0
                                      ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ProfileFriendsListScreen(
                                                userId: userProfile.uid,
                                                userName:
                                                    userProfile.displayName ??
                                                        '名無しさん',
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: _buildSingleStatItem(
                                      context: context,
                                      icon: Icons.people_alt_outlined,
                                      label: 'フレンド',
                                      value: friendCount.toString(),
                                      iconColor: iconColor,
                                      textColor: textColor),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  )),
            ),
          ),

          // === ▲▲▲ 透明感のあるパネルデザイン ▲▲▲ ===
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPanelRow({
    required BuildContext context,
    required IconData icon1,
    required String label1,
    required String value1,
    required Color iconColor1,
    required Color textColor1,
    required IconData icon2,
    required String label2,
    required String value2,
    required Color iconColor2,
    required Color textColor2,
    bool isJob = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSingleStatItem(
            context: context,
            icon: icon1,
            label: label1,
            value: value1,
            iconColor: iconColor1,
            textColor: textColor1,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildSingleStatItem(
            context: context,
            icon: icon2,
            label: label2,
            value: value2,
            iconColor: iconColor2,
            textColor: textColor2,
            highlightValue: isJob,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color textColor,
    bool highlightValue = false,
  }) {
    // ハイライト時の色を調整
    final highlightColor = Colors.yellow.shade600; // 少し濃い黄色

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textColor.withOpacity(0.8))),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: highlightValue ? highlightColor : textColor,
                      // 影はハイライト時のみ軽く
                      shadows: highlightValue
                          ? [
                              Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 1)
                            ]
                          : null,
                    )),
          ],
        ),
      ],
    );
  }
}
