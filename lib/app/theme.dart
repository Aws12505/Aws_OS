import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/settings_provider.dart';
import '../core/services/settings_service.dart';
import '../shared/design/app_theme.dart';

/// User-controllable theme settings. Surfaced through `themeProvider` and
/// persisted to the `app_settings` key/value table.
@immutable
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

  /// Value equality is what makes the [buildTheme] cache work. Without it every
  /// rebuild of the app widget regenerates two seeded color schemes, a contrast
  /// search per semantic role, and the whole type scale.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings &&
          other.primaryColor == primaryColor &&
          other.accentColor == accentColor &&
          other.themeMode == themeMode &&
          other.fontFamily == fontFamily &&
          other.fontScale == fontScale;

  @override
  int get hashCode =>
      Object.hash(primaryColor, accentColor, themeMode, fontFamily, fontScale);
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

ThemeMode? _parseMode(String? raw) => switch (raw) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => null,
};

/// Reads the persisted theme without constructing a notifier.
///
/// Called from `main()` before the first frame so a cold start renders the
/// theme the user actually chose. The app used to paint one frame of default
/// indigo in the default font and then swap.
Future<ThemeSettings> loadThemeSettings(SettingsService settings) async {
  const base = ThemeSettings.defaults;
  final primary = await settings.getInt(_kPrimary);
  final accent = await settings.getInt(_kAccent);
  final mode = await settings.getRaw(_kMode);
  final font = await settings.getRaw(_kFont);
  final scale = await settings.getRaw(_kScale);

  return ThemeSettings(
    primaryColor: primary != null ? Color(primary) : base.primaryColor,
    accentColor: accent != null ? Color(accent) : base.accentColor,
    themeMode: _parseMode(mode) ?? base.themeMode,
    fontFamily: _curatedFonts.contains(font) ? font! : base.fontFamily,
    fontScale: double.tryParse(scale ?? '') ?? base.fontScale,
  );
}

/// Seeded by `main()` with the persisted settings so there is no first-frame
/// theme flash. Falls back to [ThemeSettings.defaults] when not overridden,
/// which is what tests and any other entry point get.
final initialThemeSettingsProvider = Provider<ThemeSettings>(
  (ref) => ThemeSettings.defaults,
);

class ThemeNotifier extends StateNotifier<ThemeSettings> {
  ThemeNotifier(this._settings, ThemeSettings initial) : super(initial) {
    unawaited(_load());
  }

  final SettingsService _settings;

  Future<void> _load() async {
    state = await loadThemeSettings(_settings);
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
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeSettings>((
  ref,
) {
  return ThemeNotifier(
    ref.watch(settingsServiceProvider),
    ref.watch(initialThemeSettingsProvider),
  );
});

const Set<String> curatedFontFamilies = _curatedFonts;

/// `AwsOsApp.build` calls this twice, once per brightness, and rebuilds on any
/// theme or router change. Each uncached call generates a seeded HCT palette,
/// runs a contrast search per semantic role and resolves fifteen font variants,
/// so this cache is not a micro-optimization; it is what makes those
/// affordable.
final Map<(ThemeSettings, Brightness), ThemeData> _themeCache = {};

ThemeData buildTheme(ThemeSettings s, Brightness brightness) {
  if (_themeCache.length > 6) _themeCache.clear();
  return _themeCache.putIfAbsent((
    s,
    brightness,
  ), () => _buildTheme(s, brightness));
}

ThemeData _buildTheme(ThemeSettings s, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: s.primaryColor,
    brightness: brightness,
    secondary: s.accentColor,
  );
  final type = AppTypeTokens.resolve(family: s.fontFamily, scale: s.fontScale);
  final app = AppTheme.fromScheme(scheme, typography: type);
  final surfaces = app.surfaces;
  final isDark = brightness == Brightness.dark;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
  );

  OutlineInputBorder inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[app],
    // The type scale already carries fontScale, letter spacing included. There
    // must be no `* s.fontScale` anywhere below this line.
    //
    // The colours have to be applied here. `ThemeData`'s constructor merges a
    // bare text theme onto Typography.black/white, but `copyWith` does not, so
    // a scale built with null colours stays null — and a null `TextStyle.color`
    // paints white in dart:ui. That rendered every heading, value and title
    // white-on-white in the light theme while dark mode looked correct by
    // coincidence.
    textTheme: type.textTheme.apply(
      bodyColor: surfaces.textPrimary,
      displayColor: surfaces.textPrimary,
      decorationColor: surfaces.textPrimary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    // Opaque. There is no backdrop behind the routes any more, so a
    // transparent page would show the raw window.
    scaffoldBackgroundColor: surfaces.canvas,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Without this, AppBar derives the overlay style from its own background
      // colour — which is transparent here — and guesses wrong. Its
      // AnnotatedRegion sits deeper than AppScaffold's, so it wins, and the
      // status-bar icons went invisible on every screen with an app bar.
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: type.appBarTitle.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: surfaces.hairline),
      ),
      color: surfaces.raised,
      surfaceTintColor: Colors.transparent,
    ),
    // Filled, with no resting outline. A field that is a soft filled shape
    // reads as somewhere to type; a rectangle drawn in outline reads as a
    // border, and a form of them reads as a table.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaces.sunken,
      border: inputBorder(Colors.transparent, 0),
      enabledBorder: inputBorder(Colors.transparent, 0),
      focusedBorder: inputBorder(scheme.primary, 2),
      errorBorder: inputBorder(scheme.error, 1),
      focusedErrorBorder: inputBorder(scheme.error, 2),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      labelStyle: type.textTheme.bodyMedium?.copyWith(
        color: surfaces.textSecondary,
      ),
      hintStyle: type.textTheme.bodyMedium?.copyWith(
        color: surfaces.textTertiary,
      ),
      helperStyle: type.textTheme.bodySmall?.copyWith(
        color: surfaces.textSecondary,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide(color: surfaces.hairline),
      ),
      side: BorderSide(color: surfaces.hairline),
      labelStyle: type.textTheme.labelLarge ?? const TextStyle(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Derived from the resolved label so the bar grows with the text scale
      // instead of clipping at 1.30.
      height: type.navBarHeight,
      elevation: 0,
      backgroundColor: Colors.transparent,
      // The selected destination gets a tonal pill. It is the one piece of
      // chrome on every screen, and a filled marker says where you are from
      // across the room where a colour change alone does not.
      indicatorColor: surfaces.tint(
        scheme.primary,
        over: surfaces.navFill,
        strength: isDark ? 0.30 : 0.18,
      ),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return type.navLabel
            .weight(selected ? FontWeight.w700 : FontWeight.w500)
            .copyWith(
              color: selected ? scheme.primary : surfaces.textSecondary,
            );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : surfaces.textTertiary,
          size: 23,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      dragHandleColor: surfaces.textTertiary,
      dragHandleSize: const Size(28, 3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      backgroundColor: surfaces.overlay,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      elevation: 3,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 6,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    // Buttons were on Material defaults, which means fully rounded stadiums.
    // A capsule is the one shape this design does not use outside of chips.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        elevation: 0,
        textStyle: type.textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        side: BorderSide(
          color: surfaces.hairlineStrong,
          width: AppSurfaces.hairlineWidth,
        ),
        foregroundColor: surfaces.textPrimary,
        textStyle: type.textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: type.textTheme.labelLarge,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: surfaces.hairline,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      // The page margin, so a tile lines up with the section label above it
      // and with every header on every other screen.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 2,
      ),
      minVerticalPadding: AppSpacing.sm,
      titleTextStyle: type.textTheme.titleSmall,
      subtitleTextStyle: type.textTheme.bodySmall?.copyWith(
        color: surfaces.textSecondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      elevation: 0,
      backgroundColor: surfaces.overlay,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: type.dialogTitle.copyWith(color: scheme.onSurface),
      contentTextStyle: type.textTheme.bodyMedium?.copyWith(
        color: surfaces.textSecondary,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      color: surfaces.overlay,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      textStyle: type.textTheme.bodyMedium,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: surfaces.textPrimary,
      unselectedLabelColor: surfaces.textTertiary,
      labelStyle: type.tabLabel,
      unselectedLabelStyle: type.tabLabel.weight(FontWeight.w500),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      backgroundColor: isDark
          ? scheme.surfaceContainerHigh
          : scheme.inverseSurface,
      contentTextStyle: type.snackBody.copyWith(
        color: isDark ? scheme.onSurface : scheme.onInverseSurface,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: type.textTheme.bodySmall?.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
  );
}
