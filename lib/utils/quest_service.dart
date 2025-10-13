import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quest.dart';

// Webアプリの useQuests.ts のロジックをDartに移植
class QuestService {
  // 今日の日付からシード値（ランダムの素）を生成する
  static int _getSeedForToday() {
    final now = DateTime.now();
    // YYYYMMDD 形式の文字列を作成
    final seedStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    return seedStr.hashCode;
  }

  // 3つのデイリークエストを取得する
  static Future<List<Quest>> getDailyQuests({int count = 3}) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('quests').get();
    if (snapshot.docs.isEmpty) return [];

    final allQuests =
        snapshot.docs.map((doc) => Quest.fromFirestore(doc)).toList();

    // 日付ベースのシードを使ってクエストをシャッフル
    final random = Random(_getSeedForToday());
    allQuests.shuffle(random);

    // 最初の `count` 件をデイリークエストとして返す
    return allQuests.take(count).toList();
  }
}
