import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/providers/settings_provider.dart';
import '../core/services/settings_service.dart';

/// User-controllable theme settings. Surfaced through `themeProvider` and
/// persisted to the `app_settings` key/value table.
class ThemeSettings {
  const ThemeSettings({
    required this.primaryColor,
    required this.accentColor,
    required this.themeMode,
    required this.fontFamily,
    required this.fontScale,
  });

  final Color primaryColor;
  final Color accentColor;
  final ThemeMode themeMode;
  final String fontFamily; // 'system' or a curated google_fonts name
  final double fontScale;

  static const ThemeSettings defaults = ThemeSettings(
    primaryColor: Color(0xFF4F46E5),
    accentColor: Color(0xFF06B6D4),
    themeMode: ThemeMode.system,
    fontFamily: 'Inter',
    fontScale: 1.0,
  );

  ThemeSettings copyWith({
    Color? primaryColor,
    Color? accentColor,
    ThemeMode? themeMode,
    String? fontFamily,
    double? fontScale,
  }) {
    return ThemeSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

const _kPrimary = 'theme.primary';
const _kAccent = 'theme.accent';
const _kMode = 'theme.mode';
const _kFont = 'theme.font';
const _kScale = 'theme.scale';

const _curatedFonts = <String>{
  'Inter',
  'Roboto',
  'Noto Naskh Arabic',
  'Cairo',
  'IBM Plex Sans',
};

class ThemeNotifier extends StateNotifier<ThemeSettings> {
  ThemeNotifier(this._settings) : super(ThemeSettings.defaults) {
    unawaited(_load());
  }

  final SettingsService _settings;

  Future<void> _load() async {
    final primary = await _settings.getInt(_kPrimary);
    final accent = await _settings.getInt(_kAccent);
    final mode = await _settings.getRaw(_kMode);
    final font = await _settings.getRaw(_kFont);
    final scale = await _settings.getRaw(_kScale);

    state = ThemeSettings(
      primaryColor: primary != null ? Color(primary) : state.primaryColor,
      accentColor: accent != null ? Color(accent) : state.accentColor,
      themeMode: _parseMode(mode) ?? state.themeMode,
      fontFamily: _curatedFonts.contains(font) ? font! : state.fontFamily,
      fontScale: double.tryParse(scale ?? '') ?? state.fontScale,
    );
  }

  Future<void> setPrimary(Color color) async {
    state = state.copyWith(primaryColor: color);
    await _settings.setInt(_kPrimary, color.toARGB32());
  }

  Future<void> setAccent(Color color) async {
    state = state.copyWith(accentColor: color);
    await _settings.setInt(_kAccent, color.toARGB32());
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _settings.setRaw(_kMode, mode.name);
  }

  Future<void> setFontFamily(String name) async {
    if (!_curatedFonts.contains(name)) return;
    state = state.copyWith(fontFamily: name);
    await _settings.setRaw(_kFont, name);
  }

  Future<void> setFontScale(double scale) async {
    final clamped = scale.clamp(0.85, 1.30);
    state = state.copyWith(fontScale: clamped);
    await _settings.setRaw(_kScale, clamped.toStringAsFixed(2));
  }

  ThemeMode? _parseMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeSettings>((ref) {
  return ThemeNotifier(ref.watch(settingsServiceProvider));
});

const Set<String> curatedFontFamilies = _curatedFonts;

ThemeData buildTheme(ThemeSettings s, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: s.primaryColor,
    brightness: brightness,
    secondary: s.accentColor,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );
  final textTheme = s.fontFamily == 'system'
      ? base.textTheme
      : GoogleFonts.getTextTheme(s.fontFamily, base.textTheme);
  return base.copyWith(
    textTheme: textTheme.apply(fontSizeFactor: s.fontScale),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(),
    ),
  );
}
