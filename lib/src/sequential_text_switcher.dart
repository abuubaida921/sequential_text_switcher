import 'package:flutter/material.dart';

enum _AnimPhase { holding, exiting, entering }

class SequentialTextSwitcher extends StatefulWidget {
  const SequentialTextSwitcher({
    super.key,
    required this.texts,
    this.textStyle,
    this.holdDuration = const Duration(seconds: 2),
    this.exitDuration = const Duration(milliseconds: 500),
    this.enterDuration = const Duration(milliseconds: 300),
    this.exitOverlapFraction = 0.5,
    this.curve = const Cubic(0.65, 0, 0.35, 1),
  }) : assert(texts.length >= 2, 'texts must have at least 2 items');

  final List<String> texts;
  final TextStyle? textStyle;
  final Duration holdDuration;
  final Duration exitDuration;
  final Duration enterDuration;
  final double exitOverlapFraction;
  final Curve curve;

  @override
  State<SequentialTextSwitcher> createState() => _SequentialTextSwitcherState();
}

class _SequentialTextSwitcherState extends State<SequentialTextSwitcher>
    with TickerProviderStateMixin {
  late AnimationController _exitController;
  late AnimationController _enterController;
  late Animation<Offset> _exitAnim;
  late Animation<Offset> _enterAnim;

  int _currentIndex = 0;
  late String _visibleText;
  _AnimPhase _phase = _AnimPhase.holding;

  @override
  void initState() {
    super.initState();
    _visibleText = widget.texts.first;

    _exitController = AnimationController(
      vsync: this,
      duration: widget.exitDuration,
    );
    _enterController = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
    );

    _exitAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(parent: _exitController, curve: widget.curve));

    _enterAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterController, curve: widget.curve));

    _startCycle();
  }

  Future<void> _startCycle() async {
    while (mounted) {
      setState(() => _phase = _AnimPhase.holding);
      await Future.delayed(widget.holdDuration);
      if (!mounted) return;

      setState(() => _phase = _AnimPhase.exiting);

      bool enterStarted = false;
      _exitController.addListener(() {
        if (_exitController.value >= widget.exitOverlapFraction && !enterStarted) {
          enterStarted = true;
          setState(() {
            _currentIndex = (_currentIndex + 1) % widget.texts.length;
            _visibleText = widget.texts[_currentIndex];
            _phase = _AnimPhase.entering;
          });
          _enterController.forward();
        }
      });

      await _exitController.forward();
      if (!mounted) return;
      _exitController.reset();

      if (_enterController.isAnimating) {
        await _enterController.forward();
      }
      _enterController.reset();
    }
  }

  @override
  void didUpdateWidget(covariant SequentialTextSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exitDuration != widget.exitDuration) {
      _exitController.duration = widget.exitDuration;
    }
    if (oldWidget.enterDuration != widget.enterDuration) {
      _enterController.duration = widget.enterDuration;
    }
  }

  @override
  void dispose() {
    _exitController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<Offset> position = switch (_phase) {
      _AnimPhase.exiting => _exitAnim,
      _AnimPhase.entering => _enterAnim,
      _AnimPhase.holding => const AlwaysStoppedAnimation(Offset.zero),
    };

    return ClipRect(
      child: SlideTransition(
        position: position,
        child: Text(
          _visibleText,
          style: widget.textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}