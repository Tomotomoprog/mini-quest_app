// lib/utils/progression.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class JobResult {
  final String title;
  JobResult({required this.title});
}

// ジョブの定義データ
class JobDefinition {
  final String id;
  final String title;
  final String rank; // Apprentice, Novice, Intermediate, Advanced
  final String description; // 一覧用の短い説明
  final String story; // 詳細画面用のストーリー・世界観
  final Map<String, int> requiredStats; // 必要なステータス値
  final int requiredLevel;

  const JobDefinition({
    required this.id,
    required this.title,
    required this.rank,
    required this.description,
    required this.story,
    required this.requiredStats,
    required this.requiredLevel,
  });
}

class Progression {
  static int getLevel(int xp) {
    return (xp / 100).floor() + 1;
  }

  static int getExpForNextLevel(int xp) {
    final level = getLevel(xp);
    return level * 100;
  }

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

  static IconData getJobIcon(String jobTitle) {
    if (jobTitle.contains('魔') ||
        jobTitle.contains('ウィザード') ||
        jobTitle.contains('賢者')) return Icons.auto_fix_high;
    if (jobTitle.contains('戦') ||
        jobTitle.contains('騎士') ||
        jobTitle.contains('剣聖') ||
        jobTitle.contains('勇者') ||
        jobTitle.contains('ヴァルキリー')) return Icons.security;
    if (jobTitle.contains('治癒') ||
        jobTitle.contains('司教') ||
        jobTitle.contains('聖') ||
        jobTitle.contains('パラディン')) return Icons.favorite;
    if (jobTitle.contains('冒険') ||
        jobTitle.contains('レンジャー') ||
        jobTitle.contains('狩') ||
        jobTitle.contains('旅') ||
        jobTitle.contains('仙人')) return Icons.explore;
    if (jobTitle.contains('芸') ||
        jobTitle.contains('職人') ||
        jobTitle.contains('マイスター') ||
        jobTitle.contains('創造') ||
        jobTitle.contains('吟遊')) return Icons.palette;
    if (jobTitle.contains('商') ||
        jobTitle.contains('富豪') ||
        jobTitle.contains('君主')) return Icons.store;
    if (jobTitle.contains('機工') || jobTitle.contains('錬金'))
      return Icons.science;
    if (jobTitle.contains('暗殺') || jobTitle.contains('修道'))
      return Icons.sports_martial_arts;
    if (jobTitle.contains('グランド')) return Icons.workspace_premium;

    return Icons.work_outline;
  }

  // ▼▼▼ 全ジョブの定義リスト (ストーリーを追加) ▼▼▼
  static const List<JobDefinition> allJobs = [
    // --- 見習い ---
    JobDefinition(
      id: 'apprentice',
      title: '見習い',
      rank: 'Apprentice',
      description: '無限の可能性を秘めた、冒険の初心者。',
      story:
          '全ての英雄はここから始まった。まだ何者でもない君だが、その瞳には希望の光が宿っている。日々の小さな努力が、やがて世界を変える力となることを、君はまだ知らない。',
      requiredStats: {},
      requiredLevel: 1,
    ),

    // --- 初級職 (Novice) : Lv.2以上 ---
    JobDefinition(
      id: 'warrior',
      title: '戦士',
      rank: 'Novice',
      description: '己の肉体を武器とする、力強き闘士。',
      story:
          '「筋肉は裏切らない」。その信念のもと、汗と努力で鋼の肉体を手に入れた者。日々のトレーニングという名の戦場を駆け抜け、昨日の自分に打ち勝つ強さを持つ。',
      requiredStats: {'Physical': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'mage',
      title: '魔術師',
      rank: 'Novice',
      description: '知識を魔力へと変える、賢き探求者。',
      story:
          '本を開けば、そこは別世界への入り口だ。学びによって得た知識は、現実世界を変える魔法となる。知的好奇心の炎を絶やすことなく、真理を追い求める者の姿がそこにある。',
      requiredStats: {'Study': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'cleric',
      title: '治癒士',
      rank: 'Novice',
      description: '安らぎと癒やしをもたらす、心の守り手。',
      story:
          '混沌とした世界において、自身の心を整えることは最大の防衛術である。瞑想や内省を通じて内なる静寂を手に入れた君は、その穏やかなオーラで周囲の人々さえも癒やしていく。',
      requiredStats: {'Mental': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'hunter',
      title: '狩人',
      rank: 'Novice',
      description: '規則正しい生活で獲物を狙う、生活の達人。',
      story:
          '早起きは三文の得、整理整頓は勝利への布石。生活リズムという名の弓矢を研ぎ澄まし、乱れた日常を狩り尽くす。丁寧な暮らしこそが、最強の生存戦略であることを知っている。',
      requiredStats: {'Life': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'merchant',
      title: '商人',
      rank: 'Novice',
      description: '言葉と笑顔で価値を生む、交流のプロ。',
      story:
          '人と人との繋がりこそが、最大の財産だ。挨拶ひとつ、会話ひとつで信頼を築き上げ、社会という大海原を渡っていく。君の周りにはいつも笑顔とチャンスが溢れている。',
      requiredStats: {'Social': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'crafter',
      title: '職人',
      rank: 'Novice',
      description: '無から有を生み出す、創造の担い手。',
      story:
          '頭の中に描いたイメージを、現実世界に具現化する喜び。試行錯誤の末に生まれた作品は、君の魂の欠片だ。作る楽しさを知った君の手は、魔法使いの杖よりも雄弁に語る。',
      requiredStats: {'Creative': 5},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'spellblade',
      title: '魔法剣士',
      rank: 'Novice',
      description: '剣技と魔法を操る、文武両道の勇者。',
      story:
          'ペンと剣、どちらか一つ選ぶ必要などない。身体を鍛えながら知性も磨く、欲張りで完璧主義な君にふさわしいジョブ。バランスの取れた努力は、どんな局面でも君を支える力となる。',
      requiredStats: {'Physical': 3, 'Study': 3},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'bard',
      title: '吟遊詩人',
      rank: 'Novice',
      description: '世界を旅し歌う、自由な表現者。',
      story:
          '君の言葉、君の作品は、誰かの心を動かす力を持っている。社会と関わりながら自己表現を続ける君は、退屈な日常に彩りを与えるアーティストだ。響かせろ、魂の歌を！',
      requiredStats: {'Social': 3, 'Creative': 3},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'monk',
      title: '修道士',
      rank: 'Novice',
      description: '鋼の肉体に不動の心を宿す求道者。',
      story:
          '厳しい鍛錬の末に辿り着く、心身統一の境地。肉体の限界に挑むことで精神も研ぎ澄まされていく。己の弱さと向き合い続ける君の拳は、迷いを打ち砕く一撃となる。',
      requiredStats: {'Physical': 3, 'Mental': 3},
      requiredLevel: 2,
    ),
    JobDefinition(
      id: 'adventurer',
      title: '冒険家',
      rank: 'Novice',
      description: '未知なる世界へ挑む、自由な魂。',
      story:
          '健康な身体と整った生活基盤があれば、どこへだって行ける。日常の枠を飛び出し、新しい体験を求めて突き進む君の背中は、多くの人に勇気を与えるだろう。',
      requiredStats: {'Life': 3, 'Physical': 3},
      requiredLevel: 2,
    ),

    // --- 中級職 (Intermediate) : Lv.20以上 ---
    JobDefinition(
      id: 'knight',
      title: '騎士',
      rank: 'Intermediate',
      description: '揺るぎない信念と鋼の肉体を持つ守護者。',
      story:
          '継続は力なり。長期間の鍛錬により、君の努力は確固たる実力へと昇華した。その強靭な肉体と精神は、大切な人を守る盾となり、正義を貫く剣となる。誰もが認める実力者。',
      requiredStats: {'Physical': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'wizard',
      title: 'ウィザード',
      rank: 'Intermediate',
      description: '深淵なる知識の海を渡る、大賢者の卵。',
      story:
          '一つの分野を極めようとする君の知識量は、もはや常人の域を超えつつある。難解な理論も、君にとってはパズルのようなもの。知識の塔を登り続ける君に、見えぬものはない。',
      requiredStats: {'Study': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'bishop',
      title: '司教',
      rank: 'Intermediate',
      description: '迷える人々を導く、強靭な精神の支柱。',
      story:
          'あらゆるストレスや苦難を受け流し、常に平穏を保つことができる聖職者。その悟りの境地は、周囲の人々に安心感を与え、精神的な支えとなる。メンタルコントロールの達人。',
      requiredStats: {'Mental': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'ranger',
      title: 'レンジャー',
      rank: 'Intermediate',
      description: 'あらゆる環境に適応し生き抜く、生活の達人。',
      story:
          '早寝早起き、栄養管理、タスク処理。君の生活スキルは芸術の域に達している。どんな過酷な状況でも、君なら快適な「日常」を作り出せるだろう。生存能力のエキスパート。',
      requiredStats: {'Life': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'tycoon',
      title: '大富豪',
      rank: 'Intermediate',
      description: '人を惹きつけ富を築く、カリスマリーダー。',
      story:
          '広大な人脈と巧みな交渉術を持つ君は、社会というゲームの支配者だ。人々は君の魅力に惹かれ、自然と協力者が集まってくる。信頼という名の富を無限に生み出す錬金術師。',
      requiredStats: {'Social': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'meister',
      title: 'マイスター',
      rank: 'Intermediate',
      description: '神業のごとき技術を持つ、至高の職人。',
      story:
          '「神は細部に宿る」。その言葉を体現するかのように、君の作品は魂を震わせる完成度を誇る。妥協なきこだわりと積み重ねた技術が、君を唯一無二の存在へと押し上げた。',
      requiredStats: {'Creative': 20},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'alchemist',
      title: '錬金術師',
      rank: 'Intermediate',
      description: '理論と創造で常識を覆す、奇跡の発明家。',
      story:
          '膨大な知識と奔放なアイデアの融合。君の頭脳は、この世にない新しい価値を生み出す工場だ。「ありえない」を「ありえる」に変えるその力で、世界を驚かせ続けろ。',
      requiredStats: {'Study': 15, 'Creative': 15},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'paladin',
      title: 'パラディン',
      rank: 'Intermediate',
      description: '聖なる力と武力を兼ね備えた、不滅の聖騎士。',
      story:
          '健全なる精神は健全なる肉体に宿る。心身ともに極限まで鍛え上げられた君は、もはや弱点など存在しない完全無欠の超人だ。その輝きは、闇を払う希望の光となる。',
      requiredStats: {'Physical': 15, 'Mental': 15},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'assassin',
      title: '暗殺者',
      rank: 'Intermediate',
      description: '音もなく課題を処理する、影の仕事人。',
      story:
          '卓越した身体能力と独創的な発想で、どんな難題も瞬時に解決する。君の努力は誰にも気づかれないかもしれないが、その成果は誰の目にも明らかだ。クールでスタイリッシュな実力者。',
      requiredStats: {'Physical': 15, 'Creative': 15},
      requiredLevel: 20,
    ),
    JobDefinition(
      id: 'sage',
      title: '賢者',
      rank: 'Intermediate',
      description: '森羅万象を理解し、人生を達観した知恵者。',
      story:
          '知識、精神、そして生活。全てが調和した君は、人生という迷宮の地図を持っているかのようだ。悩める人々に進むべき道を示す、現代の賢者。',
      requiredStats: {'Study': 15, 'Mental': 15},
      requiredLevel: 20,
    ),

    // --- 上級職 (Advanced) : Lv.50以上 ---
    JobDefinition(
      id: 'sword_saint',
      title: '剣聖',
      rank: 'Advanced',
      description: '武の極致に達した、伝説の戦士。',
      story:
          'もはや君の肉体は凶器であり、芸術だ。一振りで山を断つような圧倒的な努力の蓄積が、君を武の頂点へと押し上げた。歴史に名を残す、生ける伝説。',
      requiredStats: {'Physical': 50},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'grand_magus',
      title: '大魔導士',
      rank: 'Advanced',
      description: '世界の理（ことわり）を書き換える、魔法の深淵。',
      story:
          '君の知識は図書館一つ分を優に超える。知の探求の果てに辿り着いた境地で、君は新たな真理すら創造する。その叡智に、世界中の学者がひれ伏すだろう。',
      requiredStats: {'Study': 50},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'saint',
      title: '聖人',
      rank: 'Advanced',
      description: '神の如き慈愛で世界を包む、精神の頂。',
      story:
          '君の存在そのものが、周囲に安らぎと浄化をもたらす。怒りや悲しみを慈愛へと変えるその心は、もはや人の領域を超えているのかもしれない。現人神と崇められる存在。',
      requiredStats: {'Mental': 50},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'monarch',
      title: '君主',
      rank: 'Advanced',
      description: '時代を動かし、人々を導く絶対的王者。',
      story:
          '君の一言が世界を動かす。圧倒的なカリスマ性と統率力で、多くの人々を理想郷へと導く指導者。君の歩む道こそが、新たな時代の王道となる。',
      requiredStats: {'Social': 50},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'creator',
      title: '創造神',
      rank: 'Advanced',
      description: '無から有を生み出す、神域の芸術家。',
      story:
          '君の想像力に限界はない。君が生み出す作品やアイデアは、世界に新たな色を与え、文化そのものを創り変える。破壊と創造を司る、クリエイティブの神。',
      requiredStats: {'Creative': 50},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'hero',
      title: '勇者',
      rank: 'Advanced',
      description: '勇気と力で希望を紡ぐ、選ばれし者。',
      story:
          '強き肉体、不屈の精神、そして人々を愛する心。全てを兼ね備えた君は、まさに物語の主人公だ。どんな絶望的な状況でも、君がいれば希望は決して消えない。',
      requiredStats: {'Physical': 40, 'Mental': 40, 'Social': 40},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'hermit',
      title: '仙人',
      rank: 'Advanced',
      description: '俗世を離れ、真理と一体化した超越者。',
      story: '完璧な生活リズムと深い知識、そして悟りの心。霞を食べて生きる仙人のように、君はあらゆる執着から解放され、真の自由を手に入れた。',
      requiredStats: {'Life': 40, 'Mental': 40, 'Study': 40},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'machinist',
      title: '機工士',
      rank: 'Advanced',
      description: '科学と魔法を融合させる、未来の開拓者。',
      story:
          '知性と創造性、そしてそれを実現する体力。君の手にかかれば、空飛ぶ船も不老不死の薬も夢物語ではない。テクノロジーと魔法の融合で、人類を次のステージへ導く者。',
      requiredStats: {'Study': 40, 'Creative': 40, 'Physical': 40},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'valkyrie',
      title: 'ヴァルキリー',
      rank: 'Advanced',
      description: '戦場を舞う美しき戦乙女。',
      story:
          '美しく、強く、そして気高い。戦場（日常）を華麗に駆け抜け、タスクを薙ぎ払うその姿は、見る者すべてを魅了する。勝利の女神に愛された、戦うアイドル。',
      requiredStats: {'Physical': 40, 'Social': 40, 'Life': 40},
      requiredLevel: 50,
    ),
    JobDefinition(
      id: 'grandmaster',
      title: 'グランドマスター',
      rank: 'Advanced',
      description: '全ての道を極めし、万能にして最強の超人。',
      story:
          'これぞ努力の結晶、進化の到達点。全てのステータスが高次元で融合し、弱点など微塵も存在しない。君はもはや、一つの「職業」という枠には収まらない存在だ。',
      requiredStats: {
        'Life': 30,
        'Study': 30,
        'Physical': 30,
        'Social': 30,
        'Creative': 30,
        'Mental': 30
      },
      requiredLevel: 50,
    ),
  ];

  static List<JobDefinition> getUnlockedJobs(UserStats stats, int level) {
    return allJobs.where((job) {
      // レベル条件
      if (level < job.requiredLevel) return false;

      // ステータス条件
      for (var entry in job.requiredStats.entries) {
        final statName = entry.key;
        final requiredValue = entry.value;

        int currentValue = 0;
        switch (statName) {
          case 'Life':
            currentValue = stats.life;
            break;
          case 'Study':
            currentValue = stats.study;
            break;
          case 'Physical':
            currentValue = stats.physical;
            break;
          case 'Social':
            currentValue = stats.social;
            break;
          case 'Creative':
            currentValue = stats.creative;
            break;
          case 'Mental':
            currentValue = stats.mental;
            break;
        }

        if (currentValue < requiredValue) return false;
      }

      return true;
    }).toList();
  }

  // 互換性維持
  static JobResult computeJob(UserStats stats, int level) {
    return JobResult(title: "見習い");
  }
}

int computeLevel(int xp) => Progression.getLevel(xp);
JobResult computeJob(UserStats stats, int level) =>
    Progression.computeJob(stats, level);
Map<String, int> computeXpProgress(int xp) => Progression.getXpProgress(xp);
