import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BotanicalBackground extends StatelessWidget {
  const BotanicalBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBF2), AppColors.cream, AppColors.mint],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/botanical_background.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              opacity: const AlwaysStoppedAnimation(.5),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFFBF2).withValues(alpha: .58),
                    AppColors.cream.withValues(alpha: .46),
                    AppColors.mint.withValues(alpha: .36),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(top: 138, left: 28, child: _JasmineGhost(size: 36)),
          const Positioned(top: 520, right: 34, child: _JasmineGhost(size: 30)),
          const Positioned(bottom: 220, left: 42, child: _VineCurl()),
          Positioned(
            bottom: 70,
            right: -24,
            child: Icon(
              Icons.spa,
              size: 130,
              color: AppColors.lightGreen.withValues(alpha: .16),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _JasmineGhost extends StatelessWidget {
  const _JasmineGhost({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _JasmineGhostPainter(),
    );
  }
}

class _JasmineGhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final petalPaint = Paint()..color = Colors.white.withValues(alpha: .34);
    final centerPaint = Paint()..color = AppColors.soil.withValues(alpha: .13);
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 5; i++) {
      final angle = i * 1.256;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            center.dx + size.width * .22 * math.sin(angle),
            center.dy - size.height * .22 * math.cos(angle),
          ),
          width: size.width * .24,
          height: size.width * .34,
        ),
        petalPaint,
      );
    }
    canvas.drawCircle(center, size.width * .075, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VineCurl extends StatelessWidget {
  const _VineCurl();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(110, 70), painter: _VineCurlPainter());
  }
}

class _VineCurlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.green.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height * .78)
      ..cubicTo(
        size.width * .3,
        size.height * .3,
        size.width * .65,
        size.height,
        size.width,
        size.height * .22,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
