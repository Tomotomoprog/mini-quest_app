// lib/widgets/profile/hex_stats_chart.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../models/user_profile.dart';

class HexStatsChart extends StatelessWidget {
  final UserStats stats;
  final int max;
  final Map<String, Color> colors;
  final String? avatarPath;
  final VoidCallback? onAvatarTap;

  const HexStatsChart({
    super.key,
    required this.stats,
    required this.max,
    required this.colors,
    this.avatarPath,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    const double chartSize = 250;
    const double labelPadding = 50;

    final List<String> labels = [
      'Life',
      'Study',
      'Physical',
      'Social',
      'Creative',
      'Mental'
    ];
    final List<int> values = [
      stats.life,
      stats.study,
      stats.physical,
      stats.social,
      stats.creative,
      stats.mental
    ];

    final List<Color> dataColors = [
      colors['Life']!,
      colors['Study']!,
      colors['Physical']!,
      colors['Social']!,
      colors['Creative']!,
      colors['Mental']!,
    ];

    return Center(
      // ▼▼▼ 修正: 全体を GestureDetector で囲み、どこをタップしても反応するように変更 ▼▼▼
      child: GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          width: chartSize + labelPadding * 2,
          height: chartSize + labelPadding * 2,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // アバター画像 (透明度なし)
              if (avatarPath != null)
                ClipPath(
                  clipper: HexagonClipper(),
                  child: SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: Image.asset(
                      avatarPath!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.black26,
                          child:
                              const Icon(Icons.person, color: Colors.white54),
                        );
                      },
                    ),
                  ),
                ),

              // チャートの描画
              CustomPaint(
                size: const Size(chartSize, chartSize),
                painter: _HexChartPainter(
                  values: values,
                  max: max,
                  colors: dataColors,
                ),
              ),

              // ラベルの描画
              ..._buildLabels(context, chartSize / 2, labels, values,
                  dataColors, labelPadding),
            ],
          ),
        ),
      ),
      // ▲▲▲
    );
  }

  List<Widget> _buildLabels(
    BuildContext context,
    double radius,
    List<String> labels,
    List<int> values,
    List<Color> dataColors,
    double labelPadding,
  ) {
    final List<Widget> widgets = [];
    final int n = labels.length;
    final double labelOffsetFromCenter = radius + (labelPadding / 2);
    final double totalSize = (radius * 2) + (labelPadding * 2);
    final double centerPos = totalSize / 2;

    const double labelWidth = 80;
    const double labelHeight = 50;

    for (int i = 0; i < n; i++) {
      final double angle = (i * 2 * math.pi / n) - (math.pi / 2);
      final double x = labelOffsetFromCenter * math.cos(angle);
      final double y = labelOffsetFromCenter * math.sin(angle);

      final double left = centerPos + x - (labelWidth / 2);
      final double top = centerPos + y - (labelHeight / 2);

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: labelWidth,
          height: labelHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                labels[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: dataColors[i],
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              Text(
                '${values[i]}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Path path = Path();
    const int n = 6;

    for (int i = 0; i < n; i++) {
      final double angle = (i * 2 * math.pi / n) - (math.pi / 2);
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexChartPainter extends CustomPainter {
  final List<int> values;
  final int max;
  final List<Color> colors;

  _HexChartPainter({
    required this.values,
    required this.max,
    required this.colors,
  });

  final Paint _backgroundPaint = Paint()
    ..color = Colors.grey[800]!.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _gridLinePaint = Paint()
    ..color = Colors.white.withOpacity(0.05)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const int n = 6;

    _drawBackgroundGrid(canvas, center, radius, n);
    _drawDataPolygon(canvas, center, radius, n);
  }

  void _drawBackgroundGrid(Canvas canvas, Offset center, double radius, int n) {
    const int gridLevels = 3;

    final Path outerHexPath = Path();
    for (int i = 0; i < n; i++) {
      final Offset point = _getOffset(center, radius, n, i);
      if (i == 0) {
        outerHexPath.moveTo(point.dx, point.dy);
      } else {
        outerHexPath.lineTo(point.dx, point.dy);
      }
    }
    outerHexPath.close();
    canvas.drawPath(outerHexPath, _backgroundPaint);

    for (int level = 1; level < gridLevels; level++) {
      final double levelRadius = radius * (level / gridLevels);
      final Path levelPath = Path();
      for (int i = 0; i < n; i++) {
        final Offset point = _getOffset(center, levelRadius, n, i);
        if (i == 0) {
          levelPath.moveTo(point.dx, point.dy);
        } else {
          levelPath.lineTo(point.dx, point.dy);
        }
      }
      levelPath.close();
      canvas.drawPath(levelPath, _gridLinePaint);
    }

    for (int i = 0; i < n; i++) {
      final Offset point = _getOffset(center, radius, n, i);
      canvas.drawLine(center, point, _backgroundPaint);
    }
  }

  void _drawDataPolygon(Canvas canvas, Offset center, double radius, int n) {
    final Path dataPath = Path();
    final List<Offset> dataPoints = [];

    for (int i = 0; i < n; i++) {
      final double value = values[i].toDouble();
      final double fraction = (max > 0 ? (value / max) : 0.0).clamp(0.0, 1.0);
      final double pointRadius = radius * fraction;
      final Offset point = _getOffset(center, pointRadius, n, i);
      dataPoints.add(point);

      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          colors.first.withOpacity(0.2),
          colors.first.withOpacity(0.05),
        ],
        [0.0, 1.0],
        TileMode.clamp,
      );
    canvas.drawPath(dataPath, fillPaint);

    for (int i = 0; i < n; i++) {
      final Paint strokePaint = Paint()
        ..color = colors[i].withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final Offset p1 = dataPoints[i];
      final Offset p2 = dataPoints[(i + 1) % n];
      canvas.drawLine(p1, p2, strokePaint);
    }
  }

  Offset _getOffset(Offset center, double radius, int n, int i) {
    final double angle = (i * 2 * math.pi / n) - (math.pi / 2);
    final double x = center.dx + radius * math.cos(angle);
    final double y = center.dy + radius * math.sin(angle);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _HexChartPainter) {
      return oldDelegate.values != values ||
          oldDelegate.max != max ||
          oldDelegate.colors != colors;
    }
    return true;
  }
}
