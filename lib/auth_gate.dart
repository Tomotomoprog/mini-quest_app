// lib/auth_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'initial_profile_setup_screen.dart';
import 'login_screen.dart';
import 'main.dart';
import 'tutorial_screens.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. 認証状態のチェック
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // 2. ユーザーデータのチェック
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            // プロフィール未作成なら作成画面へ
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const InitialProfileSetupScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;

            // ▼▼▼ 修正: 完了フラグをチェックして振り分け ▼▼▼
            final bool isTutorialCompleted =
                userData['isTutorialCompleted'] ?? false;

            if (isTutorialCompleted) {
              return const HomeScreen();
            } else {
              return const TutorialSelectionScreen();
            }
            // ▲▲▲
          },
        );
      },
    );
  }
}
