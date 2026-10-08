import 'package:flutter/material.dart';

class PeladinhasColors {
  const PeladinhasColors._();

  static const brandDark = Color(0xFF0A3325);
  static const brand = Color(0xFF0B6B47);
  static const brandSoft = Color(0xFFE9F2ED);
  static const highlight = Color(0xFFD6A45E);
  static const background = Color(0xFFF5F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF101512);
  static const inkSecondary = Color(0xFF5C655F);
  static const border = Color(0xFFD8DDD9);
  static const success = Color(0xFF1C7A50);
  static const onDark = Color(0xFFF7F8F5);
  static const mutedIcon = Color(0xFFC8D8CF);
}

class PeladinhasSpacing {
  const PeladinhasSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 44.0;
}

class PeladinhasRadii {
  const PeladinhasRadii._();

  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 16.0;
}

class PeladinhasBreakpoints {
  const PeladinhasBreakpoints._();

  static const mobile = 768.0;
  static const desktop = 1200.0;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}

class PeladinhasTypography {
  const PeladinhasTypography._();

  static const fontFamily = 'Manrope';
  static const fontFamilyFallback = ['Arial', 'Helvetica', 'sans-serif'];

  static const display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w700,
    color: PeladinhasColors.ink,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    height: 34 / 26,
    fontWeight: FontWeight.w700,
    color: PeladinhasColors.ink,
  );

  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    color: PeladinhasColors.ink,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 23 / 15,
    fontWeight: FontWeight.w400,
    color: PeladinhasColors.inkSecondary,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}

ThemeData buildPeladinhasTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: PeladinhasColors.brand,
      primary: PeladinhasColors.brand,
      surface: PeladinhasColors.surface,
    ),
    scaffoldBackgroundColor: PeladinhasColors.background,
    fontFamily: PeladinhasTypography.fontFamily,
    fontFamilyFallback: PeladinhasTypography.fontFamilyFallback,
    useMaterial3: true,
  );
}
