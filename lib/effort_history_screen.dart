// lib/effort_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';

class _ChartDataPoint {
  final String label;
  final Map<String, double> efforts;
  final DateTime startDate;

  _ChartDataPoint({
    required this.label,
    required this.efforts,
    required this.startDate,
  });

  double get total => efforts.values.fold(0, (sum, val) => sum + val);
}

class EffortHistoryScreen extends StatefulWidget {
  // ▼▼▼ 追加: 表示対象のユーザーIDを受け取る ▼▼▼
  final String? userId;

  const EffortHistoryScreen({
    super.key,
    this.userId, // コンストラクタに追加
  });
  // ▲▲▲

  @override
  State<EffortHistoryScreen> createState() => _EffortHistoryScreenState();
}

class _EffortHistoryScreenState extends State<EffortHistoryScreen> {
  bool _isLoading = true;
  int _selectedPeriodDays = 7;
  List<_ChartDataPoint> _chartData = [];
  Map<String, String> _questTitles = {};
  Map<String, Color> _questColors = {};
  double _totalPeriodHours = 0.0;

  final List<Color> _chartColors = [
    Colors.blue,
    Colors.redAccent,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _fetchEffortData();
  }

  void _onPeriodChanged(int? days) {
    if (days != null && days != _selectedPeriodDays) {
      setState(() {
        _selectedPeriodDays = days;
        _isLoading = true;
      });
      _fetchEffortData();
    }
  }

  int _getAggregationStep() {
    if (_selectedPeriodDays == 30) return 7;
    if (_selectedPeriodDays == 90) return 14;
    return 1;
  }

  Future<void> _fetchEffortData() async {
    // ▼▼▼ 修正: 渡されたIDがあればそれを使い、なければ自分のIDを使う ▼▼▼
    final targetUserId =
        widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

    if (targetUserId == null) return;
    // ▲▲▲

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(Duration(days: _selectedPeriodDays - 1));

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: targetUserId) // ◀◀◀ targetUserId を使用
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('createdAt', descending: false)
          .get();

      final Map<String, String> tempQuestTitles = {};
      final Map<String, Color> tempQuestColors = {};
      int colorIndex = 0;
      double tempTotalHours = 0.0;

      final int step = _getAggregationStep();
      final int bucketCount = (_selectedPeriodDays / step).ceil();

      List<_ChartDataPoint> tempData = List.generate(bucketCount, (index) {
        final bucketStart = startDate.add(Duration(days: index * step));
        String label;
        if (step == 1) {
          label = DateFormat('M/d').format(bucketStart);
        } else {
          label = "${DateFormat('M/d').format(bucketStart)}~";
        }
        return _ChartDataPoint(
          label: label,
          efforts: {},
          startDate: bucketStart,
        );
      });

      for (var doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);
        if (post.timeSpentHours == null || post.timeSpentHours! <= 0) continue;

        final postDate = post.createdAt.toDate();
        final normalizedDate =
            DateTime(postDate.year, postDate.month, postDate.day);

        if (normalizedDate.isBefore(startDate)) continue;

        final diffDays = normalizedDate.difference(startDate).inDays;
        final bucketIndex = diffDays ~/ step;

        if (bucketIndex >= 0 && bucketIndex < tempData.length) {
          final questId = post.myQuestId ?? 'unknown';
          final questTitle =
              post.myQuestTitle ?? (post.isShortPost ? '一言投稿' : 'その他');

          if (!tempQuestTitles.containsKey(questId)) {
            tempQuestTitles[questId] = questTitle;
            tempQuestColors[questId] =
                _chartColors[colorIndex % _chartColors.length];
            colorIndex++;
          }

          final efforts = tempData[bucketIndex].efforts;
          efforts[questId] = (efforts[questId] ?? 0) + post.timeSpentHours!;

          tempTotalHours += post.timeSpentHours!;
        }
      }

      if (mounted) {
        setState(() {
          _chartData = tempData;
          _questTitles = tempQuestTitles;
          _questColors = tempQuestColors;
          _totalPeriodHours = tempTotalHours;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('グラフデータの取得エラー: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('努力の推移')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade700),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedPeriodDays,
                            items: const [
                              DropdownMenuItem(value: 7, child: Text("1週間")),
                              DropdownMenuItem(value: 30, child: Text("1ヶ月")),
                              DropdownMenuItem(value: 90, child: Text("3ヶ月")),
                            ],
                            onChanged: _onPeriodChanged,
                            isDense: true,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("期間合計",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "${_totalPeriodHours.toStringAsFixed(1)} h",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _calculateMaxY(),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final dataPoint = _chartData[group.x];
                              final questId =
                                  _getQuestIdFromRodIndex(dataPoint, rodIndex);
                              final title = _questTitles[questId] ?? 'その他';
                              final value = rod.toY - rod.fromY;

                              return BarTooltipItem(
                                '$title\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${value.toStringAsFixed(1)} h',
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= _chartData.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _chartData[index].label,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _generateBarGroups(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('内訳',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _questTitles.entries.map((entry) {
                      final id = entry.key;
                      final title = entry.value;
                      final color = _questColors[id]!;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(title, style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  double _calculateMaxY() {
    double maxTotal = 0;
    for (var data in _chartData) {
      if (data.total > maxTotal) maxTotal = data.total;
    }
    return (maxTotal < 5 ? 5 : maxTotal * 1.2).toDouble();
  }

  String _getQuestIdFromRodIndex(_ChartDataPoint dataPoint, int rodStackIndex) {
    if (rodStackIndex < dataPoint.efforts.length) {
      return dataPoint.efforts.keys.elementAt(rodStackIndex);
    }
    return 'unknown';
  }

  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(_chartData.length, (index) {
      final dataPoint = _chartData[index];
      List<BarChartRodStackItem> rodStackItems = [];
      double currentY = 0;

      dataPoint.efforts.forEach((questId, hours) {
        final color = _questColors[questId] ?? Colors.grey;
        rodStackItems
            .add(BarChartRodStackItem(currentY, currentY + hours, color));
        currentY += hours;
      });

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: currentY,
            width: 24,
            color: Colors.transparent,
            rodStackItems: rodStackItems,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });
  }
}
