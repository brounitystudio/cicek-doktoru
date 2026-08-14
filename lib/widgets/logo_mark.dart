import 'package:flutter/material.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: Image.asset(
        'assets/brand/logo_mark.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class FullBrandLogo extends StatelessWidget {
  const FullBrandLogo({super.key, this.width = 320});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo_full.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
