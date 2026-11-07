import 'package:flutter/material.dart';

/// Design tokens của M1 (docs/13-m1-sprint1-ui.md), giữ nguyên giá trị.
abstract final class AppColors {
  static const background = Color(0xFFFFFBF8);
  static const ink = Color(0xFF29262B);
  static const rose = Color(0xFFC74E70);
  static const softRose = Color(0xFFFCE8EC);
  static const border = Color(0xFFE8DDD9);
}

final ThemeData ourSpaceTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.rose,
    primary: AppColors.rose,
    surface: AppColors.background,
    onSurface: AppColors.ink,
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(
      fontSize: 38,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.ink,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.rose, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
);

/// Định dạng ngày giờ theo giờ local của thiết bị (backend trả UTC ISO-8601).
String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
