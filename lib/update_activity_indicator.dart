import 'package:flutter/material.dart';

/// Small, non-blocking feedback for updates running while the user uses the app.
class UpdateActivityIndicator extends StatelessWidget {
  const UpdateActivityIndicator({
    super.key,
    required this.active,
    required this.label,
    this.percent,
  });

  final bool active;
  final String label;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -.12), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: !active
            ? const SizedBox.shrink(key: ValueKey('update-idle'))
            : Semantics(
                key: const ValueKey('update-active'),
                liveRegion: true,
                label: label,
                child: ExcludeSemantics(
                  child: Material(
                    color: scheme.surfaceContainerHigh,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.primary.withOpacity(.24)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: reduceMotion
                                  ? Icon(Icons.sync_rounded, size: 18, color: scheme.primary)
                                  : CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              percent == null ? label : '$label ${percent!.clamp(0, 100)}%',
                              softWrap: true,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
