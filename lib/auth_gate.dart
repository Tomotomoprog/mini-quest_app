import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'main.dart';
import 'avatar_creation_screen.dart'; // アバター作成画面をインポート

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ユーザーがログインしていない場合
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // ユーザーがログインしている場合
        final user = snapshot.data!;

        // ユーザーのアバター情報があるかFirestoreをチェックする
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userDocSnapshot) {
            // データ読み込み中
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ユーザーデータが存在し、'avatar'フィールドも存在する場合
            if (userDocSnapshot.hasData &&
                userDocSnapshot.data!.exists &&
                (userDocSnapshot.data!.data() as Map).containsKey('avatar')) {
              // ホーム画面へ
              return const HomeScreen();
            } else {
              // アバターが未作成ならアバター作成画面へ
              return const AvatarCreationScreen();
            }
          },
        );
      },
    );
  }
}
