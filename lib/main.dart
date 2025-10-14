import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'friends_screen.dart';
import 'models/quest.dart';
import 'my_quests_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'utils/quest_service.dart';

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
    final seedColor = const Color(0xFF0EA5E9);
    final textTheme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return MaterialApp(
      title: 'MiniQuest',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor, background: const Color(0xFFF8FAFC)),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFFFFFFF).withOpacity(0.8),
          foregroundColor: const Color(0xFF0f172a),
          elevation: 0,
          titleTextStyle:
              textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.orange,
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
      appBar: AppBar(title: const Text('今日のクエスト')),
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
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: quests.length,
            itemBuilder: (context, index) {
              final quest = quests[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${quest.tag}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(quest.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(quest.description,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) =>
                                  PostScreen(dailyQuest: quest)));
                        },
                        child: const Text('達成を投稿'),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
