import 'package:flutter/material.dart';
import '../models/ability.dart';

class AbilityService {
  // アビリティのマスターデータ
  static final Map<String, Ability> _abilities = {
    '守護者の祈り': Ability(
      name: '守護者の祈り',
      description: 'フレンドの連続ログインを1日だけ保護できる（週1回）。',
      icon: Icons.shield,
    ),
    '祝福の風': Ability(
      name: '祝福の風',
      description: 'フレンドの投稿の獲得XPを1.5倍にする祝福を送れる。',
      icon: Icons.air,
    ),
    '叡智の共有': Ability(
      name: '叡智の共有',
      description: '自分のStudyクエスト投稿に「叡智」を付与し、他の人が見た際の獲得コインを増やす。',
      icon: Icons.lightbulb_circle,
    ),
  };

  // ジョブ（クラス名）に基づいて利用可能なアビリティを返す
  static List<Ability> getAbilitiesForClass(String className) {
    // 設計案に基づき、クラス名とアビリティを紐付ける
    if (className.contains('Knight') || className.contains('Monk')) {
      return [_abilities['守護者の祈り']!];
    }
    if (className.contains('Healer') ||
        className.contains('Priest') ||
        className.contains('Bard')) {
      return [_abilities['祝福の風']!];
    }
    if (className.contains('Mage') ||
        className.contains('Wizard') ||
        className.contains('Sage')) {
      return [_abilities['叡智の共有']!];
    }
    // それ以外のクラスは今はアビリティなし
    return [];
  }
}
