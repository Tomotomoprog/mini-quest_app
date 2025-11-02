import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Google Fonts
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'friends_screen.dart';
import 'my_quests_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'explore_quests_screen.dart'; // 「探す」タブ

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
    // 1. 色の定義
    final Color primaryAccent = Colors.deepOrange; // 炎のようなアクセント色
    final Color backgroundColor = Colors.black; // ベース背景
    final Color surfaceColor = Colors.grey[900]!; // カードやAppBarの背景色
    final Color primaryTextColor = Colors.white; // 通常の文字色
    final Color secondaryTextColor = Colors.grey[400]!; // やや暗い文字色

    // 2. テキストテーマの定義
    final baseTheme = ThemeData(brightness: Brightness.dark);
    // 全体の基本フォントは 'Inter' を維持
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
      bodyColor: primaryTextColor,
      displayColor: primaryTextColor,
    );

    // 3. MaterialAppに新しいテーマを適用
    return MaterialApp(
      title: 'MiniQuest',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,

        // 基本のカラー設定
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryAccent,
          brightness: Brightness.dark,
          background: backgroundColor,
          surface: surfaceColor, // カード、ダイアログ
          onBackground: primaryTextColor, // 黒背景上のテキスト
          onSurface: primaryTextColor, // カード上のテキスト
          primary: primaryAccent, // ボタン、アクティブ要素
          onPrimary: Colors.white, // ボタン上のテキスト
          secondary: Colors.redAccent, // サブのアクセント
        ),

        // テキストテーマ
        textTheme: textTheme,

        // AppBarのテーマ
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceColor.withOpacity(0.85), // AppBarの背景
          foregroundColor: primaryTextColor, // 戻る矢印など
          elevation: 0,
          // ▼▼▼ フォントサイズを 1.5倍 (displaySmall) に変更 ▼▼▼
          titleTextStyle: GoogleFonts.orbitron(
            textStyle: textTheme.displaySmall?.copyWith(
              // ◀◀◀ サイズ基準を変更
              fontWeight: FontWeight.bold,
              color: primaryAccent,
            ),
          ),
          // ▲▲▲
        ),

        // カードのテーマ
        cardTheme: CardThemeData(
          color: surfaceColor, // カード背景
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey[800]!), // カードの枠線
          ),
        ),

        // 下部ナビゲーションバーのテーマ
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surfaceColor, // ナビゲーションバーの背景
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryAccent, // 選択中のアイコンを炎色に
          unselectedItemColor: secondaryTextColor, // 非選択のアイコン
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
        const MyQuestsScreen(), // 1番目 (Index 0)
        const TimelineScreen(),
        const ExploreQuestsScreen(), // 3番目 (Index 2)
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
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'マイクエスト'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'タイムライン'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '探す'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'フレンド'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
