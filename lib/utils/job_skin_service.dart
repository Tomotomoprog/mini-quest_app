// ジョブ名から、対応するデフォルトの職業装備ID（画像ファイル名）を返すサービス
class JobSkinService {
  static String getTorsoSkinForJob(String jobTitle) {
    switch (jobTitle) {
      case '戦士':
        return 'warrior_armor.png'; // 例: assets/images/avatar/torso/warrior_armor.png
      case '魔術師':
        return 'mage_robe.png';
      case '治癒士':
        return 'healer_robe.png';
      case '芸術家':
        return 'artist_smock.png';
      case '冒険家':
        return 'explorer_tunic.png';
      default: // 見習い
        return 'novice_clothes.png';
    }
  }

  // TODO: 頭、足など他の部位のジョブスキンも必要に応じて追加
}
