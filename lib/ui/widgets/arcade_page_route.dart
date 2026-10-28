import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

/// Renders a snappy two-phase retro arcade Dip-to-Black transition.
///
/// Phase 1 (0.0 -> 0.5): Black curtain fades from 0.0 to 1.0 over the outgoing route,
/// keeping [child] at opacity 0.0 while it initializes and mounts offstage.
/// Phase 2 (0.5 -> 1.0): [child] flips to full opacity behind the solid black curtain,
/// and the curtain fades from 1.0 down to 0.0 to reveal the new screen.
Widget buildArcadeDipTransition({
  required Animation<double> animation,
  required bool isFirstRoute,
  required Widget child,
}) {
  if (isFirstRoute) {
    // Root replacement transition (e.g. pushAndRemoveUntil where previous routes were disposed)
    // Fades in cleanly from black (curtain 1.0 -> 0.0)
    final curtainOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOut),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: FadeTransition(
            opacity: curtainOpacity,
            child: const ColoredBox(color: AppPalette.playerBlack),
          ),
        ),
      ],
    );
  }

  final childVisibility = const _ChildVisibilityTween().animate(animation);
  final curtainOpacity = const _DipCurtainTween().animate(animation);

  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: childVisibility,
        child: child,
      ),
      IgnorePointer(
        child: FadeTransition(
          opacity: curtainOpacity,
          child: const ColoredBox(color: AppPalette.playerBlack),
        ),
      ),
    ],
  );
}

class _ChildVisibilityTween extends Animatable<double> {
  const _ChildVisibilityTween();

  @override
  double transform(double t) => t >= 0.5 ? 1.0 : 0.0;
}

class _DipCurtainTween extends Animatable<double> {
  const _DipCurtainTween();

  @override
  double transform(double t) {
    if (t < 0.5) {
      return (t * 2.0).clamp(0.0, 1.0);
    } else {
      return ((1.0 - t) * 2.0).clamp(0.0, 1.0);
    }
  }
}

/// A 100ms Dip-to-Black [PageRouteBuilder] for arcade screen navigation.
class ArcadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ArcadePageRoute({
    required this.page,
    Duration duration = const Duration(milliseconds: 100),
    super.settings,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final route = ModalRoute.of(context);
            final isFirst = route?.isFirst ?? false;
            return buildArcadeDipTransition(
              animation: animation,
              isFirstRoute: isFirst,
              child: child,
            );
          },
        );
}

/// A [PageTransitionsBuilder] for configuring global arcade Dip-to-Black in [ThemeData.pageTransitionsTheme].
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
    return buildArcadeDipTransition(
      animation: animation,
      isFirstRoute: route.isFirst,
      child: child,
    );
  }
}
