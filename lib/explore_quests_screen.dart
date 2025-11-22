// lib/explore_quests_screen.dart
import 'package:flutter/material.dart';
import 'category_quest_list_screen.dart';

class ExploreQuestsScreen extends StatelessWidget {
  const ExploreQuestsScreen({super.key});

  // カテゴリ定義 (色をアクセントカラーに変更)
  static final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Life',
      'jpName': '生活',
      'icon': Icons.home_outlined,
      'color': Colors.greenAccent.shade400,
    },
    {
      'name': 'Study',
      'jpName': '学習',
      'icon': Icons.school_outlined,
      'color': Colors.cyanAccent.shade400,
    },
    {
      'name': 'Physical',
      'jpName': '身体',
      'icon': Icons.fitness_center_outlined,
      'color': Colors.redAccent.shade400,
    },
    {
      'name': 'Social',
      'jpName': '社会',
      'icon': Icons.people_outline,
      'color': Colors.pinkAccent.shade400,
    },
    {
      'name': 'Creative',
      'jpName': '創造',
      'icon': Icons.palette_outlined,
      'color': Colors.purpleAccent.shade400,
    },
    {
      'name': 'Mental',
      'jpName': '精神',
      'icon': Icons.self_improvement_outlined,
      'color': Colors.indigoAccent.shade400,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景色を少しリッチなダークカラーに
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('MiniQuest'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXPLORE',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'クエストを探す',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2列
                crossAxisSpacing: 16, // 横スペース
                mainAxisSpacing: 16, // 縦スペース
                childAspectRatio: 0.85, // 少し縦長にしてスタイリッシュに
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return _ModernCategoryCard(
                  name: category['name'],
                  jpName: category['jpName'],
                  icon: category['icon'],
                  color: category['color'],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CategoryQuestListScreen(
                          categoryName: category['name'],
                          categoryColor: category['color'],
                          categoryIcon: category['icon'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// デザインを一新したカテゴリカード
class _ModernCategoryCard extends StatelessWidget {
  final String name;
  final String jpName;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModernCategoryCard({
    required this.name,
    required this.jpName,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            // ダークなグラデーション背景
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2C2C2E),
                const Color(0xFF1C1C1E),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            // 枠線をうっすら光らせる
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // ほんのり色のグロー効果
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 背景の巨大アイコン（ウォーターマーク演出）
              Positioned(
                right: -20,
                bottom: -20,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    icon,
                    size: 120,
                    color: color.withOpacity(0.08), // 非常に薄く表示
                  ),
                ),
              ),

              // メインコンテンツ
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // アイコンコンテナ
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    // 英語名
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900, // かなり太く
                        letterSpacing: 1.2,
                        color: Colors.white,
                        fontFamily: 'Roboto', // 幾何学的なフォントがおすすめ
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 日本語名
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 2,
                          color: color, // アクセントライン
                        ),
                        const SizedBox(width: 8),
                        Text(
                          jpName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
