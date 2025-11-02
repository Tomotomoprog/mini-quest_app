// lib/category_quest_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/my_quest.dart';
import 'my_quest_detail_screen.dart';

// ▼▼▼ StatefulWidget に変更 ▼▼▼
class CategoryQuestListScreen extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryQuestListScreen({
    super.key,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<CategoryQuestListScreen> createState() =>
      _CategoryQuestListScreenState();
}

class _CategoryQuestListScreenState extends State<CategoryQuestListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ▼▼▼ フレンドリスト用の状態変数を追加 ▼▼▼
  Set<String> _friendIds = {};
  String? _myId;
  bool _isLoadingFriends = true;
  // ▲▲▲

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _fetchFriends(); // ◀◀◀ フレンドリストの取得を開始

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  // ▼▼▼ フレンドリストを取得する関数 ▼▼▼
  Future<void> _fetchFriends() async {
    if (_myId == null) {
      setState(() => _isLoadingFriends = false);
      return;
    }

    final friendsSnapshot = await FirebaseFirestore.instance
        .collection('friendships')
        .where('userIds', arrayContains: _myId)
        .where('status', isEqualTo: 'accepted')
        .get();

    final friendIds = friendsSnapshot.docs
        .map((doc) {
          final userIds = doc.data()['userIds'] as List;
          return userIds.firstWhere((id) => id != _myId, orElse: () => null);
        })
        .where((id) => id != null)
        .toSet(); // Set に変更

    if (mounted) {
      setState(() {
        _friendIds = friendIds.cast<String>();
        _isLoadingFriends = false;
      });
    }
  }
  // ▲▲▲

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: widget.categoryColor.withOpacity(0.1),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'クエスト名で検索...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[850], // 色調整
              ),
            ),
          ),
          Expanded(
            // ▼▼▼ クエスト取得の前にフレンド読み込みを待つ ▼▼▼
            child: _isLoadingFriends
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('my_quests')
                        .where('status', isEqualTo: 'active')
                        .where('category', isEqualTo: widget.categoryName)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        print(snapshot.error);
                        return const Center(child: Text('クエストの取得に失敗しました'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text('このカテゴリのクエストはまだありません。'));
                      }

                      var quests = snapshot.data!.docs
                          .map((doc) => MyQuest.fromFirestore(doc))
                          .toList();

                      if (_searchQuery.isNotEmpty) {
                        quests = quests.where((quest) {
                          final titleLower = quest.title.toLowerCase();
                          final queryLower = _searchQuery.toLowerCase();
                          return titleLower.contains(queryLower);
                        }).toList();
                      }

                      if (quests.isEmpty) {
                        return const Center(child: Text('該当するクエストが見つかりません。'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        itemCount: quests.length,
                        itemBuilder: (context, index) {
                          final quest = quests[index];
                          // ▼▼▼ フレンドかどうかを判定 ▼▼▼
                          final bool isFriendOrMyQuest = quest.uid == _myId ||
                              _friendIds.contains(quest.uid);
                          // ▲▲▲

                          return _MyQuestSearchCard(
                            quest: quest,
                            icon: widget.categoryIcon,
                            isFriendOrMyQuest: isFriendOrMyQuest, // ◀◀◀ 渡す
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MyQuestSearchCard extends StatelessWidget {
  final MyQuest quest;
  final IconData icon;
  final bool isFriendOrMyQuest; // ◀◀◀ 受け取る

  const _MyQuestSearchCard({
    required this.quest,
    required this.icon,
    required this.isFriendOrMyQuest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MyQuestDetailScreen(quest: quest),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(icon,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quest.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ▼▼▼ 挑戦者情報を匿名化 ▼▼▼
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage:
                        (isFriendOrMyQuest && quest.userPhotoURL != null)
                            ? NetworkImage(quest.userPhotoURL!)
                            : null,
                    child: (!isFriendOrMyQuest || quest.userPhotoURL == null)
                        ? const Icon(Icons.person, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFriendOrMyQuest
                          ? '${quest.userName} が挑戦中'
                          : '匿名の冒険者 が挑戦中',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isFriendOrMyQuest ? null : Colors.grey[400],
                            fontWeight: isFriendOrMyQuest
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
                ],
              ),
              // ▲▲▲
            ],
          ),
        ),
      ),
    );
  }
}
