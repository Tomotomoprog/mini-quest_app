// lib/utils/progression.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class JobResult {
  final String title;

  JobResult({required this.title});
}

// ▼▼▼ 既存のコード互換用（トップレベル関数） ▼▼▼
int computeLevel(int xp) {
  return Progression.getLevel(xp);
}

JobResult computeJob(UserStats stats, int level) {
  return Progression.computeJob(stats, level);
}

Map<String, int> computeXpProgress(int xp) {
  return Progression.getXpProgress(xp);
}
// ▲▲▲

// ▼▼▼ 新しいクラス定義 ▼▼▼
class Progression {
  // ユーザーのXPからレベルを計算する
  static int getLevel(int xp) {
    // 1レベルアップに必要なXPは100
    return (xp / 100).floor() + 1;
  }

  // 次のレベルに到達するための累積経験値（閾値）を取得
  // (例: Lv.1 -> 100, Lv.2 -> 200)
  static int getExpForNextLevel(int xp) {
    final level = getLevel(xp);
    return level * 100;
  }

  // 次のレベルまでの進捗詳細
  static Map<String, int> getXpProgress(int xp) {
    final level = getLevel(xp);
    final baseXpForCurrentLevel = (level - 1) * 100;
    final xpInCurrentLevel = xp - baseXpForCurrentLevel;
    final xpNeededForNextLevel = 100;

    return {
      'level': level,
      'xpInCurrentLevel': xpInCurrentLevel,
      'xpNeededForNextLevel': xpNeededForNextLevel,
    };
  }

  // ジョブのアイコンを取得
  static IconData getJobIcon(String jobTitle) {
    switch (jobTitle) {
      case '魔術師':
        return Icons.auto_fix_high;
      case '治癒士':
        return Icons.favorite;
      case '冒険家':
        return Icons.explore;
      case '戦士':
        return Icons.security;
      case '芸術家':
        return Icons.palette;
      default:
        return Icons.work_outline;
    }
  }

  // ジョブの計算ロジック
  static JobResult computeJob(UserStats stats, int level) {
    // レベル10未満は「見習い」
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

    // 2つのステータスが「バランス良く高い」と判定するための閾値
    const balanceThreshold = 0.7;

    // バランス型のジョブ判定
    if ((top1Stat == 'Study' && top2Stat == 'Mental' ||
            top1Stat == 'Mental' && top2Stat == 'Study') &&
        (top2Value >= top1Value * balanceThreshold)) {
      return JobResult(title: "魔術師");
    }
    if ((top1Stat == 'Social' && top2Stat == 'Life' ||
            top1Stat == 'Life' && top2Stat == 'Social') &&
        (top2Value >= top1Value * balanceThreshold)) {
      return JobResult(title: "治癒士");
    }
    if ((top1Stat == 'Life' && top2Stat == 'Physical' ||
            top1Stat == 'Physical' && top2Stat == 'Life') &&
        (top2Value >= top1Value * balanceThreshold)) {
      return JobResult(title: "冒険家");
    }

    // 特化型のジョブ判定
    if (top1Stat == 'Physical') {
      return JobResult(title: "戦士");
    }
    if (top1Stat == 'Creative') {
      return JobResult(title: "芸術家");
    }

    // デフォルト
    return JobResult(title: "見習い");
  }
}
