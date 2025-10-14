import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/user_profile.dart';
import 'utils/progression.dart';
import 'artisan_workshop_screen.dart'; // 工房画面をインポート

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
      body: StreamBuilder<DocumentSnapshot>(
        // FutureBuilderからStreamBuilderに変更
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
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
            return _SanctuaryUnlockedView(userLevel: level);
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
  final int userLevel;
  const _SanctuaryUnlockedView({required this.userLevel});

  @override
  Widget build(BuildContext context) {
    // 設計案に基づき、各建物の解放レベルを定義
    const workshopUnlockLevel = 15;

    // 職人の工房が解放されているか
    final isWorkshopUnlocked = userLevel >= workshopUnlockLevel;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        // 建物が増えてもスクロールできるようにListViewに変更
        children: [
          const Text(
            'あなたの街を発展させましょう',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ▼▼▼ 職人の工房カードを追加 ▼▼▼
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isWorkshopUnlocked
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) =>
                                const ArtisanWorkshopScreen()),
                      );
                    }
                  : null, // ロック中はタップ不可
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      isWorkshopUnlocked ? Icons.construction : Icons.lock,
                      size: 40,
                      color: isWorkshopUnlocked
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '職人の工房',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            isWorkshopUnlocked
                                ? '装備品（スキン）を作成できます'
                                : 'レベル$workshopUnlockLevelで解放',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ▲▲▲ 職人の工房カードを追加 ▲▲▲

          // TODO: 他の建物のカードもここに追加していく
        ],
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
