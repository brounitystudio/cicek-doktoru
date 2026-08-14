import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum OnboardingIllustrationType { camera, carePlan, calendar }

class OnboardingHeroIllustration extends StatelessWidget {
  const OnboardingHeroIllustration({super.key, required this.type});

  final OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          return Center(
            child: SizedBox.square(
              dimension: size.clamp(250, 370).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _HeroStage(),
                  Positioned.fill(child: _DecorativeBotany(type: type)),
                  if (type == OnboardingIllustrationType.camera)
                    const _CameraScene()
                  else if (type == OnboardingIllustrationType.carePlan)
                    const _CarePlanScene()
                  else
                    const _CalendarScene(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroStage extends StatelessWidget {
  const _HeroStage();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8F0E2), Color(0xFFE7F3E8)],
        ),
        borderRadius: BorderRadius.circular(42),
        border: Border.all(color: Colors.white.withValues(alpha: .86)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: .24),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
        ],
      ),
    );
  }
}

class _DecorativeBotany extends StatelessWidget {
  const _DecorativeBotany({required this.type});

  final OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    final accent = type == OnboardingIllustrationType.calendar
        ? AppColors.warning
        : type == OnboardingIllustrationType.carePlan
        ? AppColors.leaf
        : AppColors.green;

    return Stack(
      children: [
        Positioned(
          top: 18,
          right: 20,
          child: Transform.rotate(
            angle: .35,
            child: Icon(
              Icons.eco_rounded,
              size: 72,
              color: AppColors.green.withValues(alpha: .12),
            ),
          ),
        ),
        Positioned(
          bottom: 18,
          left: 22,
          child: Icon(
            Icons.spa_rounded,
            size: 70,
            color: accent.withValues(alpha: .11),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _VinePainter(accent))),
      ],
    );
  }
}

class _CameraScene extends StatelessWidget {
  const _CameraScene();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 74,
          top: 48,
          right: 74,
          bottom: 48,
          child: _PhoneFrame(
            child: Stack(
              children: const [
                Positioned.fill(child: _PhoneCameraView()),
                Positioned(left: 18, right: 18, bottom: 18, child: _ScanBar()),
              ],
            ),
          ),
        ),
        Positioned(
          left: 34,
          bottom: 58,
          child: _FloatingBadge(
            icon: Icons.camera_alt_rounded,
            label: 'AI tarama',
            color: AppColors.green,
          ),
        ),
        Positioned(right: 34, top: 86, child: _FloatingScore(score: '92')),
      ],
    );
  }
}

class _CarePlanScene extends StatelessWidget {
  const _CarePlanScene();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 38,
          right: 38,
          top: 56,
          bottom: 58,
          child: _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _MiniHealthHeader(),
                SizedBox(height: 16),
                _CareTask(icon: Icons.water_drop_outlined, text: 'Toprak nemi'),
                SizedBox(height: 10),
                _CareTask(icon: Icons.wb_sunny_outlined, text: 'Aydınlık yer'),
                SizedBox(height: 10),
                _CareTask(icon: Icons.eco_outlined, text: 'Yaprak kontrolü'),
              ],
            ),
          ),
        ),
        const Positioned(right: 42, bottom: 44, child: _LeafPot(size: 104)),
      ],
    );
  }
}

class _CalendarScene extends StatelessWidget {
  const _CalendarScene();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(left: 42, right: 42, top: 50, child: _CalendarPanel()),
        const Positioned(left: 48, bottom: 42, child: _LeafPot(size: 118)),
        Positioned(
          right: 38,
          bottom: 66,
          child: _FloatingBadge(
            icon: Icons.notifications_active_outlined,
            label: 'Hatırlat',
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: .26),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: child),
    );
  }
}

class _PhoneCameraView extends StatelessWidget {
  const _PhoneCameraView();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F4E9), Color(0xFFD9ECD8)],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            left: 42,
            right: 42,
            bottom: 58,
            child: _LeafPot(size: 96),
          ),
          Positioned(left: 22, top: 28, child: _FocusCorner()),
          Positioned(right: 22, top: 28, child: _FocusCorner(flipX: true)),
          Positioned(left: 22, bottom: 72, child: _FocusCorner(flipY: true)),
          Positioned(
            right: 22,
            bottom: 72,
            child: _FocusCorner(flipX: true, flipY: true),
          ),
        ],
      ),
    );
  }
}

class _FocusCorner extends StatelessWidget {
  const _FocusCorner({this.flipX = false, this.flipY = false});

  final bool flipX;
  final bool flipY;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        flipX ? -1.0 : 1.0,
        flipY ? -1.0 : 1.0,
        1,
      ),
      child: SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: .9),
                width: 3,
              ),
              left: BorderSide(
                color: Colors.white.withValues(alpha: .9),
                width: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome_rounded, color: AppColors.green),
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: .16),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTextStyles.muted.copyWith(
              color: AppColors.darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingScore extends StatelessWidget {
  const _FloatingScore({required this.score});

  final String score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: AppColors.darkGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withValues(alpha: .22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score,
            style: AppTextStyles.section.copyWith(
              color: Colors.white,
              fontSize: 21,
            ),
          ),
          Text(
            'sağlık',
            style: AppTextStyles.muted.copyWith(
              color: Colors.white70,
              fontSize: 10,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .9)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: .18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniHealthHeader extends StatelessWidget {
  const _MiniHealthHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety_outlined,
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bakım planı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.section.copyWith(fontSize: 16),
              ),
              Text(
                'Bugün için 3 öneri',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CareTask extends StatelessWidget {
  const _CareTask({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.muted.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.leaf, size: 18),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel();

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Haziran',
                style: AppTextStyles.section.copyWith(fontSize: 17),
              ),
              const Spacer(),
              const Icon(Icons.calendar_month, color: AppColors.green),
            ],
          ),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: List.generate(8, (index) {
              final active = index == 2 || index == 6;
              return Container(
                decoration: BoxDecoration(
                  color: active ? AppColors.green : AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.muted.copyWith(
                      color: active ? Colors.white : AppColors.muted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LeafPot extends StatelessWidget {
  const _LeafPot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _LeafPotPainter());
  }
}

class _LeafPotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = AppColors.darkGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .06
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()..color = AppColors.leaf;
    final darkLeafPaint = Paint()..color = AppColors.green;
    final potPaint = Paint()..color = const Color(0xFFE4D8B9);
    final rimPaint = Paint()..color = AppColors.leaf;

    final centerX = size.width * .5;
    canvas.drawLine(
      Offset(centerX, size.height * .67),
      Offset(centerX, size.height * .28),
      stemPaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height * .45),
      Offset(size.width * .27, size.height * .28),
      stemPaint,
    );
    canvas.drawLine(
      Offset(centerX, size.height * .38),
      Offset(size.width * .73, size.height * .18),
      stemPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .28, size.height * .25),
        width: size.width * .34,
        height: size.height * .2,
      ),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .74, size.height * .17),
        width: size.width * .42,
        height: size.height * .24,
      ),
      darkLeafPaint,
    );

    final pot = Path()
      ..moveTo(size.width * .27, size.height * .62)
      ..lineTo(size.width * .73, size.height * .62)
      ..lineTo(size.width * .67, size.height * .9)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .98,
        size.width * .33,
        size.height * .9,
      )
      ..close();
    canvas.drawPath(pot, potPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .22,
          size.height * .56,
          size.width * .56,
          size.height * .1,
        ),
        Radius.circular(size.width * .03),
      ),
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VinePainter extends CustomPainter {
  const _VinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .16)
      ..cubicTo(
        size.width * .32,
        size.height * .03,
        size.width * .45,
        size.height * .33,
        size.width * .62,
        size.height * .2,
      )
      ..cubicTo(
        size.width * .82,
        size.height * .05,
        size.width * .92,
        size.height * .26,
        size.width * .8,
        size.height * .42,
      );
    canvas.drawPath(path, paint);

    for (final point in [
      Offset(size.width * .2, size.height * .14),
      Offset(size.width * .58, size.height * .22),
      Offset(size.width * .82, size.height * .38),
    ]) {
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(math.pi / 7);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 22, height: 11),
        Paint()..color = color.withValues(alpha: .13),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _VinePainter oldDelegate) =>
      oldDelegate.color != color;
}
