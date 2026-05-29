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
  final isDark = brightness == Brightness.dark;
  return base.copyWith(
    textTheme: textTheme.apply(fontSizeFactor: s.fontScale),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 20 * s.fontScale,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
        ),
      ),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outline.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outline.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      side: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11 * s.fontScale,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          size: 22,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: scheme.surface,
      elevation: 8,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      focusElevation: 4,
      hoverElevation: 5,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 8,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: scheme.surface,
      titleTextStyle: TextStyle(
        fontSize: 18 * s.fontScale,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13 * s.fontScale,
      ),
      unselectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13 * s.fontScale,
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: isDark ? scheme.onSurface : scheme.onInverseSurface,
        fontSize: 14 * s.fontScale,
      ),
    ),
  );
}
