import 'package:flutter/material.dart';

/// Shares the top slot with feedback popups without blocking the app beneath it.
class UpdateActivityOverlay extends StatelessWidget {
  const UpdateActivityOverlay({
    super.key,
    required this.workerUpdating,
    required this.appUpdating,
    this.percent,
    this.feedbackVisible = false,
  });

  final bool workerUpdating;
  final bool appUpdating;
  final int? percent;
  final bool feedbackVisible;

  @override
  Widget build(BuildContext context) {
    if (feedbackVisible) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        WorkerUpdateBanner(active: workerUpdating),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: UpdateActivityIndicator(
                active: !workerUpdating && appUpdating,
                label: 'Updating Yutaka…',
                percent: percent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Persistent update feedback with the same placement and style as top popups.
class WorkerUpdateBanner extends StatelessWidget {
  const WorkerUpdateBanner({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final reduceMotion = media.disableAnimations;
    final desktop = switch (theme.platform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };
    final surface = Color.alphaBlend(
      scheme.primary.withOpacity(dark ? .08 : .055),
      dark ? scheme.surfaceContainerHigh : scheme.surface,
    );

    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, desktop ? 14 : 10, 12, 0),
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
              reverseDuration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                if (reduceMotion) return child;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -.18), end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: !active
                  ? const SizedBox.shrink(key: ValueKey('worker-update-idle'))
                  : Semantics(
                      key: const ValueKey('worker-update-active'),
                      liveRegion: true,
                      label: 'Updating Worker. Installing the latest update.',
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            key: const ValueKey('worker-update-card'),
                            width: double.infinity,
                            constraints: BoxConstraints(minHeight: 68, maxWidth: desktop ? 500 : 520),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: surface.withOpacity(.985),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: scheme.primary.withOpacity(dark ? .28 : .22)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(dark ? .30 : .14),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withOpacity(.14),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: scheme.primary.withOpacity(.22)),
                                  ),
                                  child: Center(
                                    child: RepaintBoundary(
                                      child: SizedBox(
                                        width: 21,
                                        height: 21,
                                        child: reduceMotion
                                            ? Icon(Icons.sync_rounded, color: scheme.primary, size: 21)
                                            : CircularProgressIndicator(strokeWidth: 2.2, color: scheme.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Updating Worker',
                                        softWrap: true,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Installing the latest update…',
                                        softWrap: true,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                          height: 1.18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

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
