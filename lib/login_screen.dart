// lib/login_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart'; // ◀◀◀ AppBarと同じフォントを使うためにインポート

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Googleログイン処理
  Future<void> _signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // Firebaseにログイン情報を渡す
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ UIをダークテーマに合わせて全面的に修正 ▼▼▼
    return Scaffold(
      // 背景色をテーマのスカフォールド背景色（黒）に設定
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // タイトル (AppBarと同じフォントと色)
              Text(
                'MiniQuest',
                style: GoogleFonts.orbitron(
                  textStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary, // 炎色
                      ),
                ),
              ),
              const SizedBox(height: 12),
              // サブタイトル (白)
              Text(
                '日常を、冒険に。',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[300], // 少し落ち着いた白
                    ),
              ),
              const SizedBox(height: 64),
              // Googleログインボタン (炎色)
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.login), // Googleアイコンより汎用的なログイン
                label: const Text('Googleでログイン'),
                style: ElevatedButton.styleFrom(
                  // ボタンの背景色を炎色に
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  // ボタンの文字色を白に
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // 角を丸くする
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // ▲▲▲
  }
}
