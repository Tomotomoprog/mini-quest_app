// lib/tutorial_screens.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart'; // HomeScreen

// 1. チュートリアルを見るか選択する画面
class TutorialSelectionScreen extends StatelessWidget {
  const TutorialSelectionScreen({super.key});

  Future<void> _completeTutorial(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 完了フラグを更新
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isTutorialCompleted': true});
    }

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueGrey.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_stories, size: 80, color: Colors.amber),
            const SizedBox(height: 32),
            const Text(
              'MiniQuestへようこそ！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              '努力を可視化し、人生をゲームのように楽しみましょう。\nアプリの使い方とメリットをご案内します。',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    // 最初に見る場合は isFirstTime: true
                    builder: (context) =>
                        const TutorialContentScreen(isFirstTime: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('チュートリアルを見る'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _completeTutorial(context),
              child: const Text(
                'スキップして始める',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. チュートリアル本編 (PageViewでスライド表示)
class TutorialContentScreen extends StatefulWidget {
  final bool isFirstTime; // 初回かどうか

  const TutorialContentScreen({
    super.key,
    this.isFirstTime = false,
  });

  @override
  State<TutorialContentScreen> createState() => _TutorialContentScreenState();
}

class _TutorialContentScreenState extends State<TutorialContentScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // スライドデータ
  final List<Map<String, dynamic>> _pages = [
    {
      'title': '努力をXPに変える',
      'description':
          '日々の小さな努力も、記録することで確実に積み上がります。\n\n「仕組み」で習慣化し、自分の成長を可視化しましょう。',
      'icon': Icons.star,
      'color': Colors.amber,
    },
    {
      'title': '🏴 マイクエスト',
      'description':
          '【目標管理と記録】\n\n達成したい目標（クエスト）を作成し、日々の進捗を記録します。\n\n「いつ・どこでやるか」を決めることで、継続率が劇的に向上します。',
      'icon': Icons.flag,
      'color': Colors.orange,
    },
    {
      'title': '⏳ タイムライン',
      'description':
          '【振り返りと応援】\n\n自分やフレンドの記録が流れます。\n\n過去の頑張りを振り返ったり、仲間に「応援（いいね）」を送ってモチベーションを高め合いましょう。',
      'icon': Icons.timeline,
      'color': Colors.blue,
    },
    {
      'title': '🧭 探す',
      'description':
          '【発見とヒント】\n\n他のユーザーがどんなクエストに挑戦しているか探せます。\n\nLife, Study, Physical... カテゴリごとに新しい目標のヒントを見つけましょう。',
      'icon': Icons.explore,
      'color': Colors.green,
    },
    {
      'title': '👥 フレンド',
      'description':
          '【協力と競争】\n\nフレンドと一緒にクエストに挑戦したり、努力量を競う「バトル」ができます。\n\n一人では続かないことも、仲間となら乗り越えられます。',
      'icon': Icons.people,
      'color': Colors.pink,
    },
    {
      'title': '👤 プロフィール',
      'description':
          '【成長の証】\n\n積み上げた努力が「ステータス」や「ジョブ」として反映されます。\n\n六角形グラフで自分の強みを知り、理想の自分へレベルアップしましょう！',
      'icon': Icons.person,
      'color': Colors.purple,
    },
  ];

  Future<void> _finishTutorial() async {
    // 初回の場合のみ完了フラグを更新してホームへ
    if (widget.isFirstTime) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'isTutorialCompleted': true});
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } else {
      // プロフィールから見た場合は単に戻る
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: !widget.isFirstTime
          ? AppBar(title: const Text('チュートリアル'), backgroundColor: Colors.black)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: (page['color'] as Color).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page['icon'],
                            size: 100,
                            color: page['color'],
                          ),
                        ),
                        const SizedBox(height: 60),
                        Text(
                          page['title'],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // インジケーターとボタン
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ページインジケーター
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        width: _currentPage == index ? 24 : 10, // 現在地を長くする
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),

                  // 次へ / 完了ボタン
                  if (_currentPage == _pages.length - 1)
                    ElevatedButton(
                      onPressed: _finishTutorial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: Text(widget.isFirstTime ? '始める' : '閉じる'),
                    )
                  else
                    TextButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('次へ', style: TextStyle(fontSize: 16)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
