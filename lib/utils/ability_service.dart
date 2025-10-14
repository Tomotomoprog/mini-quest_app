import 'package:flutter/material.dart';
import '../models/ability.dart';

class AbilityService {
  // 設計案に基づいたアビリティのマスターデータ
  static final Map<String, Ability> _abilities = {
    '不屈の激励': Ability(
      name: '不屈の激励',
      description: 'フレンドの「運動」に関する投稿に使うと、相手の次の「運動」記録で得られる経験値が少しアップする。',
      icon: Icons.fitness_center, // 戦士のイメージ
    ),
    '叡智の共有': Ability(
      name: '叡智の共有',
      description: '自分の「学習」クエスト記録に「叡智」を付与して投稿できる。他のフレンドが見ると、もらえるコインが少し増える。',
      icon: Icons.lightbulb_outline, // 魔術師のイメージ
    ),
    '祝福の風': Ability(
      name: '祝福の風',
      description: 'フレンドの投稿に「祝福」スタンプを送る。受け取った相手は、その投稿で得られるXPが1.5倍になる。',
      icon: Icons.air, // 治癒士のイメージ
    ),
    '彩りの霊感': Ability(
      name: '彩りの霊感',
      description: 'フレンドの投稿に「霊感」スタンプを送る。受け取った相手は、街の装飾品やアバターの装備作成に使える素材を少量獲得する。',
      icon: Icons.palette_outlined, // 芸術家のイメージ
    ),
    '発見のコンパス': Ability(
      name: '発見のコンパス',
      description:
          'フレンドの投稿に「ナイス発見!」スタンプを送る。受け取った相手は、次のデイリークエスト完了時にレアな素材が手に入りやすくなる。',
      icon: Icons.explore_outlined, // 冒険家のイメージ
    ),
  };

  // ジョブ名（日本語）に基づいて利用可能なアビリティのリストを返す
  static List<Ability> getAbilitiesForClass(String jobTitle) {
    switch (jobTitle) {
      case '戦士':
        return [_abilities['不屈の激励']!];
      case '魔術師':
        return [_abilities['叡智の共有']!];
      case '治癒士':
        return [_abilities['祝福の風']!];
      case '芸術家':
        return [_abilities['彩りの霊感']!];
      case '冒険家':
        return [_abilities['発見のコンパス']!];
      default:
        // 見習いやその他のクラスはアビリティなし
        return [];
    }
  }
}
