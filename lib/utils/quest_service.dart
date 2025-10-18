import 'dart:math';
import '../models/quest.dart';

class QuestService {
  // マスタデータ: アプリ内のすべてのクエストを定義
  static final List<Quest> _allQuests = [
    // Life
    Quest(
        id: 'L001',
        title: '部屋を少し片付ける',
        description: '5分だけでいい。身の回りを整理して、心を整えよう。',
        category: 'Life',
        tag: '暮らし'),
    Quest(
        id: 'L002',
        title: '植物に水をやる',
        description: '身近な生命の世話をして、心のうるおいを。',
        category: 'Life',
        tag: '暮らし'),
    Quest(
        id: 'L003',
        title: '一杯のコーヒーを丁寧に淹れる',
        description: '香りや温度、その一杯をじっくり味わおう。',
        category: 'Life',
        tag: '暮らし'),

    // Study
    Quest(
        id: 'S001',
        title: '新しい英単語を5つ覚える',
        description: '知識の扉を少しだけ開いてみよう。',
        category: 'Study',
        tag: '学習'),
    Quest(
        id: 'S002',
        title: '気になっていた記事を1つ読む',
        description: '知的好奇心を満たす時間を作ろう。',
        category: 'Study',
        tag: '学習'),
    Quest(
        id: 'S003',
        title: '15分間、資格の勉強をする',
        description: '未来の自分のための小さな投資。',
        category: 'Study',
        tag: '学習'),

    // Physical
    Quest(
        id: 'P001',
        title: '10分間のストレッチをする',
        description: '凝り固まった体をゆっくりとほぐそう。',
        category: 'Physical',
        tag: '運動'),
    Quest(
        id: 'P002',
        title: '一駅手前で降りて歩く',
        description: '日常に少しだけ運動を取り入れよう。',
        category: 'Physical',
        tag: '運動'),
    Quest(
        id: 'P003',
        title: '寝る前に3分間の筋トレをする',
        description: '明日の自分のための小さな挑戦。',
        category: 'Physical',
        tag: '運動'),

    // Social
    Quest(
        id: 'C001',
        title: '友人に「元気？」と連絡する',
        description: '大切な人との繋がりを確かめよう。',
        category: 'Social',
        tag: '交流'),
    Quest(
        id: 'C002',
        title: '家族と5分間話す',
        description: '身近な人との対話の時間を作ろう。',
        category: 'Social',
        tag: '交流'),
    Quest(
        id: 'C003',
        title: 'SNSで誰かの投稿に温かいコメントをする',
        description: 'ポジティブな言葉を世界に一つ増やそう。',
        category: 'Social',
        tag: '交流'),

    // Creative
    Quest(
        id: 'R001',
        title: '今日の出来事を一行で詩にする',
        description: '日常を言葉で切り取ってみよう。',
        category: 'Creative',
        tag: '創造'),
    Quest(
        id: 'R002',
        title: '簡単なイラストを1つ描く',
        description: '上手い下手は関係ない。表現を楽しもう。',
        category: 'Creative',
        tag: '創造'),
    Quest(
        id: 'R003',
        title: '好きな曲の鼻歌を録音してみる',
        description: '自分だけのメロディを形に残そう。',
        category: 'Creative',
        tag: '創造'),

    // Mental
    Quest(
        id: 'M001',
        title: '3分間、瞑想をする',
        description: '目を閉じて、自分の呼吸に意識を向けてみよう。',
        category: 'Mental',
        tag: '内省'),
    Quest(
        id: 'M002',
        title: '今日感謝したことを1つ書き出す',
        description: '小さな幸せを見つける練習。',
        category: 'Mental',
        tag: '内省'),
    Quest(
        id: 'M003',
        title: '寝る前に5分間、日記をつける',
        description: '一日を振り返り、自分の心と対話しよう。',
        category: 'Mental',
        tag: '内省'),
  ];

  static Future<List<Quest>> getDailyQuests() async {
    // 日付を元にしたシードで、毎日同じ結果が得られるようにする
    final random =
        Random(DateTime.now().day + DateTime.now().month + DateTime.now().year);

    // 全クエストをランダムにシャッフル
    final shuffledQuests = List<Quest>.from(_allQuests)..shuffle(random);

    final List<Quest> dailyQuests = [];
    final Set<String> usedCategories = {};

    // シャッフルされたリストから、カテゴリが重複しないように3つ選ぶ
    for (final quest in shuffledQuests) {
      if (!usedCategories.contains(quest.category)) {
        dailyQuests.add(quest);
        usedCategories.add(quest.category);
      }

      // 3つ見つかったらループを抜ける
      if (dailyQuests.length == 3) {
        break;
      }
    }

    return dailyQuests;
  }
}
