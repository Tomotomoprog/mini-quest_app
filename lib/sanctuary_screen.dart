import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';

class SanctuaryScreen extends StatelessWidget {
  const SanctuaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("ログインしてください"));

    return Scaffold(
      appBar: AppBar(
        title: const Text('サンクチュアリ'),
      ),
      // ユーザー情報を一度だけ取得するためにFutureBuilderを使用
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('ユーザー情報が見つかりません。'));
          }

          final userProfile = UserProfile.fromFirestore(snapshot.data!);
          final level = computeLevel(userProfile.xp);

          // レベル10以上かどうかで表示を切り替える
          if (level >= 10) {
            return const _SanctuaryUnlockedView();
          } else {
            return _SanctuaryLockedView(currentLevel: level);
          }
        },
      ),
    );
  }
}

// 機能が解放されている場合の表示
class _SanctuaryUnlockedView extends StatelessWidget {
  const _SanctuaryUnlockedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fort,
                size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'ようこそ、あなたのサンクチュアリへ',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'ここはあなたの努力で発展していく街です。\nこれから建物を建てて、機能を解放していきましょう！',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 機能がロックされている場合の表示
class _SanctuaryLockedView extends StatelessWidget {
  final int currentLevel;
  const _SanctuaryLockedView({required this.currentLevel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'サンクチュアリは\nレベル10で解放されます',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '現在のレベル: $currentLevel',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'クエストを達成してXPを貯め、レベル10を目指そう！',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
