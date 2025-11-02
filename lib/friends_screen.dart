// lib/friends_screen.dart
import 'package:flutter/material.dart';
// ▼▼▼ 新しいタブウィジェットをインポート ▼▼▼
import 'widgets/friends/friends_list_tab.dart';
import 'widgets/friends/notifications_tab.dart';
import 'widgets/friends/search_users_tab.dart';
// ▲▲▲

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
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

  // ▼▼▼ (これより下のロジックはすべて別ファイルに移動しました) ▼▼▼

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'フレンド'),
              Tab(text: 'お知らせ'),
              Tab(text: '探す'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ▼▼▼ 新しいウィジェットを呼び出す ▼▼▼
                const FriendsListTab(),
                NotificationsTab(tabController: _tabController),
                const SearchUsersTab(),
                // ▲▲▲
              ],
            ),
          ),
        ],
      ),
    );
  }
}
