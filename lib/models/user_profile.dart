import 'package:cloud_firestore/cloud_firestore.dart';

// Webアプリの progression.ts を参考にしたUserStatsの型定義
class UserStats {
  final int life;
  final int study;
  final int physical;
  final int social;
  final int creative;
  final int mental;

  UserStats({
    this.life = 0,
    this.study = 0,
    this.physical = 0,
    this.social = 0,
    this.creative = 0,
    this.mental = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> data) {
    return UserStats(
      life: data['Life'] ?? 0,
      study: data['Study'] ?? 0,
      physical: data['Physical'] ?? 0,
      social: data['Social'] ?? 0,
      creative: data['Creative'] ?? 0,
      mental: data['Mental'] ?? 0,
    );
  }
}

class UserProfile {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final int xp;
  final UserStats stats; // 追加

  UserProfile({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.xp,
    required this.stats, // 追加
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      xp: data['xp'] ?? 0,
      stats: UserStats.fromMap(data['stats'] ?? {}), // 追加
    );
  }
}
