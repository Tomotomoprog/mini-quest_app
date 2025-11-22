// lib/widgets/profile/star_particle_overlay.dart
import 'dart:math';
import 'package:flutter/material.dart';

class StarParticleOverlay extends StatefulWidget {
  final bool trigger;
  final Widget child;
  final double size; // エフェクトの全体サイズ

  const StarParticleOverlay({
    super.key,
    required this.trigger,
    required this.child,
    this.size = 300,
  });

  @override
  State<StarParticleOverlay> createState() => _StarParticleOverlayState();
}

class _StarParticleOverlayState extends State<StarParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_StarParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.trigger) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    // 星を生成 (30個くらい)
    for (int i = 0; i < 30; i++) {
      _particles.add(_StarParticle(
        angle: _random.nextDouble() * 2 * pi,
        distance: widget.size / 2 + _random.nextDouble() * 100, // 画面外から
        delay: _random.nextDouble() * 0.5, // 出現タイミングをずらす
        color: Colors.amberAccent.shade100,
        scale: 0.5 + _random.nextDouble() * 0.5,
      ));
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child, // 背面のチャート
        if (widget.trigger)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _StarParticlePainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _StarParticle {
  final double angle;
  final double distance; // 初期距離
  final double delay; // 遅延 (0.0~1.0)
  final Color color;
  final double scale;

  _StarParticle({
    required this.angle,
    required this.distance,
    required this.delay,
    required this.color,
    required this.scale,
  });
}

class _StarParticlePainter extends CustomPainter {
  final List<_StarParticle> particles;
  final double progress;

  _StarParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // パーティクルごとの進行度 (0.0 ~ 1.0)
      // 全体progressが p.delay を超えたところから動き出す
      double localProgress = (progress - p.delay) * 2.0;
      if (localProgress < 0) continue;
      if (localProgress > 1) localProgress = 1;

      // 中心に向かって移動 (距離を縮める)
      // Curve: easeInExpo で吸い込まれるような加速感
      final double currentDistance =
          p.distance * (1 - Curves.easeInExpo.transform(localProgress));

      final double x = center.dx + currentDistance * cos(p.angle);
      final double y = center.dy + currentDistance * sin(p.angle);

      // 中心に近づくにつれて透明になる＆小さくなる
      final double alpha = (1.0 - localProgress).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(alpha);

      // 星を描画 (簡易的にひし形で表現)
      _drawStar(canvas, paint, Offset(x, y), 8 * p.scale * alpha);
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
