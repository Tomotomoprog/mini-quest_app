import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/user_profile.dart';
import 'models/ability.dart';
import 'utils/ability_service.dart';
import 'utils/progression.dart';

// 分割したウィジェットをインポート
import 'widgets/profile/profile_header.dart';
import 'widgets/profile/profile_stats_tab.dart';
import 'widgets/profile/profile_posts_tab.dart';
import 'widgets/profile/profile_my_quests_tab.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('プロフィール'),
                pinned: true,
                actions: [
                  if (_isMyProfile)
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                    )
                ],
              ),
              SliverToBoxAdapter(
                child: ProfileHeader(
                  userProfile: userProfile,
                  level: level,
                  jobInfo: jobInfo,
                  isMyProfile: _isMyProfile,
                  onEditPicture: _updateProfilePicture,
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'ステータス'),
                      Tab(text: '投稿'),
                      Tab(text: 'マイクエスト'),
                    ],
                  ),
                ),
                pinned: true,
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProfileStatsTab(
                        userProfile: userProfile, abilities: abilities),
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
}

// TabBarをSliverPersistentHeaderとして使うためのヘルパークラス
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
