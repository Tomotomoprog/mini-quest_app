// lib/widgets/profile/profile_posts_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/post.dart';

// プロフィール画面の「投稿」タブのメインウィジェット (ProfilePostsTab)
// このクラス名に修正することで、ProfileStatsTabとの名前の競合が解消されます。
class ProfilePostsTab extends StatelessWidget {
  final String userId;
  const ProfilePostsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('まだ投稿がありません。'));
        }

        final posts =
            snapshot.data!.docs.map((doc) => Post.fromFirestore(doc)).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(post: post);
          },
        );
      },
    );
  }
}

// 投稿内容を簡潔に表示するためのカードウィジェット
class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 写真
          if (post.photoURL != null)
            Padding(
              padding: const EdgeInsets.all(16.0).copyWith(bottom: 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(post.photoURL!,
                    width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
            ),

          // テキストとフッター
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 紐付けられたマイクエストのタイトル
                if (post.myQuestTitle != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200)),
                    child: Text('🚀 ${post.myQuestTitle}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 12)),
                  ),
                // 投稿テキスト
                if (post.text.isNotEmpty)
                  Text(
                    post.text,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                // いいね、コメント数、日時
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 4),
                        Text(post.likeCount.toString(),
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline,
                            color: Colors.grey[600], size: 16),
                        const SizedBox(width: 4),
                        Text(post.commentCount.toString(),
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    Text(
                      DateFormat('M/d HH:mm').format(post.createdAt.toDate()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
