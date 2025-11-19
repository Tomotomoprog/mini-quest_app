// lib/effort_history_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/post.dart';

// グラフ表示用のデータクラス
class _ChartDataPoint {
  final String label; // X軸のラベル (例: "11/1", "11/1~")
  final Map<String, double> efforts; // クエストIDごとの努力時間
  final DateTime startDate; // 集計期間の開始日

  _ChartDataPoint({
    required this.label,
    required this.efforts,
    required this.startDate,
  });

  double get total => efforts.values.fold(0, (sum, val) => sum + val);
}

class EffortHistoryScreen extends StatefulWidget {
  const EffortHistoryScreen({super.key});

  @override
  State<EffortHistoryScreen> createState() => _EffortHistoryScreenState();
}

class _EffortHistoryScreenState extends State<EffortHistoryScreen> {
  bool _isLoading = true;

  // 選択された期間（日数）
  int _selectedPeriodDays = 7;

  // 集計後のグラフデータ
  List<_ChartDataPoint> _chartData = [];

  // クエスト情報 (ID -> タイトル/色)
  Map<String, String> _questTitles = {};
  Map<String, Color> _questColors = {};

  // 期間内の合計時間
  double _totalPeriodHours = 0.0;

  // カラーパレット
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

  // 集計単位（日数）を決定する
  int _getAggregationStep() {
    if (_selectedPeriodDays == 30) return 7; // 1ヶ月 -> 1週間
    if (_selectedPeriodDays == 90) return 14; // 3ヶ月 -> 2週間
    return 1; // 1週間 -> 1日
  }

  Future<void> _fetchEffortData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // データの取得開始日
    // (今日を含めて _selectedPeriodDays 分遡る)
    final startDate = today.subtract(Duration(days: _selectedPeriodDays - 1));

    try {
      // 1. Firestoreから期間内のデータを取得
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: user.uid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('createdAt', descending: false)
          .get();

      final Map<String, String> tempQuestTitles = {};
      final Map<String, Color> tempQuestColors = {};
      int colorIndex = 0;
      double tempTotalHours = 0.0;

      // 2. 集計枠（バケット）の準備
      final int step = _getAggregationStep();
      // 必要なバケット数 (切り上げ)
      final int bucketCount = (_selectedPeriodDays / step).ceil();

      List<_ChartDataPoint> tempData = List.generate(bucketCount, (index) {
        final bucketStart = startDate.add(Duration(days: index * step));
        String label;
        if (step == 1) {
          label = DateFormat('M/d').format(bucketStart);
        } else {
          // 範囲の場合は "M/d~" のように表示
          label = "${DateFormat('M/d').format(bucketStart)}~";
        }
        return _ChartDataPoint(
          label: label,
          efforts: {},
          startDate: bucketStart,
        );
      });

      // 3. 投稿データをバケットに振り分け
      for (var doc in snapshot.docs) {
        final post = Post.fromFirestore(doc);
        if (post.timeSpentHours == null || post.timeSpentHours! <= 0) continue;

        final postDate = post.createdAt.toDate();
        final normalizedDate =
            DateTime(postDate.year, postDate.month, postDate.day);

        // 範囲外チェック
        if (normalizedDate.isBefore(startDate)) continue;

        // 開始日からの経過日数
        final diffDays = normalizedDate.difference(startDate).inDays;
        // バケットのインデックスを計算
        final bucketIndex = diffDays ~/ step;

        if (bucketIndex >= 0 && bucketIndex < tempData.length) {
          final questId = post.myQuestId ?? 'unknown';
          final questTitle =
              post.myQuestTitle ?? (post.isShortPost ? '一言投稿' : 'その他');

          // クエスト情報の登録
          if (!tempQuestTitles.containsKey(questId)) {
            tempQuestTitles[questId] = questTitle;
            tempQuestColors[questId] =
                _chartColors[colorIndex % _chartColors.length];
            colorIndex++;
          }

          // 時間を加算
          final efforts = tempData[bucketIndex].efforts;
          efforts[questId] = (efforts[questId] ?? 0) + post.timeSpentHours!;

          // 合計時間も加算
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
                  // ▼▼▼ ヘッダー (期間選択 & 合計) ▼▼▼
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

                  // ▼▼▼ 棒グラフ ▼▼▼
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
                              // ロッドのスタック順序からクエストIDを特定
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
                          horizontalInterval: 1, // 1時間ごとに線
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

                  // ▼▼▼ 凡例（レジェンド） ▼▼▼
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
    // 最低でも5、または最大値の1.2倍 (端数を綺麗にするためceilも可)
    return (maxTotal < 5 ? 5 : maxTotal * 1.2).toDouble();
  }

  String _getQuestIdFromRodIndex(_ChartDataPoint dataPoint, int rodStackIndex) {
    // _generateBarGroups の forEach 順序に依存
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
            width: 24, // 棒の太さ
            color: Colors.transparent,
            rodStackItems: rodStackItems,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    });
  }
}
