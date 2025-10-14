import '../models/user_profile.dart';

class JobResult {
  final String title;

  JobResult({required this.title});
}

// ユーザーのXPからレベルを計算する
int computeLevel(int xp) {
  // 1レベルアップに必要なXPは100
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

// ユーザーのステータスとレベルから一次職（ジョブ）を計算する
JobResult computeJob(UserStats stats, int level) {
  // 設計案の通り、レベル10未満は「見習い」
  if (level < 10) {
    return JobResult(title: "見習い");
  }

  final statsMap = {
    'Creative': stats.creative,
    'Life': stats.life,
    'Mental': stats.mental,
    'Physical': stats.physical,
    'Social': stats.social,
    'Study': stats.study,
  };

  // 経験値が高い順にソート
  final sortedEntries = statsMap.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final top1Stat = sortedEntries[0].key;
  final top1Value = sortedEntries[0].value;
  final top2Stat = sortedEntries[1].key;
  final top2Value = sortedEntries[1].value;

  // 2つのステータスが「バランス良く高い」と判定するための閾値（2番目が1番目の70%以上）
  const balanceThreshold = 0.7;

  // 設計案に基づき、バランス型のジョブから先に判定する
  // 魔術師: StudyとMentalがバランス良く高い
  if ((top1Stat == 'Study' && top2Stat == 'Mental' ||
          top1Stat == 'Mental' && top2Stat == 'Study') &&
      (top2Value >= top1Value * balanceThreshold)) {
    return JobResult(title: "魔術師");
  }
  // 治癒士: SocialとLifeがバランス良く高い
  if ((top1Stat == 'Social' && top2Stat == 'Life' ||
          top1Stat == 'Life' && top2Stat == 'Social') &&
      (top2Value >= top1Value * balanceThreshold)) {
    return JobResult(title: "治癒士");
  }
  // 冒険家: LifeとPhysicalがバランス良く高い
  if ((top1Stat == 'Life' && top2Stat == 'Physical' ||
          top1Stat == 'Physical' && top2Stat == 'Life') &&
      (top2Value >= top1Value * balanceThreshold)) {
    return JobResult(title: "冒険家");
  }

  // 特化型のジョブを判定
  // 戦士: Physicalが最も高い
  if (top1Stat == 'Physical') {
    return JobResult(title: "戦士");
  }
  // 芸術家: Creativeが最も高い
  if (top1Stat == 'Creative') {
    return JobResult(title: "芸術家");
  }

  // どの条件にも当てはまらない場合のデフォルト
  return JobResult(title: "見習い");
}
