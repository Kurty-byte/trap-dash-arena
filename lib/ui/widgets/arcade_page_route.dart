import 'package:flutter/material.dart';

/// An instantaneous zero-delay [PageRouteBuilder] for arcade screen navigation.
class ArcadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ArcadePageRoute({
    required this.page,
    Duration duration = Duration.zero,
    super.settings,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
        );
}

/// A [PageTransitionsBuilder] for configuring global instantaneous arcade navigation in [ThemeData.pageTransitionsTheme].
class ArcadePageTransitionsBuilder extends PageTransitionsBuilder {
  const ArcadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
