/// Neo-Manga Cyberpunk, from DESIGN.md: obsidian ground under a faint
/// blueprint grid, neon lime for the thing to press, electric violet for
/// vocabulary, mint for "you got it right".
library;

import 'package:flutter/material.dart';

class C {
  static const ground = Color(0xFF0D0D11);
  static const surface = Color(0xFF16161F);
  static const elevated = Color(0xFF1E1E2A);
  static const sheet = Color(0xFF090A0E);
  static const border = Color(0xFF2E2E42);
  static const ghostBorder = Color(0xFF3E3E56);
  static const track = Color(0xFF262636);
  static const grid = Color(0x0AFFFFFF);

  static const lime = Color(0xFFE3FD38);
  static const violet = Color(0xFF7B52F8);
  static const mint = Color(0xFF2EE9A6);
  static const danger = Color(0xFFFF6B6B);

  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFA0A0B5);
  static const inactive = Color(0xFF6C6C82);

  /// Text on lime: pitch black at heavy weight, per the spec.
  static const onLime = Color(0xFF0D0D11);
}

class T {
  static const _outfit = 'Outfit';
  static const _mono = 'SpaceMono';

  static const headlineXl = TextStyle(
    fontFamily: _outfit,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.8,
    color: C.text,
  );
  static const headlineLg = TextStyle(
    fontFamily: _outfit,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.26,
    color: C.text,
  );
  static const headlineMd = TextStyle(
    fontFamily: _outfit,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: C.text,
  );
  static const bodyLg = TextStyle(
    fontFamily: _outfit,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: C.text,
  );
  static const bodyMd = TextStyle(
    fontFamily: _outfit,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: C.text,
  );
  static const pill = TextStyle(
    fontFamily: _outfit,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: C.text,
  );
  static const monoBold = TextStyle(
    fontFamily: _mono,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.33,
    letterSpacing: 0.72,
    color: C.text,
  );
  static const monoSm = TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0.8,
    color: C.textDim,
  );

  /// Japanese: generous line height so furigana has room.
  static const jp = TextStyle(
    fontFamily: _outfit,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.6,
    color: C.text,
  );
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.dark(
    primary: C.lime,
    onPrimary: C.onLime,
    secondary: C.violet,
    onSecondary: C.text,
    tertiary: C.mint,
    surface: C.surface,
    onSurface: C.text,
    error: C.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: C.ground,
    canvasColor: C.ground,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.lime,
      selectionColor: Color(0x55E3FD38),
      selectionHandleColor: C.lime,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black,
      hintStyle: T.bodyMd.copyWith(color: C.inactive),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: C.ghostBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: C.ghostBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: C.lime, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: C.border),
      ),
      titleTextStyle: T.headlineMd,
      contentTextStyle: T.bodyMd,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.sheet,
      showDragHandle: true,
      dragHandleColor: C.inactive,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.elevated,
      contentTextStyle: T.bodyMd,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.lime, textStyle: T.pill),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.lime),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.onLime : C.inactive,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? C.lime : C.track,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.lime,
      inactiveTrackColor: C.track,
      thumbColor: C.lime,
    ),
  );
}

/// Japanese at study size, from jlptbenkyo: a 14pt kanji is a smudge, and
/// not being able to tell 待 from 持 looks exactly like not knowing them.
class Jp {
  static const word = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 52,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: C.text,
  );
  static const reading = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 24,
    height: 1.4,
    color: C.lime,
  );
  static const sentence = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 22,
    height: 1.8,
    color: C.text,
  );
}

/// Anki's colours, which every SRS user already reads without labels:
/// Again red, Hard orange, Good green, Easy blue.
class Srs {
  static const again = Color(0xFFE53935);
  static const hard = Color(0xFFFB8C00);
  static const good = Color(0xFF43A047);
  static const easy = Color(0xFF1E88E5);

  /// The three counts: new blue, learning red, review green.
  static const newCards = Color(0xFF42A5F5);
  static const learning = Color(0xFFEF5350);
  static const review = Color(0xFF66BB6A);
}

/// A JLPT level's colour, as in jlptbenkyo, so the level reads at a glance.
Color jlptColour(String? level) => switch (level) {
  'N5' => const Color(0xFF43A047),
  'N4' => const Color(0xFF1E88E5),
  'N3' => const Color(0xFF8E24AA),
  'N2' => const Color(0xFFF4511E),
  'N1' => const Color(0xFFE53935),
  _ => const Color(0xFF757575),
};
