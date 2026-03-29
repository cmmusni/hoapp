import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// HOApp brand theme using FlexColorScheme with Material 3.
///
/// ```dart
/// // Light theme
/// final light = FlexThemeData.light(
///   colors: const FlexSchemeColor(
///     primary:   Color(0xff215e3f),
///     primaryContainer: Color(0xFFA5D6A7),
///     secondary: Color(0xFF558B2F),
///     secondaryContainer: Color(0xFFC5E1A5),
///   ),
///   useMaterial3: true,
///   fontFamily: 'Roboto',
/// );
/// ```
class HOAppTheme {
  HOAppTheme._();

  static const _defaultBrand = FlexSchemeColor(
    primary: Color(0xff215e3f),
    primaryContainer: Color(0xFFA5D6A7),
    secondary: Color(0xFF558B2F),
    secondaryContainer: Color(0xFFC5E1A5),
  );

  /// Build a light theme from a dynamic primary color.
  static ThemeData buildLight({Color? primaryColor}) {
    final brand = primaryColor != null
        ? FlexSchemeColor(
            primary: primaryColor,
            primaryContainer: Color.alphaBlend(
              primaryColor.withValues(alpha: 0.3),
              const Color(0xFFFFFFFF),
            ),
            secondary: _defaultBrand.secondary,
            secondaryContainer: _defaultBrand.secondaryContainer,
          )
        : _defaultBrand;
    return FlexThemeData.light(
      colors: brand,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarStyle: FlexAppBarStyle.primary,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        blendOnColors: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 10,
        chipRadius: 20,
        cardRadius: 12,
        dialogRadius: 16,
        fabRadius: 16,
      ),
    );
  }

  static final ThemeData lightTheme = buildLight();

  static final ThemeData darkTheme = FlexThemeData.dark(
    colors: _defaultBrand,
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarStyle: FlexAppBarStyle.material,
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      blendOnColors: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorRadius: 10,
      chipRadius: 20,
      cardRadius: 12,
      dialogRadius: 16,
      fabRadius: 16,
    ),
  );
}
