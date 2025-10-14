import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/comment.dart';
import 'models/post.dart';

class CommentScreen extends StatefulWidget {
  final Post post;
  const CommentScreen({super.key, required this.post});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final _commentController = TextEditingController();

  Future<void> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty) return;

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .doc();

    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

    final shouldNotify = widget.post.uid != user.uid;
    final notificationRef =
        FirebaseFirestore.instance.collection('notifications').doc();

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'uid': user.uid,
        'userName': user.displayName ?? '名無しさん',
        'userAvatar': user.photoURL,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(postRef, {'commentCount': FieldValue.increment(1)});

      if (shouldNotify) {
        transaction.set(notificationRef, {
          'type': 'comment',
          'fromUserId': user.uid,
          'fromUserName': user.displayName ?? '名無しさん',
          'fromUserAvatar': user.photoURL,
          'postId': widget.post.id,
          'postTextSnippet': widget.post.text.length > 50
              ? '${widget.post.text.substring(0, 50)}...'
              : widget.post.text,
          'targetUserId': widget.post.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コメント'),
      ),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data!.docs
                    .map((doc) => Comment.fromFirestore(doc))
                    .toList();
                if (comments.isEmpty) {
                  return const Center(child: Text('まだコメントはありません。'));
                }
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
                      title: Text(comment.userName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(comment.text),
                      trailing: Text(
                        DateFormat('M/d HH:mm')
                            .format(comment.createdAt.toDate()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
