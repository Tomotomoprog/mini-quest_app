import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'friends_screen.dart';
import 'my_quests_screen.dart';
import 'profile_screen.dart';
import 'timeline_screen.dart';
import 'explore_quests_screen.dart';
import 'utils/local_notification_service.dart'; // ▼ 追加

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ▼▼▼ ローカル通知の初期化とスケジュール設定 ▼▼▼
  await LocalNotificationService.init();
  await LocalNotificationService.scheduleDailyNotification();
  // ▲▲▲

  // ▼▼▼ プッシュ通知 (FCM) の設定 ▼▼▼
  try {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('ユーザーが通知を許可しました');
      String? token = await messaging.getToken();
      print('FCM Token: $token');
      await _saveTokenToFirestore(token);
    }
  } catch (e) {
    print('通知設定のエラー: $e');
  }
  // ▲▲▲

  runApp(const MyApp());
}

// (以下、_saveTokenToFirestore や MyApp クラスなどは変更なし)
Future<void> _saveTokenToFirestore(String? token) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('FCMトークンを保存しました');
    } catch (e) {
      print('FCMトークンの保存に失敗: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 色の定義
    final Color primaryAccent = Colors.deepOrange;
    final Color backgroundColor = Colors.black;
    final Color surfaceColor = Colors.grey[900]!;
    final Color primaryTextColor = Colors.white;
    final Color secondaryTextColor = Colors.grey[400]!;

    // 2. テキストテーマの定義
    final baseTheme = ThemeData(brightness: Brightness.dark);
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryAccent,
          brightness: Brightness.dark,
          background: backgroundColor,
          surface: surfaceColor,
          onBackground: primaryTextColor,
          onSurface: primaryTextColor,
          primary: primaryAccent,
          onPrimary: Colors.white,
          secondary: Colors.redAccent,
        ),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceColor.withOpacity(0.85),
          foregroundColor: primaryTextColor,
          elevation: 0,
          titleTextStyle: GoogleFonts.orbitron(
            textStyle: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: primaryAccent,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey[800]!),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surfaceColor,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryAccent,
          unselectedItemColor: secondaryTextColor,
          selectedLabelStyle: TextStyle(fontSize: 12.0),
          unselectedLabelStyle: TextStyle(fontSize: 12.0),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// (HomeScreenクラスも変更なし)
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
        const MyQuestsScreen(),
        const TimelineScreen(),
        const ExploreQuestsScreen(),
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
