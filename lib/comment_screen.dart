import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';
import 'models/comment.dart';

class CommentScreen extends StatefulWidget {
  final Post post;
  const CommentScreen({super.key, required this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _commentController = TextEditingController();
  bool _isPosting = false;

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

      // Webアプリの useAddComment を参考に実装
      final commentData = {
        'uid': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userAvatar': user.photoURL,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await postRef.collection('comments').add(commentData);
      await postRef.update({'commentCount': FieldValue.increment(1)});

      _commentController.clear();
    } catch (e) {
      print('コメント投稿エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('コメントの投稿に失敗しました。')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.post.userName}の投稿')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final comments = snapshot.data!.docs
                    .map((doc) => Comment.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: comment.userAvatar != null
                            ? NetworkImage(comment.userAvatar!)
                            : null,
                        child: comment.userAvatar == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(comment.userName),
                      subtitle: Text(comment.text),
                    );
                  },
                );
              },
            ),
          ),
          // コメント入力欄
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'コメントを追加...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _isPosting
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator())
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _addComment,
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
