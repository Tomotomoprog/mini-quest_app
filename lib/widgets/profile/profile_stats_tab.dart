// lib/widgets/profile/profile_stats_tab.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../utils/progression.dart';
import 'dart:math' as math;
import 'hex_stats_chart.dart';
import 'profile_avatar_section.dart';
import 'profile_status_panel.dart';
import 'star_particle_overlay.dart';
import '../../tutorial_screens.dart'; // ◀◀◀ 追加

class ProfileStatsTab extends StatelessWidget {
  final UserProfile userProfile;
  final int level;
  final JobResult jobInfo;
  final bool isMyProfile;
  final VoidCallback onEditPicture;
  final bool showXpAnimation;

  const ProfileStatsTab({
    super.key,
    required this.userProfile,
    required this.level,
    required this.jobInfo,
    required this.isMyProfile,
    required this.onEditPicture,
    this.showXpAnimation = false,
  });

  static const categoryColors = {
    'Life': Color(0xFF4ADE80),
    'Study': Color(0xFF60A5FA),
    'Physical': Color(0xFFF87171),
    'Social': Color(0xFFF472B6),
    'Creative': Color(0xFFC084FC),
    'Mental': Color(0xFF818CF8),
  };

  static const String _defaultAvatar =
      'lib/assets/images/avatar/minarai_boy.jpg';

  void _showAvatarSelectionDialog(BuildContext context) {
    final List<String> availableAvatars = [
      'lib/assets/images/avatar/minarai_boy.jpg',
      'lib/assets/images/avatar/minnarai_girl.jpg',
    ];

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
                  children: availableAvatars.map((path) {
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
        onEditPicture();
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isMe =
        (currentUserId != null && currentUserId == userProfile.uid);

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

    final String displayAvatarPath =
        userProfile.characterImage ?? _defaultAvatar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. アバターセクション
          ProfileAvatarSection(
            userProfile: userProfile,
            isMyProfile: isMe,
            onEditPicture: onEditPicture,
          ),

          // 2. ステータスパネル
          ProfileStatusPanel(
            userProfile: userProfile,
            level: level,
            isMyProfile: isMe,
          ),

          const SizedBox(height: 24),

          // 3. 六角形チャート (スターエフェクトでラップ)
          StarParticleOverlay(
            trigger: showXpAnimation,
            size: 350,
            child: HexStatsChart(
              stats: userProfile.stats,
              max: currentMax,
              colors: categoryColors,
              avatarPath: displayAvatarPath,
              onAvatarTap:
                  isMe ? () => _showAvatarSelectionDialog(context) : null,
            ),
          ),

          // ▼▼▼ 追加: チュートリアル再確認ボタン ▼▼▼
          if (isMe) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    // 再確認なので isFirstTime: false
                    builder: (context) =>
                        const TutorialContentScreen(isFirstTime: false),
                  ),
                );
              },
              icon:
                  const Icon(Icons.help_outline, color: Colors.grey, size: 18),
              label: const Text(
                'チュートリアルを確認する',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
          // ▲▲▲
        ],
      ),
    );
  }
}
