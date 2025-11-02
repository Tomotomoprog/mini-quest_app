// lib/explore_quests_screen.dart
import 'package:flutter/material.dart';
import 'category_quest_list_screen.dart';

class ExploreQuestsScreen extends StatelessWidget {
  const ExploreQuestsScreen({super.key});

  // カテゴリの定義
  static final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Life',
      'icon': Icons.home_outlined,
      'color': Colors.green, // MaterialColor
    },
    {
      'name': 'Study',
      'icon': Icons.school_outlined,
      'color': Colors.blue, // MaterialColor
    },
    {
      'name': 'Physical',
      'icon': Icons.fitness_center_outlined,
      'color': Colors.red, // MaterialColor
    },
    {
      'name': 'Social',
      'icon': Icons.people_outline,
      'color': Colors.pink, // MaterialColor
    },
    {
      'name': 'Creative',
      'icon': Icons.palette_outlined,
      'color': Colors.purple, // MaterialColor
    },
    {
      'name': 'Mental',
      'icon': Icons.self_improvement_outlined,
      'color': Colors.indigo, // MaterialColor
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniQuest'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        // ▼▼▼ Column と Text 部分を削除し、GridView を直接配置 ▼▼▼
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2列
            crossAxisSpacing: 12, // 横のスペース
            mainAxisSpacing: 12, // 縦のスペース
            childAspectRatio: 1 / 1, // 縦横比を1:1 (正方形) に
          ),
          itemCount: _categories.length, // 6カテゴリ
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _CategoryCard(
              name: category['name'],
              icon: category['icon'],
              color: category['color'],
              onTap: () {
                // 新しい画面にカテゴリ名を渡して遷移
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
        // ▲▲▲
      ),
    );
  }
}

// カテゴリボタン用のウィジェット
class _CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                Colors.white,
              ],
            ),
            border: Border(
              top: BorderSide(color: color, width: 4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color.shade800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
