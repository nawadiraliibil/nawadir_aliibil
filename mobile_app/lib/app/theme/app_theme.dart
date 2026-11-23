import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shapes.dart';
import 'app_typography.dart';

/// سمة التطبيق بالوضعين، مبنية من رموز التصميم المعتمد.
///
/// تُضبط مكونات Material نفسها (الأزرار، الحقول، الشرائح، الحوارات) لتظهر
/// بالأسلوب المعتمد دون أغلفة، فتستخدم الشاشات `FilledButton` و`TextField`
/// و`ChoiceChip` مباشرة.
abstract final class AppTheme {
  static final ThemeData light = _build(AppColors.light, Brightness.light);
  static final ThemeData dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final textTheme = AppTypography.textTheme(text: c.text, muted: c.muted);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.button,
      onPrimary: c.buttonText,
      primaryContainer: c.tintGold,
      onPrimaryContainer: c.gold,
      secondary: c.gold,
      onSecondary: c.bg,
      // الزر الثانوي (`.btn.outline`): تعبئة هادئة بلا إطار.
      secondaryContainer: c.soft,
      onSecondaryContainer: c.text,
      tertiary: c.info,
      onTertiary: c.bg,
      tertiaryContainer: c.tintBlue,
      onTertiaryContainer: c.info,
      error: c.error,
      onError: c.bg,
      errorContainer: c.tintRed,
      onErrorContainer: c.error,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.soft,
      surfaceContainerHighest: c.soft,
      outline: c.line,
      outlineVariant: c.line,
      shadow: c.shadow,
      scrim: const Color(0x55111B1C),
    );

    const stadium = StadiumBorder();
    const buttonSize = Size(64, AppShapes.minTouchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 11);

    OutlineInputBorder fieldBorder() => const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppShapes.field)),
      borderSide: BorderSide.none,
    );
    // عند التركيز والخطأ: خط سفلي بسمك 2 فوق التعبئة ذات الزوايا المدورة.
    UnderlineInputBorder fieldUnderline(Color color) => UnderlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppShapes.field)),
      borderSide: BorderSide(color: color, width: 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.body,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.hair,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: c.text, size: 22),
      ),
      iconTheme: IconThemeData(color: c.text, size: 20),
      // لا تُضبط الألوان هنا: هذا النمط يسري على `FilledButton` و
      // `FilledButton.tonal` معًا، وضبطها يجعل الثانوي بلون الرئيسي. الألوان
      // تأتي من المخطط: primary للرئيسي و secondaryContainer للثانوي.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: stadium,
          side: BorderSide(color: c.line),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: stadium,
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size.square(AppShapes.minTouchTarget),
          shape: const CircleBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.soft,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        constraints: const BoxConstraints(minHeight: AppShapes.minTouchTarget),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: c.muted.withValues(alpha: 0.8),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: c.muted),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(color: c.gold),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: c.error),
        errorMaxLines: 3,
        helperMaxLines: 3,
        border: fieldBorder(),
        enabledBorder: fieldBorder(),
        disabledBorder: fieldBorder(),
        focusedBorder: fieldUnderline(c.gold),
        errorBorder: fieldUnderline(c.error),
        focusedErrorBorder: fieldUnderline(c.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.soft,
        selectedColor: c.tintGold,
        disabledColor: c.soft.withValues(alpha: 0.5),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShapes.chip)),
        ),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      dividerTheme: DividerThemeData(color: c.hair, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShapes.dialog)),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppShapes.sheetRadius,
        ),
        showDragHandle: true,
        dragHandleColor: c.line,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.button,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.buttonText),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppShapes.note)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.gold,
        linearTrackColor: c.soft,
        circularTrackColor: c.line,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.gold : c.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.gold
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.bg),
        side: BorderSide(color: c.muted, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.gold : c.muted,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.gold,
        textColor: c.text,
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall,
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      ),
    );
  }
}
