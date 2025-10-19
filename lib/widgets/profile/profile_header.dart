// lib/widgets/profile/profile_header.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../profile_friends_list_screen.dart';
import '../../utils/progression.dart'; // JobResult を使うために必要

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

  // アバター表示用ウィジェット
  Widget _buildAvatarWidget(BuildContext context) {
    const double avatarRadius = 45;

    Widget avatarContent;
    if (userProfile.photoURL != null && userProfile.photoURL!.isNotEmpty) {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundImage: NetworkImage(userProfile.photoURL!),
      );
    } else if (userProfile.avatar != null) {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: userProfile.avatar!.skinColor,
      );
    } else {
      avatarContent = CircleAvatar(
        radius: avatarRadius,
        backgroundColor: Colors.grey.shade300,
        child:
            Icon(Icons.person, size: avatarRadius, color: Colors.grey.shade600),
      );
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: avatarContent,
        ),
        if (isMyProfile)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).primaryColor,
              shape: CircleBorder(),
              elevation: 3.0,
              child: InkWell(
                onTap: onEditPicture,
                customBorder: CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ),
          )
      ],
    );
  }

  // パネル内の1項目表示
  Widget _buildSingleStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    final Color textColor = Colors.white;
    final Color labelColor = Colors.white.withOpacity(0.9);
    final List<Shadow> textShadows = [
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 2.0,
        color: Colors.black.withOpacity(0.6),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
          shadows: [
            Shadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2,
                offset: Offset(1, 1)),
          ],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: labelColor,
                      shadows: textShadows,
                    )),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      shadows: textShadows,
                    )),
          ],
        ),
      ],
    );
  }

  // パネル内の1行 (2項目) を生成するヘルパー
  Widget _buildPanelRow({
    required BuildContext context,
    required IconData icon1,
    required String label1,
    required String value1,
    required Color iconColor1,
    required IconData icon2,
    required String label2,
    required String value2,
    required Color iconColor2,
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
          ),
        ),
      ],
    );
  }

  // ▼▼▼ エラーの原因箇所 ▼▼▼
  // // 総努力時間のフォーマット (int totalMinutes を受け取る古いコード)
  // String _formatDuration(int totalMinutes) {
  //   if (totalMinutes <= 0) {
  //     return '0.0h';
  //   }
  //   final hours = totalMinutes / 60.0;
  //   return '${hours.toStringAsFixed(1)}h';
  // }

  // ▼▼▼ double totalHours を受け取るように修正 ▼▼▼
  String _formatDuration(double totalHours) {
    if (totalHours <= 0) {
      return '0.0h';
    }
    // 小数点以下1桁で表示
    return '${totalHours.toStringAsFixed(1)}h';
  }
  // ▲▲▲ double totalHours を受け取るように修正 ▲▲▲
  // ▲▲▲ エラーの原因箇所 ▲▲▲

  @override
  Widget build(BuildContext context) {
    final panelColor = Colors.blueGrey.shade700;
    final panelBorderColor = Colors.blueGrey.shade800;
    final List<Color> iconColors = [
      Colors.yellow.shade300,
      Colors.cyan.shade200,
      Colors.redAccent.shade100,
      Colors.lightGreen.shade300,
      Colors.orange.shade300,
      Colors.pink.shade200,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Row(
            children: [
              _buildAvatarWidget(context),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  userProfile.displayName ?? '名無しさん',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: panelBorderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 1,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 3,
                  spreadRadius: -2,
                  offset: Offset(0, -1),
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
                  value1: level.toString(),
                  iconColor1: iconColors[0],
                  icon2: Icons.work_outline,
                  label2: 'ジョブ',
                  value2: jobInfo.title,
                  iconColor2: iconColors[1],
                ),
                Divider(
                    color: Colors.white.withOpacity(0.3),
                    height: 24,
                    thickness: 0.5),
                _buildPanelRow(
                  context: context,
                  icon1: Icons.local_fire_department_outlined,
                  label1: '連続記録',
                  value1: '${userProfile.currentStreak} 日',
                  iconColor1: iconColors[2],
                  icon2: Icons.timer_outlined,
                  label2: '総努力時間',
                  // ▼▼▼ エラーの原因箇所 ▼▼▼
                  // value2: _formatDuration(userProfile.totalEffortMinutes), // <- 古い int 型フィールド
                  // ▼▼▼ 修正後 ▼▼▼
                  value2: _formatDuration(
                      userProfile.totalEffortHours), // <- 新しい double 型フィールド
                  // ▲▲▲ 修正後 ▲▲▲
                  iconColor2: iconColors[3],
                ),
                Divider(
                    color: Colors.white.withOpacity(0.3),
                    height: 24,
                    thickness: 0.5),
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
                                (snapshot.data?.docs.length ?? 0).toString();
                          } else if (snapshot.hasError) {
                            achievementCount = '0';
                          }
                          return _buildSingleStatItem(
                              context: context,
                              icon: Icons.emoji_events_outlined,
                              label: '総達成数',
                              value: achievementCount,
                              iconColor: iconColors[4]);
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('friendships')
                            .where('userIds', arrayContains: userProfile.uid)
                            .where('status', isEqualTo: 'accepted')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final friendCount = snapshot.data?.docs.length ?? 0;
                          return InkWell(
                            onTap: friendCount > 0
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProfileFriendsListScreen(
                                          userId: userProfile.uid,
                                          userName: userProfile.displayName ??
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
                                iconColor: iconColors[5]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
