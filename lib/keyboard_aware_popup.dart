import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Moves a fixed-size popup when the IME covers its focused input.
///
/// Layout constraints stay unchanged: this is a paint translation, not a
/// scroll view or a keyboard-triggered scale-down. Lower form sections can
/// move above the keyboard while earlier sections temporarily leave the view.
class KeyboardAwarePopup extends StatefulWidget {
  const KeyboardAwarePopup({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardAwarePopup> createState() => _KeyboardAwarePopupState();
}

class _KeyboardAwarePopupState extends State<KeyboardAwarePopup>
    with WidgetsBindingObserver {
  double _offset = 0;
  bool _checkPending = false;
  final List<Timer> _settleTimers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_scheduleChecks);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleChecks();
  }

  @override
  void didChangeMetrics() => _scheduleChecks();

  void _scheduleChecks() {
    if (!mounted) return;
    _queueCheck();
    for (final timer in _settleTimers) {
      timer.cancel();
    }
    _settleTimers.clear();
    // Recheck after the popup alignment and keyboard opening animations settle.
    for (final delay in [120, 280, 480]) {
      _settleTimers.add(Timer(Duration(milliseconds: delay), _queueCheck));
    }
  }

  void _queueCheck() {
    if (!mounted || _checkPending) return;
    _checkPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPending = false;
      if (mounted) _updatePosition();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _updatePosition() {
    final media = MediaQuery.of(context);
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    double nextOffset = 0;
    if (media.viewInsets.bottom > 0 &&
        focusedContext != null &&
        focusedContext.mounted &&
        focusedContext.findAncestorStateOfType<_KeyboardAwarePopupState>() == this) {
      final target = focusedContext.findRenderObject();
      if (target is RenderBox && target.attached && target.hasSize) {
        final top = target.localToGlobal(Offset.zero).dy - _offset;
        final bottom = target.localToGlobal(Offset(0, target.size.height)).dy - _offset;
        final keyboardTop = media.size.height - media.viewInsets.bottom;
        // Include the field decoration, normal form spacing and nearby footer.
        // Keep the focused input itself below the status bar on short screens.
        nextOffset = math.min(0.0, keyboardTop - 128 - bottom);
        final view = View.of(context);
        final safeTop = math.max(media.padding.top, view.viewPadding.top / view.devicePixelRatio);
        nextOffset = math.min(0.0, math.max(nextOffset, safeTop + 12 - top));
      }
    }
    if ((nextOffset - _offset).abs() > .5) {
      setState(() => _offset = nextOffset);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleChecks);
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _settleTimers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: Offset(0, _offset), child: widget.child);
  }
}
