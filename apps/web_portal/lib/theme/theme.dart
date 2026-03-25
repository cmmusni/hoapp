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

  static const _brand = FlexSchemeColor(
    primary: Color(0xff215e3f),
    primaryContainer: Color(0xFFA5D6A7),
    secondary: Color(0xFF558B2F),
    secondaryContainer: Color(0xFFC5E1A5),
  );

  static final ThemeData lightTheme = FlexThemeData.light(
    colors: _brand,
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

  static final ThemeData darkTheme = FlexThemeData.dark(
    colors: _brand,
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
