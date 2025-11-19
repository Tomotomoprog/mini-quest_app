// lib/streak_calendar_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/post.dart';

class StreakCalendarScreen extends StatefulWidget {
  const StreakCalendarScreen({super.key});

  @override
  State<StreakCalendarScreen> createState() => _StreakCalendarScreenState();
}

class _StreakCalendarScreenState extends State<StreakCalendarScreen> {
  bool _isLoading = true;
  // 投稿があった日付のセット (時間情報は除去して保持)
  final Set<DateTime> _postedDays = {};

  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchPostedDates();
  }

  Future<void> _fetchPostedDates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 自分の過去の投稿をすべて取得 (createdAtのみ必要なので軽量化も可能ですが今回は普通に取得)
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: user.uid)
          .get();

      final Set<DateTime> tempPostedDays = {};

      for (var doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);
        final date = post.createdAt.toDate();
        // 時間情報を切り捨てて日付のみにする (例: 2023-11-19 00:00:00)
        final normalizedDate = DateTime(date.year, date.month, date.day);
        tempPostedDays.add(normalizedDate);
      }

      if (mounted) {
        setState(() {
          _postedDays.addAll(tempPostedDays);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('カレンダーデータの取得エラー: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = Colors.deepOrange; // 炎の色

    return Scaffold(
      appBar: AppBar(title: const Text('冒険の記録')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: theme.cardTheme.color,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TableCalendar(
                        firstDay: DateTime.utc(2024, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,

                        // ▼ カレンダーのスタイル設定 ▼
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false, // 2weeks等の切替ボタンを非表示
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        calendarStyle: CalendarStyle(
                          // 今日の日付のスタイル
                          todayDecoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: const TextStyle(color: Colors.white),
                        ),

                        // ▼ 日付ごとのカスタムビルダー (ここで色を塗る) ▼
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            // 時間を切り捨てて比較
                            final normalizedDay =
                                DateTime(day.year, day.month, day.day);

                            if (_postedDays.contains(normalizedDay)) {
                              // 投稿があった日はオレンジ色の円で塗りつぶす
                              return Container(
                                margin: const EdgeInsets.all(6.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  day.day.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return null; // 通常の日付表示
                          },
                          // 今日も投稿済みなら色を変える
                          todayBuilder: (context, day, focusedDay) {
                            final normalizedDay =
                                DateTime(day.year, day.month, day.day);
                            // 今日かつ投稿済みの場合
                            if (_postedDays.contains(normalizedDay)) {
                              return Container(
                                margin: const EdgeInsets.all(6.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: primaryColor, // 投稿済みなら濃い色
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white,
                                        width: 2) // 今日は枠線をつける
                                    ),
                                child: Text(
                                  day.day.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            // 今日だけどまだ未投稿の場合 (デフォルトのスタイルが適用されますが、明示的に書くことも可能)
                            return null;
                          },
                        ),
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ▼ 凡例 ▼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('記録した日',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '毎日続けてストリークを伸ばそう！',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
