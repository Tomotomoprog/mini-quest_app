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
  final String? accountName;
  final String? bio;
  // ▼▼▼ 追加: キャラクターアバターの画像パス ▼▼▼
  final String? characterImage;
  // ▲▲▲
  final int xp;
  final UserStats stats;
  final Avatar? avatar;
  final Map<String, String> equippedItems;
  final double totalEffortHours;
  final int currentStreak;
  final int longestStreak;
  final Timestamp? lastPostDate;
  final String? title;

  UserProfile({
    required this.uid,
    this.displayName,
    this.photoURL,
    this.accountName,
    this.bio,
    // ▼▼▼ 追加 ▼▼▼
    this.characterImage,
    // ▲▲▲
    required this.xp,
    required this.stats,
    this.avatar,
    required this.equippedItems,
    required this.totalEffortHours,
    required this.currentStreak,
    required this.longestStreak,
    this.lastPostDate,
    this.title,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    double hours = 0.0;
    if (data['totalEffortHours'] != null) {
      if (data['totalEffortHours'] is int) {
        hours = (data['totalEffortHours'] as int).toDouble();
      } else if (data['totalEffortHours'] is double) {
        hours = data['totalEffortHours'] as double;
      }
    }

    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      accountName: data['accountName'],
      bio: data['bio'],
      // ▼▼▼ 追加 ▼▼▼
      characterImage: data['characterImage'],
      // ▲▲▲
      xp: data['xp'] ?? 0,
      stats: UserStats.fromMap(data['stats'] ?? {}),
      avatar:
          data.containsKey('avatar') ? Avatar.fromMap(data['avatar']) : null,
      equippedItems: Map<String, String>.from(data['equippedItems'] ?? {}),
      totalEffortHours: hours,
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastPostDate: data['lastPostDate'],
      title: data['title'],
    );
  }
}
