// lib/profile_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/user_profile.dart';
import 'models/friendship.dart'; // ◀◀◀ フレンドステータスをインポート
import 'utils/progression.dart';

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

  // ▼▼▼ 状態変数を追加 ▼▼▼
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  bool _isLoadingStatus = true;
  // ▲▲▲

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFriendshipStatus(); // ◀◀◀ フレンド関係をチェック
  }

  // ▼▼▼ 別のプロフィールに移動したときに再チェックする処理 ▼▼▼
  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      _checkFriendshipStatus();
    }
  }
  // ▲▲▲

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isMyProfile =>
      FirebaseAuth.instance.currentUser?.uid == widget.userId;

  // ▼▼▼ フレンドステータスを確認する関数 ▼▼▼
  Future<void> _checkFriendshipStatus() async {
    setState(() {
      _isLoadingStatus = true;
    });
    final myId = FirebaseAuth.instance.currentUser?.uid;
    final otherId = widget.userId;

    // ログインしていない、または自分のプロフィールの場合
    if (myId == null) {
      setState(() {
        _friendshipStatus = FriendshipStatus.none;
        _isLoadingStatus = false;
      });
      return;
    }
    if (myId == otherId) {
      setState(() {
        _friendshipStatus = FriendshipStatus.accepted; // 自分のプロフは常時許可
        _isLoadingStatus = false;
      });
      return;
    }

    // フレンドかどうかをDBに確認
    final db = FirebaseFirestore.instance;
    final query1 = db
        .collection('friendships')
        .where('userIds', isEqualTo: [myId, otherId])
        .where('status', isEqualTo: 'accepted')
        .get();

    final query2 = db
        .collection('friendships')
        .where('userIds', isEqualTo: [otherId, myId])
        .where('status', isEqualTo: 'accepted')
        .get();

    final results = await Future.wait([query1, query2]);

    final bool isFriend =
        results[0].docs.isNotEmpty || results[1].docs.isNotEmpty;

    if (mounted) {
      setState(() {
        _friendshipStatus =
            isFriend ? FriendshipStatus.accepted : FriendshipStatus.none;
        _isLoadingStatus = false;
      });
    }
  }
  // ▲▲▲

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
    final Color primaryAccent = Theme.of(context).colorScheme.primary;

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
        // ▼▼▼ TabBarのロジックを修正 ▼▼▼
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          // フレンドステータスが読み込み中の場合はタブを隠す
          child: _isLoadingStatus
              ? const SizedBox.shrink() // 空白
              : Builder(builder: (context) {
                  // contextを正しく取得
                  // フレンドか自分の場合は全タブ表示
                  final bool canViewPrivateTabs = _isMyProfile ||
                      _friendshipStatus == FriendshipStatus.accepted;

                  return TabBar(
                    controller: _tabController,
                    labelColor: primaryAccent,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: primaryAccent,
                    tabs: [
                      const Tab(text: 'ステータス'),
                      Tab(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!canViewPrivateTabs)
                            Icon(Icons.lock_outline,
                                size: 18, color: Colors.grey[600]),
                          if (!canViewPrivateTabs) const SizedBox(width: 8),
                          const Text('投稿'),
                        ]),
                      ),
                      Tab(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (!canViewPrivateTabs)
                            Icon(Icons.lock_outline,
                                size: 18, color: Colors.grey[600]),
                          if (!canViewPrivateTabs) const SizedBox(width: 8),
                          const Text('マイクエスト'),
                        ]),
                      ),
                    ],
                    // ロック中のタブがタップされたら無効化する
                    onTap: (index) {
                      if (!canViewPrivateTabs && (index == 1 || index == 2)) {
                        _tabController.index = 0; // ステータスタブに戻す
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('フレンドになると閲覧できます'),
                            backgroundColor: primaryAccent,
                          ),
                        );
                      }
                    },
                  );
                }),
        ),
        // ▲▲▲
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || _isLoadingStatus) {
            // ◀◀◀ 読み込み中を追加
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('ユーザーが見つかりません。'));
          }

          final userProfile = UserProfile.fromFirestore(snapshot.data!);
          final progress = computeXpProgress(userProfile.xp);
          final level = progress['level']!;
          final jobInfo = computeJob(userProfile.stats, level);

          // ▼▼▼ 表示可否を決定 ▼▼▼
          final bool canViewPrivateTabs =
              _isMyProfile || _friendshipStatus == FriendshipStatus.accepted;
          // ▲▲▲

          return TabBarView(
            // ▼▼▼ TabControllerの操作はTabBarのonTapに任せる ▼▼▼
            // physics: canViewPrivateTabs
            //     ? null // フレンドならスワイプ可能
            //     : const NeverScrollableScrollPhysics(), // フレンド以外はスワイプ禁止
            // ▲▲▲
            controller: _tabController,
            children: [
              // 1. ステータスタブ (常に表示)
              ProfileStatsTab(
                userProfile: userProfile,
                level: level,
                jobInfo: jobInfo,
                isMyProfile: _isMyProfile,
                onEditPicture: _updateProfilePicture,
              ),
              // 2. 投稿タブ (条件付き表示)
              canViewPrivateTabs
                  ? ProfilePostsTab(userId: widget.userId)
                  : const _LockedTabPlaceholder(message: 'フレンドになると投稿を閲覧できます。'),

              // 3. マイクエストタブ (条件付き表示)
              canViewPrivateTabs
                  ? ProfileMyQuestsTab(userId: widget.userId)
                  : const _LockedTabPlaceholder(
                      message: 'フレンドになるとマイクエストを閲覧できます。'),
            ],
          );
        },
      ),
    );
  }
}

// ▼▼▼ ロック中タブの中身 (新規追加) ▼▼▼
class _LockedTabPlaceholder extends StatelessWidget {
  final String message;
  const _LockedTabPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// ▲▲▲
