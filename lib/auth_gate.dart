import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // これから作るログイン画面
import 'main.dart'; // 既存のホーム画面

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebaseの認証状態を監視する
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // まだ認証状態がわからない場合
        if (!snapshot.hasData) {
          return const LoginScreen(); // ログイン画面を表示
        }

        // ログイン済みの場合はホーム画面を表示
        return const HomeScreen();
      },
    );
  }
}