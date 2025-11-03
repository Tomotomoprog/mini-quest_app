// lib/my_quest_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // (不要)
import 'models/my_quest.dart';
import 'models/post.dart';
import 'models/user_profile.dart';
import 'models/friendship.dart';
import 'utils/progression.dart';
import 'comment_screen.dart';
import 'profile_screen.dart';
import 'my_quest_post_screen.dart';
// import 'like_list_screen.dart'; // (不要)
import 'package:firebase_storage/firebase_storage.dart'; // ◀◀◀ Firebase Storage をインポート

import 'widgets/my_quest_detail/quest_detail_header.dart';
import 'widgets/my_quest_detail/post_card_widgets.dart'; // (前回のリファクタリングで導入済み)

class MyQuestDetailScreen extends StatefulWidget {
  final MyQuest quest;

  const MyQuestDetailScreen({super.key, required this.quest});

  @override
  State<MyQuestDetailScreen> createState() => _MyQuestDetailScreenState();
}

class _MyQuestDetailScreenState extends State<MyQuestDetailScreen> {
  Set<String> _likedPostIds = {}; // (DB構造は変えないので変数名はそのまま)
  UserProfile? _currentUserProfile;

  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  bool _isLoadingStatus = true;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid;
    _fetchMyDataAndFriendship();
  }

  Future<void> _fetchMyDataAndFriendship() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingStatus = false);
      return;
    }

    final userDocFuture =
        FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final likesFuture = FirebaseFirestore.instance
        .collectionGroup('likes') // (DB構造は 'likes' のまま)
        .where('uid', isEqualTo: user.uid)
        .get();

    final responses = await Future.wait([
      userDocFuture,
      likesFuture,
      _checkFriendshipStatus(),
    ]);

    final userDoc = responses[0] as DocumentSnapshot;
    final likesSnapshot = responses[1] as QuerySnapshot;

    if (mounted) {
      if (userDoc.exists) {
        final profile = UserProfile.fromFirestore(userDoc);
        setState(() {
          _currentUserProfile = profile;
        });
      }
      setState(() {
        _likedPostIds = likesSnapshot.docs
            .map((doc) => doc.reference.parent.parent!.id)
            .toSet();
        _isLoadingStatus = false;
      });
    }
  }

  Future<FriendshipStatus> _checkFriendshipStatus() async {
    final otherId = widget.quest.uid;

    if (_myId == null) return FriendshipStatus.none;
    if (_myId == otherId) return FriendshipStatus.accepted;

    final db = FirebaseFirestore.instance;
    final query = db
        .collection('friendships')
        .where('userIds', arrayContains: _myId)
        .get();

    final results = await query;

    FriendshipStatus status = FriendshipStatus.none;

    for (var doc in results.docs) {
      final userIds = doc.data()['userIds'] as List;
      if (userIds.contains(otherId)) {
        final docStatus = doc.data()['status'] as String;
        if (docStatus == 'accepted') {
          status = FriendshipStatus.accepted;
          break;
        } else if (docStatus == 'pending' || docStatus == 'quest_pending') {
          status = FriendshipStatus.pending;
        }
      }
    }

    if (mounted) {
      setState(() {
        _friendshipStatus = status;
      });
    }
    return status;
  }

  // ▼▼▼ 通知タイプを 'cheer' に変更 ▼▼▼
  Future<void> _toggleLike(String postId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef =
        postRef.collection('likes').doc(user.uid); // (DB構造は 'likes' のまま)
    final isLiked = _likedPostIds.contains(postId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) return;
      final post = Post.fromFirestore(postSnapshot);
      final shouldNotify = !isLiked && post.uid != user.uid;

      if (isLiked) {
        transaction.delete(likeRef);
        transaction.update(postRef,
            {'likeCount': FieldValue.increment(-1)}); // (DB構造は 'likeCount' のまま)
      } else {
        transaction.set(likeRef,
            {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
        transaction.update(postRef,
            {'likeCount': FieldValue.increment(1)}); // (DB構造は 'likeCount' のまま)
        if (shouldNotify) {
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          transaction.set(notificationRef, {
            'type': 'cheer', // ◀◀◀ 通知タイプを 'cheer' に変更
            'fromUserId': user.uid,
            'fromUserName': user.displayName ?? '名無しさん',
            'fromUserAvatar': user.photoURL,
            'postId': post.id,
            'postTextSnippet': post.text.length > 50
                ? '${post.text.substring(0, 50)}...'
                : post.text,
            'targetUserId': post.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    });
    // ▲▲▲

    setState(() {
      if (isLiked) {
        _likedPostIds.remove(postId);
      } else {
        _likedPostIds.add(postId);
      }
    });
  }

  // ▼▼▼ 投稿削除のロジックを追加 ▼▼▼
  Future<void> _showDeleteConfirmDialog(String postId, String? photoURL) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('投稿の削除'),
          content: const Text('この投稿を本当に削除しますか？この操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('削除', style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deletePost(postId, photoURL);
    }
  }

  Future<void> _deletePost(String postId, String? photoURL) async {
    try {
      // 1. (もしあれば) ストレージの写真を削除
      if (photoURL != null && photoURL.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(photoURL).delete();
      }

      // 2. 投稿ドキュメントを削除
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を削除しました')),
        );
      }
    } catch (e) {
      print('投稿の削除に失敗しました: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }
  // ▲▲▲

  Future<void> _completeQuest() async {
    try {
      await FirebaseFirestore.instance
          .collection('my_quests')
          .doc(widget.quest.id)
          .update({'status': 'completed'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('クエスト達成！おめでとうございます！'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _deleteQuest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('クエストを削除'),
          content: const Text('このマイクエストを本当に削除しますか？\n関連する投稿は削除されません。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('削除', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('my_quests')
            .doc(widget.quest.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('クエストを削除しました。')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除中にエラーが発生しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendQuestFriendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _myId == null) return;

    setState(() => _isLoadingStatus = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      final friendshipRef =
          FirebaseFirestore.instance.collection('friendships').doc();
      batch.set(friendshipRef, {
        'senderId': _myId,
        'receiverId': widget.quest.uid,
        'status': 'quest_pending',
        'createdAt': FieldValue.serverTimestamp(),
        'userIds': [_myId, widget.quest.uid],
      });

      final notificationRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'friend_request',
        'fromUserId': user.uid,
        'fromUserName': user.displayName ?? '名無しさん',
        'fromUserAvatar': user.photoURL,
        'targetUserId': widget.quest.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'postId': null,
        'postTextSnippet': null,
      });

      await batch.commit();

      if (mounted) {
        setState(() {
          _friendshipStatus = FriendshipStatus.pending;
          _isLoadingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フレンド申請を送信しました。')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('申請に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMyQuest = widget.quest.uid == _myId;
    final bool isFriendOrMyQuest =
        isMyQuest || _friendshipStatus == FriendshipStatus.accepted;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quest.title),
        actions: [
          if (isMyQuest)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'クエストを削除',
              onPressed: _deleteQuest,
            )
        ],
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      QuestDetailHeader(
                        quest: widget.quest,
                        isFriendOrMyQuest: isFriendOrMyQuest,
                        friendshipStatus: _friendshipStatus,
                        onSendRequest: _sendQuestFriendRequest,
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('myQuestId', isEqualTo: widget.quest.id)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child:
                                    Text('投稿の読み込みに失敗しました: ${snapshot.error}'));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('このクエストに関する投稿はまだありません。'),
                              ),
                            );
                          }

                          final posts = snapshot.data!.docs
                              .map((doc) => Post.fromFirestore(doc))
                              .toList();

                          return Column(
                            // ▼▼▼ .map() の中身を修正 ▼▼▼
                            children: posts.map((post) {
                              final bool isMyPost = post.uid == _myId;
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 8.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PostHeader(
                                      post: post,
                                      isFriendOrMyQuest: isFriendOrMyQuest,
                                    ),
                                    PostContent(post: post),
                                    if (_currentUserProfile != null)
                                      PostActions(
                                        post: post,
                                        isLiked:
                                            _likedPostIds.contains(post.id),
                                        onLike: () => _toggleLike(post.id),
                                        isMyPost: isMyPost, // ◀◀◀ 引数を追加
                                        onDelete: () =>
                                            _showDeleteConfirmDialog(post.id,
                                                post.photoURL), // ◀◀◀ 引数を追加
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            // ▲▲▲
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
      floatingActionButton: isMyQuest
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(widget.quest.id)
                  .snapshots(),
              builder: (context, questSnapshot) {
                if (!questSnapshot.hasData || !questSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);

                if (currentQuest.status == 'active') {
                  return FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              MyQuestPostScreen(initialQuest: widget.quest)));
                    },
                    icon: const Icon(Icons.add_task),
                    label: const Text('進捗を記録'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  );
                } else {
                  return const SizedBox.shrink();
                }
              })
          : null,
      bottomNavigationBar: isMyQuest
          ? StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('my_quests')
                  .doc(widget.quest.id)
                  .snapshots(),
              builder: (context, questSnapshot) {
                if (!questSnapshot.hasData || !questSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final currentQuest = MyQuest.fromFirestore(questSnapshot.data!);

                if (currentQuest.status == 'active') {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('目標を達成済みにする'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _completeQuest,
                    ),
                  );
                } else {
                  return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                          child: Chip(
                        label: Text('🎉 この目標は達成済みです！',
                            style: TextStyle(color: Colors.green[100])),
                        backgroundColor: Colors.green[800]?.withOpacity(0.5),
                        avatar:
                            Icon(Icons.emoji_events, color: Colors.green[100]),
                      )));
                }
              })
          : null,
    );
  }
}
