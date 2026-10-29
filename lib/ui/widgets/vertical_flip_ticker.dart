import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trap_dash_arena/autoload/palette.dart';

class VerticalFlipTicker extends StatefulWidget {
  final List<String>? messages;
  final Duration interval;
  final TextStyle? textStyle;
  final double? width;
  final double height;

  const VerticalFlipTicker({
    super.key,
    this.messages,
    this.interval = const Duration(milliseconds: 3500),
    this.textStyle,
    this.width,
    this.height = 36.0,
  });

  static const List<String> defaultMessages = [
    'TIP: CRACKED TILES CRUMBLE IN 0.3 SECONDS',
    'WARNING: SAW BLADES DO NOT NEGOTIATE',
    'PRO TIP: THAT EXIT PORTAL MIGHT BE A TRAP',
    'HINT: CHECKPOINTS RESTORE YOUR DIGNITY',
    'FACT: SOME CEILINGS HAVE GRAVITY ISSUES',
    'NOTICE: PROXIMITY SPIKES SMELL FEAR',
    'RAGE ADVISORY: THROWING PHONE VOIDS WARRANTY',
  ];

  @override
  State<VerticalFlipTicker> createState() => _VerticalFlipTickerState();
}

class _VerticalFlipTickerState extends State<VerticalFlipTicker> {
  late List<String> _messages;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _messages = (widget.messages != null && widget.messages!.isNotEmpty)
        ? widget.messages!
        : VerticalFlipTicker.defaultMessages;

    if (_messages.length > 1) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _messages.length;
      });
    });
  }

  @override
  void didUpdateWidget(covariant VerticalFlipTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages != oldWidget.messages) {
      _messages = (widget.messages != null && widget.messages!.isNotEmpty)
          ? widget.messages!
          : VerticalFlipTicker.defaultMessages;
      _currentIndex = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        const TextStyle(
          fontFamily: 'AtkinsonHyperlegible',
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppPalette.playerBlack,
          letterSpacing: 0.5,
        );

    final currentText = _messages[_currentIndex];

    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppPalette.cardYellow.withValues(alpha: 0.65),
        border: Border.all(color: AppPalette.brownSolid, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutQuad,
        switchOutCurve: Curves.easeInQuad,
        transitionBuilder: (child, animation) {
          final inAnimation = Tween<Offset>(
            begin: const Offset(0.0, 1.2),
            end: Offset.zero,
          ).animate(animation);

          final outAnimation = Tween<Offset>(
            begin: const Offset(0.0, -1.2),
            end: Offset.zero,
          ).animate(animation);

          return ClipRect(
            child: SlideTransition(
              position: animation.status == AnimationStatus.completed ||
                      animation.status == AnimationStatus.forward
                  ? inAnimation
                  : outAnimation,
              child: child,
            ),
          );
        },
        child: Text(
          currentText,
          key: ValueKey<int>(_currentIndex),
          style: style,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
