import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';

/// Responsive breakpoint configuration for HOApp.
class AppResponsive {
  AppResponsive._();

  static const double mobile = 0;
  static const double tablet = 451;
  static const double desktop = 801;
  static const double fourK = 1921;

  static Widget builder(BuildContext context, Widget? child) {
    return ResponsiveBreakpoints.builder(
      child: child!,
      breakpoints: const [
        Breakpoint(start: mobile, end: 450, name: MOBILE),
        Breakpoint(start: tablet, end: 800, name: TABLET),
        Breakpoint(start: desktop, end: 1920, name: DESKTOP),
        Breakpoint(start: fourK, end: double.infinity, name: '4K'),
      ],
    );
  }

  static bool isMobile(BuildContext context) =>
      ResponsiveBreakpoints.of(context).isMobile;

  static bool isTablet(BuildContext context) =>
      ResponsiveBreakpoints.of(context).isTablet;

  static bool isDesktop(BuildContext context) =>
      ResponsiveBreakpoints.of(context).isDesktop;

  static bool isCompact(BuildContext context) =>
      isMobile(context) || isTablet(context);
}
