// lib/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'main.dart';
// import 'avatar_creation_screen.dart'; // ◀◀◀ 削除
import 'account_name_screen.dart';
import 'initial_profile_setup_screen.dart'; // ◀◀◀ 新しい画面をインポート

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 1. ドキュメント自体が存在しない場合
            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              return const AccountNameScreen();
            }

            final data = userDocSnapshot.data!.data() as Map<String, dynamic>;

            // 2. accountName がない場合
            if (!data.containsKey('accountName') ||
                data['accountName'] == null) {
              return const AccountNameScreen();
            }

            // ▼▼▼ 'avatar' のチェックを 'bio' のチェックに変更 ▼▼▼
            // 2b. bio (自己紹介) がない場合
            if (!data.containsKey('bio') || data['bio'] == null) {
              return const InitialProfileSetupScreen(); // ◀◀◀ 遷移先を変更
            }
            // ▲▲▲

            // 3. すべて揃っている場合
            return const HomeScreen();
          },
        );
      },
    );
  }
}
