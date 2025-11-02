// lib/widgets/profile/profile_stats_tab.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../profile_friends_list_screen.dart';
import '../../utils/progression.dart';

class ProfileStatsTab extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final JobResult jobInfo;
  final bool isMyProfile;
  final VoidCallback onEditPicture;

  const ProfileStatsTab({
    super.key,
    required this.userProfile,
    required this.level,
    required this.jobInfo,
    required this.isMyProfile,
    required this.onEditPicture,
  });

  static const categoryColors = {
    'Life': Color(0xFF4ADE80), // green[400]
    'Study': Color(0xFF60A5FA), // blue[400]
    'Physical': Color(0xFFF87171), // red[400]
    'Social': Color(0xFFF472B6), // pink[400]
    'Creative': Color(0xFFC084FC), // purple[400]
    'Mental': Color(0xFF818CF8), // indigo[400]
  };

  // ▼▼▼ プロフィール編集ダイアログ（bio対応） ▼▼▼
  void _showEditProfileDialog(BuildContext context, UserProfile userProfile) {
    final nameController = TextEditingController(text: userProfile.displayName);
    final bioController = TextEditingController(text: userProfile.bio);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プロフィールを編集'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名前'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '名前は必須です';
                    }
                    if (value.length > 20) {
                      return '名前は20文字以内にしてください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: '自己紹介',
                    hintText: 'よろしくお願いします！',
                  ),
                  maxLength: 100,
                  maxLines: 2,
                  validator: (value) {
                    if (value != null && value.length > 100) {
                      return '100文字以内にしてください';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('保存'),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final newName = nameController.text.trim();
                  final newBio = bioController.text.trim();

                  try {
                    // Auth の表示名も更新
                    await user.updateDisplayName(newName);

                    // Firestore を更新
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'displayName': newName,
                      'bio': newBio,
                    });

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('プロフィールを更新しました')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('更新に失敗しました: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
  // ▲▲▲

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
        backgroundColor: Colors.grey[700],
        child: Icon(Icons.person, size: avatarRadius, color: Colors.grey[400]),
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
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
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
              color: Theme.of(context).colorScheme.primary,
              shape:
                  CircleBorder(side: BorderSide(color: Colors.black, width: 2)),
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

  Widget _buildSingleStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    final Color textColor = Colors.white;
    final Color labelColor = Colors.grey[400]!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: labelColor,
                    )),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    )),
          ],
        ),
      ],
    );
  }

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

  String _formatDuration(double totalHours) {
    if (totalHours <= 0) {
      return '0.0h';
    }
    return '${totalHours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final Color panelColor = Colors.grey[900]!;
    final Color panelBorderColor = Colors.grey[800]!;
    final Color accentColor = Theme.of(context).colorScheme.primary;

    final List<Color> iconColors = [
      accentColor.withOpacity(0.9), // Level
      accentColor.withOpacity(0.9), // Job
      accentColor.withOpacity(0.8), // Streak
      accentColor.withOpacity(0.8), // Effort
      accentColor.withOpacity(0.7), // Records
      accentColor.withOpacity(0.7), // Friends
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ▼▼▼ 名前・アカウント名・自己紹介・編集ボタン ▼▼▼
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 0.0, vertical: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarWidget(context),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 名前
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
                          // 編集ボタン (自分のプロフのみ)
                          if (isMyProfile)
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  color: Colors.grey[400], size: 20),
                              onPressed: () =>
                                  _showEditProfileDialog(context, userProfile),
                            ),
                        ],
                      ),
                      // ▼▼▼ アカウント名を追加 ▼▼▼
                      if (userProfile.accountName != null)
                        Text(
                          '@${userProfile.accountName}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[400],
                                  ),
                        ),
                      // ▲▲▲
                      // ▼▼▼ 自己紹介欄を追加 ▼▼▼
                      const SizedBox(height: 8),
                      Text(
                        userProfile.bio ??
                            (isMyProfile ? '自己紹介を追加...' : '自己紹介はありません'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                              fontStyle: (userProfile.bio == null ||
                                      userProfile.bio!.isEmpty)
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ▲▲▲
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ▲▲▲

          Padding(
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
                    offset: Offset(0, 5),
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
                      color: Colors.white.withOpacity(0.1),
                      height: 24,
                      thickness: 1.0),
                  _buildPanelRow(
                    context: context,
                    icon1: Icons.local_fire_department_outlined,
                    label1: '連続記録',
                    value1: '${userProfile.currentStreak} 日',
                    iconColor1: iconColors[2],
                    icon2: Icons.timer_outlined,
                    label2: '総努力時間',
                    value2: _formatDuration(userProfile.totalEffortHours),
                    iconColor2: iconColors[3],
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
                            String recordCount = '...';
                            if (snapshot.connectionState ==
                                    ConnectionState.active &&
                                snapshot.hasData) {
                              recordCount =
                                  (snapshot.data?.docs.length ?? 0).toString();
                            } else if (snapshot.hasError) {
                              recordCount = '0';
                            }
                            return _buildSingleStatItem(
                                context: context,
                                icon: Icons.note_alt_outlined,
                                label: '総記録数',
                                value: recordCount,
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
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ProgressBar(
                      label: 'Life',
                      value: userProfile.stats.life,
                      max: 10,
                      color: categoryColors['Life']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Study',
                      value: userProfile.stats.study,
                      max: 10,
                      color: categoryColors['Study']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Physical',
                      value: userProfile.stats.physical,
                      max: 10,
                      color: categoryColors['Physical']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Social',
                      value: userProfile.stats.social,
                      max: 10,
                      color: categoryColors['Social']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Creative',
                      value: userProfile.stats.creative,
                      max: 10,
                      color: categoryColors['Creative']!),
                  const SizedBox(height: 16),
                  _ProgressBar(
                      label: 'Mental',
                      value: userProfile.stats.mental,
                      max: 10,
                      color: categoryColors['Mental']!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _ProgressBar(
      {required this.label,
      required this.value,
      required this.max,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('$value / $max', style: TextStyle(color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / max,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}
