import 'package:flutter/material.dart';

/// Breakpoint constants used across the app.
abstract final class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

enum ScreenSize { mobile, tablet, desktop }

/// Returns the current [ScreenSize] based on width.
ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.tablet) return ScreenSize.desktop;
  if (width >= Breakpoints.mobile) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

/// A widget that builds different layouts based on screen width.
///
/// Provide a [mobile] builder (required). [tablet] and [desktop] are optional
/// and fall back to the next smaller size.
class AdaptiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  const AdaptiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    return switch (size) {
      ScreenSize.desktop => (desktop ?? tablet ?? mobile)(context),
      ScreenSize.tablet => (tablet ?? mobile)(context),
      ScreenSize.mobile => mobile(context),
    };
  }
}
