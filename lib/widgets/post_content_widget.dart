// lib/widgets/post_content_widget.dart
import 'package:flutter/material.dart';
import '../models/post.dart'; // Post モデルをインポート

class PostContentWidget extends StatelessWidget {
  final Post post;
  const PostContentWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // 努力時間バッジを表示するかどうかのフラグ
    final bool showTimeSpent =
        post.timeSpentHours != null && post.timeSpentHours! > 0;
    // クエストタイトルバッジを表示するかどうかのフラグ
    final bool showQuestTitle = post.myQuestTitle != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // クエストタイトルか努力時間のどちらかが表示対象の場合のみ
          // Wrap ウィジェットと SizedBox を表示する
          if (showQuestTitle || showTimeSpent) ...[
            Wrap(
              spacing: 8.0, // バッジ間の水平方向のスペース
              runSpacing: 4.0, // バッジ間の垂直方向のスペース (改行時)
              children: [
                if (showQuestTitle)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade700)),
                    child: Text('🚀 ${post.myQuestTitle}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade100,
                            fontSize: 12)),
                  ),
                if (showTimeSpent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.green.shade800.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade600)),
                    child: Text(
                        // .toStringAsFixed(1) で小数点以下1桁まで表示
                        '⏱️ ${post.timeSpentHours!.toStringAsFixed(1)} h 努力',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade100,
                            fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8.0), // バッジと本文の間のスペース
          ],
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(post.text,
                  style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          if (post.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(post.photoURL!,
                    width: double.infinity, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}
