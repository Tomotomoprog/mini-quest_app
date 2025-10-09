import '../models/user_profile.dart';

class ClassResult {
  final String title;
  final String tier;
  final List<String> pair;

  ClassResult({required this.title, required this.tier, required this.pair});
}

// ユーザーのXPからレベルを計算する
int computeLevel(int xp) {
  return (xp / 100).floor() + 1;
}

// 次のレベルまでの進捗を計算する
Map<String, int> computeXpProgress(int xp) {
  final level = computeLevel(xp);
  final baseXpForCurrentLevel = (level - 1) * 100;
  final xpInCurrentLevel = xp - baseXpForCurrentLevel;
  final xpNeededForNextLevel = 100;

  return {
    'level': level,
    'xpInCurrentLevel': xpInCurrentLevel,
    'xpNeededForNextLevel': xpNeededForNextLevel,
  };
}

// ユーザーのステータスとレベルからクラス（ジョブ）を計算する
ClassResult computeClass(UserStats stats, int level) {
  final statsMap = {
    'Creative': stats.creative,
    'Life': stats.life,
    'Mental': stats.mental,
    'Physical': stats.physical,
    'Social': stats.social,
    'Study': stats.study,
  };

  final sortedEntries = statsMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final p1 = sortedEntries[0].key;
  final p2 = sortedEntries[1].key;

  final String tier;
  if (level <= 30) {
    tier = "初級";
  } else if (level <= 70) {
    tier = "中級";
  } else {
    tier = "上級";
  }

  final title = _mapClassTitle(p1, p2, tier);
  return ClassResult(title: title, tier: tier, pair: [p1, p2]);
}

String _mapClassTitle(String a, String b, String tier) {
  final pair = _orderPair(a, b);
  final key = '${pair[0]}-${pair[1]}';

  const classTable = {
    "Creative-Life": {"初級": "アイデア生活者", "中級": "ライフデザイナー", "上級": "革新ライフメーカー"},
    "Creative-Mental": {"初級": "夢見る人", "中級": "創造探求者", "上級": "哲学的クリエイター"},
    "Creative-Physical": {"初級": "元気クリエイター", "中級": "身体表現者", "上級": "究極アーティスト"},
    "Creative-Social": {
      "初級": "おしゃべりクリエイター",
      "中級": "共感デザイナー",
      "上級": "インスパイアリーダー"
    },
    "Creative-Study": {"初級": "ひらめき学習者", "中級": "発明家", "上級": "革命的イノベーター"},
    "Life-Mental": {"初級": "心整え人", "中級": "マインドガイド", "上級": "生活賢者"},
    "Life-Physical": {"初級": "元気生活者", "中級": "健康探求者", "上級": "究極フィットライフ"},
    "Life-Social": {"初級": "世話好きフレンド", "中級": "コミュニティ支援者", "上級": "暮らしのリーダー"},
    "Life-Study": {"初級": "生活学習者", "中級": "知識実践家", "上級": "暮らしの賢者"},
    "Mental-Physical": {"初級": "ストイック挑戦者", "中級": "精神戦士", "上級": "鉄人賢者"},
    "Mental-Social": {"初級": "癒しフレンド", "中級": "心の相談役", "上級": "共感賢者"},
    "Mental-Study": {"初級": "集中学習者", "中級": "思考探求者", "上級": "叡智の賢者"},
    "Physical-Social": {"初級": "スポーツ仲間", "中級": "闘志リーダー", "上級": "闘魂カリスマ"},
    "Physical-Study": {"初級": "学習マッチョ", "中級": "筋肉教授", "上級": "最強博士"},
    "Social-Study": {"初級": "勉強仲間", "中級": "知識シェアラー", "上級": "賢者リーダー"},
  };

  return classTable[key]?[tier] ?? "見習い";
}

List<String> _orderPair(String a, String b) {
  const order = ["Creative", "Life", "Mental", "Physical", "Social", "Study"];
  final pair = [a, b];
  pair.sort((val1, val2) => order.indexOf(val1).compareTo(order.indexOf(val2)));
  return pair;
}
