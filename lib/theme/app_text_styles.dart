import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.darkGreen,
    letterSpacing: 0,
  );
  static const title = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
    letterSpacing: 0,
  );
  static const section = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.ink,
  );
  static const muted = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: AppColors.muted,
  );
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
}
