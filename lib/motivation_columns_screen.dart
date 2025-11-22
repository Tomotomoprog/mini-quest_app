// lib/motivation_columns_screen.dart
import 'package:flutter/material.dart';

class MotivationColumnsScreen extends StatelessWidget {
  const MotivationColumnsScreen({super.key});

  // コラムごとに割り当てるアクセントカラーのリスト
  static final List<Color> _cardColors = [
    Colors.redAccent.shade200,
    Colors.orangeAccent.shade200,
    Colors.amberAccent.shade200,
    Colors.greenAccent.shade200,
    Colors.tealAccent.shade200,
    Colors.cyanAccent.shade200,
    Colors.blueAccent.shade200,
    Colors.indigoAccent.shade200,
    Colors.purpleAccent.shade200,
    Colors.pinkAccent.shade200,
  ];

  final List<Map<String, String>> columns = const [
    {
      'title': '1. 「やる気」を待ってはいけない',
      'content':
          '「やる気が出たらやろう」と思っていませんか？実は脳科学的には順序が逆です。\n\n「行動するから、やる気が出る（作業興奮）」のです。\n\nやる気が0でも、とりあえず靴を履く、1行だけ書く、1回だけスクワットをする。体を動かし始めれば、脳は後からついてきます。モチベーションは、行動した後に得られるご褒美なのです。'
    },
    {
      'title': '2. 魔法の「2分ルール」',
      'content':
          '新しい習慣を始めるときは、「2分以内にできること」までハードルを下げてください。\n\n「30分ランニングする」ではなく「ランニングシューズを履く」。「勉強する」ではなく「ノートを開く」。\n\nこれならどんなに疲れていてもできます。まずは「始めること」を習慣にし、定着してから量を増やしましょう。0を1にすることが、最もエネルギーを使う偉大な一歩です。'
    },
    {
      'title': '3. 3日坊主でも大丈夫',
      'content':
          '1日サボってしまっても、自己嫌悪に陥る必要はありません。完璧な人間などいないからです。\n\n重要なのは「一度も途切れさせないこと」ではなく、「途切れた後にすぐに復帰すること」です。\n\n「2回連続でサボらない（Never Miss Twice）」というルールを設けましょう。今日休んだなら、明日は必ず5分だけやる。そのリカバリーこそが、プロフェッショナルとアマチュアの差です。'
    },
    {
      'title': '4. 成長は「曲線」を描く',
      'content':
          '努力の成果は、すぐには目に見えません。多くの人は努力と成果が比例すると考えますが、実際は「潜伏期間（プラトー）」があります。\n\n氷点下から温度を上げても、0℃になるまでは氷は溶けません。しかし、エネルギーは確実に蓄積されています。\n\n今、成果が出ていないとしても、それは無駄ではなく「エネルギーを溜めている期間」です。爆発的な成長は、諦めずに続けた先に必ず待っています。'
    },
    {
      'title': '5. 目標ではなく「仕組み」に恋をする',
      'content':
          '「10kg痩せる」「資格を取る」という目標は方向性を示してくれますが、実際にあなたを変えるのは日々の「システム（仕組み）」です。\n\n目標達成そのものではなく、「毎日健康的な食事を選ぶ自分」「毎日机に向かう自分」というプロセスそのものを愛してください。\n\n結果はコントロールできませんが、行動はコントロールできます。優れたシステムを作れば、結果は自然とついてきます。'
    },
    {
      'title': '6. 環境が意志力に勝る',
      'content':
          '人間の意志力は消耗品であり、夕方には枯渇します。強い意志を持とうとするより、環境を変える方が遥かに簡単で効果的です。\n\n勉強したいならスマホを別の部屋に置く。運動したいなら前日にウェアを枕元に置く。お菓子を食べたくないなら買わない。\n\n悪い習慣のきっかけを遠ざけ、良い習慣のきっかけを目に見える場所に置く（トリガーの可視化）。環境をデザインすることが、習慣化の近道です。'
    },
    {
      'title': '7. 失敗は「データ収集」',
      'content':
          '習慣が続かなかったとき、「自分は意志が弱いダメな人間だ」と自分を責めてはいけません。それは単に「そのやり方が合わなかった」というデータが得られただけです。\n\n「なぜ続かなかったのか？」「時間がなかった？」「場所が悪かった？」「ハードルが高すぎた？」\n\n失敗を分析し、次はどうすればできるかを実験する。科学者のような視点で、自分に合った方法を模索し続けましょう。'
    },
    {
      'title': '8. アイデンティティを変える',
      'content':
          '行動を変える最も強力な方法は、セルフイメージ（自分が思う自分）を変えることです。\n\n「タバコをやめようとしている人」ではなく「タバコを吸わない人」になる。「走ろうとしている人」ではなく「ランナー」になる。\n\n「私は〇〇な人間だ」と信じることで、行動は自然とそれに追随します。日々の小さな行動の積み重ねが、その新しいアイデンティティへの投票となります。'
    },
    {
      'title': '9. 誰かと一緒にやる力',
      'content':
          '一人で黙々と努力するのは困難です。人間は社会的な生き物であり、他者の目があるだけでパフォーマンスが向上します。\n\nMiniQuestのフレンド機能を使って、進捗を共有しましょう。応援し合い、時には競い合うことで、モチベーションは維持されやすくなります。「約束」や「監視」の力をポジティブに利用しましょう。一人では行けない場所も、仲間となら辿り着けます。'
    },
    {
      'title': '10. 自分に優しくあれ',
      'content':
          '自分に厳しくしすぎると、ストレスで逆に悪い習慣に走ってしまうことがあります（どうにでもなれ効果）。\n\nうまくいかない時こそ、親友に接するように自分自身に優しく声をかけてください。「今日は疲れていたね、よく休んで明日また頑張ろう」。\n\nセルフ・コンパッション（自分への慈しみ）を持つ人の方が、挫折からの回復が早く、長く努力を続けられることが研究で分かっています。'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // ダーク背景
      appBar: AppBar(
        title: const Text(
          '冒険の書',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: columns.length,
        itemBuilder: (context, index) {
          final item = columns[index];
          // 色を順番に割り当てる
          final color = _cardColors[index % _cardColors.length];

          return _ColumnCard(
            title: item['title']!,
            content: item['content']!,
            color: color,
          );
        },
      ),
    );
  }
}

class _ColumnCard extends StatelessWidget {
  final String title;
  final String content;
  final Color color;

  const _ColumnCard({
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // カード背景（少し明るい黒）
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // 展開時の区切り線を消す
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // ▼ タイトル部分のデザイン ▼
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          // 閉じた状態のアイコン色
          collapsedIconColor: Colors.grey,
          // 開いた状態のアイコン色
          iconColor: color,

          // ▼ 展開部分のデザイン ▼
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            // アクセントライン
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 2,
              width: 40,
              color: color.withOpacity(0.5),
            ),
            Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.8, // 行間を広げて読みやすく
                color: Color(0xFFE0E0E0), // 完全な白ではなく少し抑えた色
              ),
            ),
          ],
        ),
      ),
    );
  }
}
