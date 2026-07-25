import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = isDark ? _darkColorScheme : _lightColorScheme;
    final textTheme = isDark ? _darkTextTheme : _lightTextTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: isDark ? AppColors.bgPrimary : AppColors.lightBgPrimary,
      colorScheme: cs,
      textTheme: textTheme,
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.bgTertiary : AppColors.lightBgSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgTertiary : AppColors.lightBgSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.glassBorder : AppColors.lightOutline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.glassBorder : AppColors.lightOutline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.accentPrimary : AppColors.lightAccentPrimary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: isDark ? AppColors.textPlaceholder : AppColors.lightTextPlaceholder,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.buttonHorizontal,
            vertical: AppSpacing.buttonVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(
            color: isDark ? AppColors.glassBorder : AppColors.lightOutline,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.secondary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(40),
          overlayColor: cs.onSurface.withValues(alpha: 0.08),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: cs.onSurfaceVariant,
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          hoverColor: cs.primary.withValues(alpha: 0.08),
          focusColor: cs.primary.withValues(alpha: 0.12),
          minimumSize: const Size(44, 44),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.glassBorder : AppColors.lightOutlineVariant,
        thickness: 1,
        space: AppSpacing.md,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cs.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: cs.onInverseSurface,
        ),
        actionTextColor: cs.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.bgTertiary : AppColors.lightBgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.bgTertiary : AppColors.lightBgSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: cs.primaryContainer,
        labelStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide.none,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary;
          }
          return cs.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary.withValues(alpha: 0.5);
          }
          return cs.surfaceContainerHighest;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgSecondary : AppColors.lightBgSecondary,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceContainerHighest,
        thumbColor: cs.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return cs.outline;
        }),
      ),
    );
  }

  static const _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: AppColors.accentPrimary,
    onPrimary: AppColors.textOnAccent,
    primaryContainer: AppColors.accentPrimary,
    onPrimaryContainer: AppColors.textOnAccent,
    secondary: AppColors.accentSecondary,
    onSecondary: AppColors.textOnAccent,
    secondaryContainer: AppColors.accentSecondary,
    onSecondaryContainer: AppColors.textOnAccent,
    tertiary: AppColors.success,
    onTertiary: AppColors.textOnAccent,
    tertiaryContainer: AppColors.success,
    onTertiaryContainer: AppColors.textOnAccent,
    surface: AppColors.bgTertiary,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerHighest: AppColors.bgSecondary,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.bgPrimary,
    inversePrimary: AppColors.accentPrimaryLight,
    error: AppColors.error,
    onError: AppColors.textOnAccent,
    errorContainer: AppColors.error,
    onErrorContainer: AppColors.textOnAccent,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    shadow: AppColors.shadow,
    surfaceTint: AppColors.accentPrimary,
  );

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: AppColors.lightAccentPrimary,
    onPrimary: AppColors.lightTextOnAccent,
    primaryContainer: AppColors.lightAccentPrimary,
    onPrimaryContainer: AppColors.lightTextOnAccent,
    secondary: AppColors.lightAccentSecondary,
    onSecondary: AppColors.lightTextOnAccent,
    secondaryContainer: AppColors.lightAccentSecondary,
    onSecondaryContainer: AppColors.lightTextOnAccent,
    tertiary: AppColors.lightSuccess,
    onTertiary: AppColors.lightTextOnAccent,
    tertiaryContainer: AppColors.lightSuccess,
    onTertiaryContainer: AppColors.lightTextOnAccent,
    surface: AppColors.lightBgSecondary,
    onSurface: AppColors.lightTextPrimary,
    onSurfaceVariant: AppColors.lightTextSecondary,
    surfaceContainerHighest: AppColors.lightBgTertiary,
    inverseSurface: AppColors.lightTextPrimary,
    onInverseSurface: AppColors.lightBgPrimary,
    inversePrimary: AppColors.accentPrimaryLight,
    error: AppColors.lightError,
    onError: AppColors.lightTextOnAccent,
    errorContainer: AppColors.lightError,
    onErrorContainer: AppColors.lightTextOnAccent,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    shadow: AppColors.lightShadow,
    surfaceTint: AppColors.lightAccentPrimary,
  );

  static TextTheme get _darkTextTheme {
    return const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
  }

  static TextTheme get _lightTextTheme {
    return const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.labelMedium,
      labelSmall: AppTextStyles.labelSmall,
    ).apply(
      bodyColor: AppColors.lightTextPrimary,
      displayColor: AppColors.lightTextPrimary,
    );
  }
}
