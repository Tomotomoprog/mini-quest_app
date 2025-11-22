// lib/main.dart
import 'dart:io';
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
import 'utils/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await LocalNotificationService.init();
  await LocalNotificationService.scheduleDailyNotification();

  try {
    final messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          for (int i = 0; i < 3; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
      }
      String? token = await messaging.getToken();
      await _saveTokenToFirestore(token);
    }
  } catch (e) {
    print('通知設定のエラー: $e');
  }

  runApp(const MyApp());
}

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
    } catch (e) {
      print('FCMトークン保存エラー: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryAccent = Colors.deepOrange;
    final Color backgroundColor = Colors.black;
    final Color surfaceColor = Colors.grey[900]!;
    final Color primaryTextColor = Colors.white;
    final Color secondaryTextColor = Colors.grey[400]!;

    final baseTheme = ThemeData(brightness: Brightness.dark);
    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
      bodyColor: primaryTextColor,
      displayColor: primaryTextColor,
    );

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // ▼▼▼ 修正: フラグ受け渡しを削除しシンプルに ▼▼▼
  final List<Widget> _widgetOptions = [
    const MyQuestsScreen(),
    const TimelineScreen(),
    const ExploreQuestsScreen(),
    const FriendsScreen(),
    // ProfileScreen は initState で設定する必要があるためここでは仮置き
    const SizedBox(),
  ];
  // ▲▲▲

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // ユーザーIDが取得できるまで待つ
    if (currentUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ProfileScreen だけは userId が必要なのでここで生成
    final List<Widget> screens = [
      const MyQuestsScreen(),
      const TimelineScreen(),
      const ExploreQuestsScreen(),
      const FriendsScreen(),
      ProfileScreen(userId: currentUserId),
    ];

    return Scaffold(
      body: Center(child: screens.elementAt(_selectedIndex)),
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
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
