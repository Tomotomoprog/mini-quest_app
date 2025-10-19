// lib/models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Avatar {
  final String hairStyle;
  final Color skinColor;
  final Color hairColor;

  Avatar({
    required this.hairStyle,
    required this.skinColor,
    required this.hairColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'hairStyle': hairStyle,
      'skinColor': skinColor.value,
      'hairColor': hairColor.value,
    };
  }

  factory Avatar.fromMap(Map<String, dynamic> map) {
    return Avatar(
      hairStyle: map['hairStyle'] ?? 'default',
      skinColor: Color(map['skinColor'] ?? Colors.orange.shade200.value),
      hairColor: Color(map['hairColor'] ?? Colors.brown.shade800.value),
    );
  }
}

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
  final UserStats stats;
  final Avatar? avatar;
  final Map<String, String> equippedItems;
  final int totalEffortMinutes;
  final int currentStreak; // ▼▼▼ 追加 ▼▼▼
  final int longestStreak; // ▼▼▼ 追加 ▼▼▼
  final String? title; // ▼▼▼ 追加 ▼▼▼

  UserProfile({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.xp,
    required this.stats,
    this.avatar,
    required this.equippedItems,
    required this.totalEffortMinutes,
    required this.currentStreak, // ▼▼▼ 追加 ▼▼▼
    required this.longestStreak, // ▼▼▼ 追加 ▼▼▼
    this.title, // ▼▼▼ 追加 ▼▼▼
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      xp: data['xp'] ?? 0,
      stats: UserStats.fromMap(data['stats'] ?? {}),
      avatar:
          data.containsKey('avatar') ? Avatar.fromMap(data['avatar']) : null,
      equippedItems: Map<String, String>.from(data['equippedItems'] ?? {}),
      totalEffortMinutes: data['totalEffortMinutes'] ?? 0,
      currentStreak: data['currentStreak'] ?? 0, // ▼▼▼ 追加 (デフォルト0) ▼▼▼
      longestStreak: data['longestStreak'] ?? 0, // ▼▼▼ 追加 (デフォルト0) ▼▼▼
      title: data['title'], // ▼▼▼ 追加 (null許容) ▼▼▼
    );
  }
}
