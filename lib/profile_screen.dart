// lib/profile_screen.dart
import 'dart:io';
import 'dart:ui'; // 影や文字効果のために必要
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/user_profile.dart';
import 'models/ability.dart';
import 'utils/ability_service.dart';
import 'utils/progression.dart';

import 'widgets/profile/profile_stats_tab.dart';
import 'widgets/profile/profile_posts_tab.dart';
import 'widgets/profile/profile_my_quests_tab.dart';
import 'profile_friends_list_screen.dart'; // Friend list screen import

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isMyProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.userId;

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_pictures/${user.uid}');
      await storageRef.putFile(file);
      final photoURL = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoURL': photoURL});
      await user.updatePhotoURL(photoURL);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プロフィール画像を変更しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像のアップロードに失敗しました: $e')),
        );
      }
    }
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '0.0h';
    }
    final hours = totalMinutes / 60.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  // === ▼▼▼ パネル内の1項目表示 (文字色:白、影で浮き上がらせる) ▼▼▼ ===
  Widget _buildSingleStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor, // アイコンの色は引数で受け取る
  }) {
    // === ▼▼▼ 文字色を白に統一 ▼▼▼ ===
    final Color textColor = Colors.white;
    final Color labelColor = Colors.white.withOpacity(0.9);
    // === ▲▲▲ 文字色を白に統一 ▲▲▲ ===
    // 文字を浮き上がらせるための影
    final List<Shadow> textShadows = [
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 2.0,
        color: Colors.black.withOpacity(0.6), // 影を調整
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
            // アイコンにも影
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
  // === ▲▲▲ パネル内の1項目表示 (文字色:白、影で浮き上がらせる) ▲▲▲ ===

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

  // アバター表示用ウィジェット
  Widget _buildAvatarWidget(UserProfile userProfile) {
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
        if (_isMyProfile)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).primaryColor,
              shape: CircleBorder(),
              elevation: 3.0,
              child: InkWell(
                onTap: _updateProfilePicture,
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

  @override
  Widget build(BuildContext context) {
    // === ▼▼▼ パネルをグレー系に変更 ▼▼▼ ===
    final panelColor = Colors.blueGrey.shade700; // グレー系の色
    final panelBorderColor = Colors.blueGrey.shade800; // 枠線の色も合わせる
    final Color primaryBlue = Theme.of(context).colorScheme.primary;
    // === ▲▲▲ パネルをグレー系に変更 ▲▲▲ ===

    // === ▼▼▼ 各アイコンの色を定義 (白文字に映えるように調整) ▼▼▼ ===
    final List<Color> iconColors = [
      Colors.yellow.shade300, // レベル (星) - 黄色系
      Colors.cyan.shade200, // ジョブ (仕事) - 水色系
      Colors.redAccent.shade100, // 連続記録 (炎) - 赤系
      Colors.lightGreen.shade300, // 総努力時間 (タイマー) - 緑系
      Colors.orange.shade300, // 総達成数 (トロフィー) - オレンジ系
      Colors.pink.shade200, // フレンド (人々) - ピンク系
    ];
    // === ▲▲▲ 各アイコンの色を定義 ▲▲▲ ===

    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
        actions: [
          if (_isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'ログアウト',
              onPressed: () => FirebaseAuth.instance.signOut(),
            )
        ],
        // === ▼▼▼ AppBarのbottomにTabBarを配置 (1つだけにする) ▼▼▼ ===
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: primaryBlue,
          tabs: const [
            Tab(text: 'ステータス'), // ラベルを戻す
            Tab(text: '投稿'),
            Tab(text: 'マイクエスト'),
          ],
        ),
        // === ▲▲▲ AppBarのbottomにTabBarを配置 (1つだけにする) ▲▲▲ ===
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('ユーザーが見つかりません。'));
          }

          final userProfile = UserProfile.fromFirestore(snapshot.data!);
          final progress = computeXpProgress(userProfile.xp);
          final level = progress['level']!;
          final jobInfo = computeJob(userProfile.stats, level);
          final abilities = AbilityService.getAbilitiesForClass(jobInfo.title);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 20.0),
                child: Row(
                  children: [
                    _buildAvatarWidget(userProfile),
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
              // --- ▼▼▼ グレーパネル ▼▼▼ ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: panelColor, // グレー系の色
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: panelBorderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4), // 影の色
                        blurRadius: 25, // ぼかし
                        spreadRadius: 1,
                        offset: Offset(0, 10), // 下方向への影
                      ),
                      BoxShadow(
                        // 内側のハイライト
                        color: Colors.white.withOpacity(0.1), // 白系のハイライト
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
                        label1: 'レベル', value1: level.toString(),
                        iconColor1: iconColors[0], // 色指定
                        icon2: Icons.work_outline, label2: 'ジョブ',
                        value2: jobInfo.title,
                        iconColor2: iconColors[1], // 色指定
                      ),
                      Divider(
                          color: Colors.white.withOpacity(0.3),
                          height: 24,
                          thickness: 0.5), // 区切り線調整
                      _buildPanelRow(
                        context: context,
                        icon1: Icons.local_fire_department_outlined,
                        label1: '連続記録',
                        value1: '${userProfile.currentStreak} 日',
                        iconColor1: iconColors[2], // 色指定
                        icon2: Icons.timer_outlined, label2: '総努力時間',
                        value2: _formatDuration(userProfile.totalEffortMinutes),
                        iconColor2: iconColors[3], // 色指定
                      ),
                      Divider(
                          color: Colors.white.withOpacity(0.3),
                          height: 24,
                          thickness: 0.5), // 区切り線調整
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
                                    iconColor: iconColors[4]); // 色指定
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
                                      iconColor: iconColors[5]), // 色指定
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
              // --- ▲▲▲ グレーパネル ---

              // === ▼▼▼ Column内のTabBarを削除 ▼▼▼ ===
              // Padding(
              //   padding: const EdgeInsets.only(top: 16.0),
              //   child: TabBar(...),
              // ),
              // === ▲▲▲ Column内のTabBarを削除 ▲▲▲ ===

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ▼▼▼ ステータスタブには詳細情報 (ProfileStatsTab) を表示 ▼▼▼
                    ProfileStatsTab(
                        userProfile: userProfile, abilities: abilities),
                    // ▲▲▲ ステータスタブには詳細情報 (ProfileStatsTab) を表示 ▲▲▲
                    ProfilePostsTab(userId: widget.userId),
                    ProfileMyQuestsTab(userId: widget.userId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} // _ProfileScreenState の終わり
