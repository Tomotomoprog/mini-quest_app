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

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = Theme.of(context).colorScheme.primary;

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
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: primaryBlue,
          tabs: const [
            Tab(text: 'ステータス'),
            Tab(text: '投稿'),
            Tab(text: 'マイクエスト'),
          ],
        ),
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

          // ▼▼▼ Columnとヘッダー部分を削除 ▼▼▼
          // return Column(
          //   children: [
          //     Padding(...), // アバターと名前
          //     Padding(...), // グレーパネル
          // ▼▼▼ TabBarViewを直接返すように変更 ▼▼▼
          return TabBarView(
            controller: _tabController,
            children: [
              // ▼▼▼ ステータスタブに必要なデータを渡す ▼▼▼
              ProfileStatsTab(
                userProfile: userProfile,
                level: level,
                jobInfo: jobInfo,
                abilities: abilities,
                isMyProfile: _isMyProfile,
                onEditPicture: _updateProfilePicture,
              ),
              // ▲▲▲ ステータスタブに必要なデータを渡す ▲▲▲
              ProfilePostsTab(userId: widget.userId),
              ProfileMyQuestsTab(userId: widget.userId),
            ],
            // ▲▲▲ TabBarViewを直接返すように変更 ▲▲▲
          );
          //   ],
          // );
          // ▲▲▲ Columnとヘッダー部分を削除 ▲▲▲
        },
      ),
    );
  }
}
