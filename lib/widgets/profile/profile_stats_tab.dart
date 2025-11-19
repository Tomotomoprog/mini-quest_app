// lib/widgets/profile/profile_stats_tab.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../profile_friends_list_screen.dart';
import '../../utils/progression.dart';
import 'dart:math' as math;
import 'hex_stats_chart.dart';
import '../../effort_history_screen.dart';
import '../../streak_calendar_screen.dart';
import '../../level_detail_screen.dart'; // ◀◀◀ 追加: レベル詳細画面をインポート

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
    'Life': Color(0xFF4ADE80),
    'Study': Color(0xFF60A5FA),
    'Physical': Color(0xFFF87171),
    'Social': Color(0xFFF472B6),
    'Creative': Color(0xFFC084FC),
    'Mental': Color(0xFF818CF8),
  };

  static const List<String> _availableAvatars = [
    'lib/assets/images/avatar/minarai_boy.jpg',
    'lib/assets/images/avatar/minnarai_girl.jpg',
  ];

  static const String _defaultAvatar =
      'lib/assets/images/avatar/minarai_boy.jpg';

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
                    await user.updateDisplayName(newName);
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

  void _showAvatarSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 300,
          child: Column(
            children: [
              Text(
                'アバターを選択',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _availableAvatars.map((path) {
                    final isSelected =
                        (userProfile.characterImage ?? _defaultAvatar) == path;
                    return GestureDetector(
                      onTap: () => _updateCharacterImage(context, path),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: isSelected
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 3)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                path,
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error, size: 50);
                                },
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Icon(Icons.check_circle,
                                  color: Colors.green, size: 24),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateCharacterImage(BuildContext context, String path) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'characterImage': path,
      });
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アバターを変更しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('変更に失敗しました: $e')),
        );
      }
    }
  }

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
                offset: const Offset(0, 4),
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
              shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2)),
              elevation: 3.0,
              child: InkWell(
                onTap: onEditPicture,
                customBorder: const CircleBorder(),
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
    VoidCallback? onTap,
  }) {
    final Color textColor = Colors.white;
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: content,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: content,
      );
    }
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
            value: value1,
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
            value: value2,
            iconColor: iconColor2,
            onTap: onTap2,
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

  List<String> _getTitles(UserProfile profile) {
    final List<String> titles = [];
    if (profile.accountName == 'tomo_developer') {
      titles.add('開発者');
    }
    if (profile.accountName != null && profile.accountName!.isNotEmpty) {
      titles.add('開発協力者');
    }
    return titles;
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

    final stats = userProfile.stats;
    final int highestValue = [
      stats.life,
      stats.study,
      stats.physical,
      stats.social,
      stats.creative,
      stats.mental
    ].isNotEmpty
        ? [
            stats.life,
            stats.study,
            stats.physical,
            stats.social,
            stats.creative,
            stats.mental
          ].reduce(math.max)
        : 0;
    final int dynamicMax = (highestValue / 10.0).ceil() * 10;
    final int currentMax = math.max(10, dynamicMax);
    final List<String> userTitles = _getTitles(userProfile);
    final String displayAvatarPath =
        userProfile.characterImage ?? _defaultAvatar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- ヘッダー ---
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
                          if (isMyProfile)
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  color: Colors.grey[400], size: 20),
                              onPressed: () =>
                                  _showEditProfileDialog(context, userProfile),
                            ),
                        ],
                      ),
                      if (userProfile.accountName != null)
                        Text(
                          '@${userProfile.accountName}',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[400],
                                  ),
                        ),
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
                      if (userTitles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: userTitles
                              .map((title) => _TitleChip(title: title))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- ステータスパネル ---
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
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ▼▼▼ 修正: レベル部分に onTap1 を追加して遷移を設定 ▼▼▼
                  _buildPanelRow(
                    context: context,
                    icon1: Icons.star_border_purple500_outlined,
                    label1: 'レベル',
                    value1: level.toString(),
                    iconColor1: iconColors[0],
                    onTap1: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              LevelDetailScreen(currentXp: userProfile.xp),
                        ),
                      );
                    },
                    icon2: Icons.work_outline,
                    label2: 'ジョブ',
                    value2: jobInfo.title,
                    iconColor2: iconColors[1],
                  ),
                  // ▲▲▲
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
                    onTap1: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StreakCalendarScreen(),
                        ),
                      );
                    },
                    icon2: Icons.timer_outlined,
                    label2: '総努力時間',
                    value2: _formatDuration(userProfile.totalEffortHours),
                    iconColor2: iconColors[3],
                    onTap2: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EffortHistoryScreen(),
                        ),
                      );
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
                                value: friendCount.toString(),
                                iconColor: iconColors[5],
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
                                    : null);
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
          HexStatsChart(
            stats: userProfile.stats,
            max: currentMax,
            colors: categoryColors,
            avatarPath: displayAvatarPath,
            onAvatarTap:
                isMyProfile ? () => _showAvatarSelectionDialog(context) : null,
          ),
        ],
      ),
    );
  }
}

class _TitleChip extends StatelessWidget {
  final String title;
  const _TitleChip({required this.title});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (title) {
      case '開発者':
        color = Colors.amber.shade600;
        icon = Icons.code_rounded;
        break;
      case '開発協力者':
        color = Colors.cyan.shade400;
        icon = Icons.group_work_outlined;
        break;
      case '古参冒険者':
        color = Colors.deepOrange.shade400;
        icon = Icons.shield_outlined;
        break;
      default:
        color = Colors.grey.shade400;
        icon = Icons.bookmark_border_rounded;
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withOpacity(0.25),
      side: BorderSide(color: color.withOpacity(0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
