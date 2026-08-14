import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum BotanicalPatternTone { meadow, jasmine, vine }

class BotanicalCardPattern extends StatelessWidget {
  const BotanicalCardPattern({
    super.key,
    required this.tone,
    required this.onDark,
  });

  final BotanicalPatternTone tone;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BotanicalCardPainter(tone: tone, onDark: onDark),
        ),
      ),
    );
  }
}

class _BotanicalCardPainter extends CustomPainter {
  const _BotanicalCardPainter({required this.tone, required this.onDark});

  final BotanicalPatternTone tone;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = onDark ? Colors.white : AppColors.green;
    final accent = onDark ? AppColors.lightGreen : AppColors.soil;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = base.withValues(alpha: onDark ? .12 : .075);

    switch (tone) {
      case BotanicalPatternTone.vine:
        _paintVine(canvas, size, paint, base);
      case BotanicalPatternTone.jasmine:
        _paintJasmine(canvas, size, base, accent);
      case BotanicalPatternTone.meadow:
        _paintMeadow(canvas, size, paint, base, accent);
    }
  }

  void _paintVine(Canvas canvas, Size size, Paint paint, Color base) {
    final path = Path()
      ..moveTo(size.width * .62, size.height + 8)
      ..cubicTo(
        size.width * .76,
        size.height * .74,
        size.width * .58,
        size.height * .55,
        size.width * .78,
        size.height * .34,
      )
      ..cubicTo(
        size.width * .88,
        size.height * .23,
        size.width * .84,
        size.height * .12,
        size.width + 8,
        -8,
      );
    canvas.drawPath(path, paint);

    final leafPaint = Paint()
      ..color = base.withValues(alpha: onDark ? .105 : .07);
    _leaf(
      canvas,
      Offset(size.width * .78, size.height * .58),
      18,
      -.65,
      leafPaint,
    );
    _leaf(
      canvas,
      Offset(size.width * .69, size.height * .38),
      14,
      .88,
      leafPaint,
    );
    _leaf(
      canvas,
      Offset(size.width * .87, size.height * .22),
      16,
      -.35,
      leafPaint,
    );
  }

  void _paintJasmine(Canvas canvas, Size size, Color base, Color accent) {
    final petalPaint = Paint()
      ..color = (onDark ? Colors.white : const Color(0xFFFFF4DC)).withValues(
        alpha: onDark ? .10 : .22,
      );
    final centerPaint = Paint()
      ..color = accent.withValues(alpha: onDark ? .13 : .09);
    _flower(
      canvas,
      Offset(size.width * .88, size.height * .22),
      15,
      petalPaint,
      centerPaint,
    );
    _flower(
      canvas,
      Offset(size.width * .94, size.height * .78),
      11,
      petalPaint,
      centerPaint,
    );

    final leafPaint = Paint()
      ..color = base.withValues(alpha: onDark ? .08 : .035);
    _leaf(
      canvas,
      Offset(size.width * .73, size.height * .82),
      17,
      .65,
      leafPaint,
    );
  }

  void _paintMeadow(
    Canvas canvas,
    Size size,
    Paint paint,
    Color base,
    Color accent,
  ) {
    final path = Path()
      ..moveTo(-8, size.height * .82)
      ..cubicTo(
        size.width * .22,
        size.height * .62,
        size.width * .18,
        size.height * .37,
        size.width * .42,
        size.height * .28,
      )
      ..cubicTo(
        size.width * .57,
        size.height * .22,
        size.width * .61,
        size.height * .12,
        size.width * .76,
        -8,
      );
    canvas.drawPath(path, paint);

    final leafPaint = Paint()
      ..color = base.withValues(alpha: onDark ? .10 : .06);
    _leaf(
      canvas,
      Offset(size.width * .22, size.height * .62),
      15,
      -.2,
      leafPaint,
    );
    _leaf(
      canvas,
      Offset(size.width * .48, size.height * .25),
      18,
      .72,
      leafPaint,
    );

    final dotPaint = Paint()
      ..color = accent.withValues(alpha: onDark ? .16 : .12);
    canvas.drawCircle(Offset(size.width * .92, size.height * .18), 5, dotPaint);
    canvas.drawCircle(Offset(size.width * .86, size.height * .28), 3, dotPaint);
  }

  void _leaf(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -radius)
      ..cubicTo(
        radius * .9,
        -radius * .55,
        radius * .75,
        radius * .6,
        0,
        radius,
      )
      ..cubicTo(
        -radius * .85,
        radius * .45,
        -radius * .75,
        -radius * .65,
        0,
        -radius,
      );
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _flower(
    Canvas canvas,
    Offset center,
    double radius,
    Paint petalPaint,
    Paint centerPaint,
  ) {
    for (var i = 0; i < 5; i++) {
      final angle = i * 1.256;
      final petalCenter = Offset(
        center.dx + radius * .55 * math.sin(angle),
        center.dy - radius * .55 * math.cos(angle),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: petalCenter,
          width: radius * .58,
          height: radius,
        ),
        petalPaint,
      );
    }
    canvas.drawCircle(center, radius * .18, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _BotanicalCardPainter oldDelegate) {
    return oldDelegate.tone != tone || oldDelegate.onDark != onDark;
  }
}
