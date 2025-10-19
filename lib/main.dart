import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // スペースを追加
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // スペースを追加
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'friends_screen.dart'; // スペースを追加
import 'models/quest.dart';
import 'my_quests_screen.dart';
import 'post_screen.dart'; // PostScreenをインポート
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'utils/quest_service.dart';
// growth_path_screen.dart は main.dart では不要

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF0EA5E9);
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return MaterialApp(
      title: 'MiniQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlue, background: const Color(0xFFF8FAFC)),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor:
              const Color(0xFFFFFFFF).withOpacity(0.8), // デフォルトのAppBar背景色
          foregroundColor: const Color(0xFF0f172a),
          elevation: 0,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryBlue, // AppBarタイトルはこの色に統一
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: primaryBlue,
          selectedLabelStyle: TextStyle(fontSize: 12.0),
          unselectedLabelStyle: TextStyle(fontSize: 12.0),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Widget> _widgetOptions = [];

  @override
  void initState() {
    super.initState();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _widgetOptions = <Widget>[
        const QuestListScreen(),
        const TimelineScreen(),
        const MyQuestsScreen(),
        const FriendsScreen(),
        ProfileScreen(userId: currentUserId),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_widgetOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'タイムライン'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'マイクエスト'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'フレンド'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class QuestListScreen extends StatefulWidget {
  const QuestListScreen({super.key});
  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  late Future<List<Quest>> _dailyQuestsFuture;

  @override
  void initState() {
    super.initState();
    _dailyQuestsFuture = QuestService.getDailyQuests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('MiniQuest'),
        backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.8),
      ),
      body: FutureBuilder<List<Quest>>(
        future: _dailyQuestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('クエストの取得に失敗しました'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('今日のクエストはありません'));
          }
          final quests = snapshot.data!;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日のクエスト',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '「日常を冒険に」毎日更新される三つのクエストに挑戦し、写真を撮ってみんなと共有しよう！',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  itemCount: quests.length,
                  itemBuilder: (context, index) {
                    final quest = quests[index];
                    return _QuestCard(quest: quest);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Quest quest;
  const _QuestCard({required this.quest});

  static const Map<String, dynamic> _categoryDesigns = {
    'Life': {'icon': Icons.home_outlined, 'color': Colors.green},
    'Study': {'icon': Icons.school_outlined, 'color': Colors.blue},
    'Physical': {'icon': Icons.fitness_center_outlined, 'color': Colors.red},
    'Social': {'icon': Icons.people_outline, 'color': Colors.pink},
    'Creative': {'icon': Icons.palette_outlined, 'color': Colors.purple},
    'Mental': {'icon': Icons.self_improvement_outlined, 'color': Colors.indigo},
    'Default': {'icon': Icons.flag_outlined, 'color': Colors.grey},
  };

  @override
  Widget build(BuildContext context) {
    final design =
        _categoryDesigns[quest.category] ?? _categoryDesigns['Default']!;
    final color = design['color'] as Color;
    final icon = design['icon'] as IconData;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => PostScreen(dailyQuest: quest)));
        },
        child: Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color, width: 4)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.05), Colors.white],
              )),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  avatar: Icon(icon, color: color, size: 18),
                  label: Text(quest.tag),
                  backgroundColor: color.withOpacity(0.15),
                  side: BorderSide.none,
                ),
                const SizedBox(height: 12),
                Text(
                  quest.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
