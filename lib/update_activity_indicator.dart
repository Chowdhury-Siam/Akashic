import 'package:flutter/material.dart';

/// Shares the top slot with feedback popups without blocking the app beneath it.
class UpdateActivityOverlay extends StatelessWidget {
  const UpdateActivityOverlay({
    super.key,
    required this.workerUpdating,
    required this.appUpdating,
    this.percent,
    this.appInstalling = false,
    this.installationMessage = 'Preparing the installer…',
    this.onDismissInstallation,
    this.feedbackVisible = false,
  });

  final bool workerUpdating;
  final bool appUpdating;
  final int? percent;
  final bool appInstalling;
  final String installationMessage;
  final VoidCallback? onDismissInstallation;
  final bool feedbackVisible;

  @override
  Widget build(BuildContext context) {
    if (feedbackVisible) return const SizedBox.shrink();
    if (workerUpdating) return const WorkerUpdateBanner(active: true);
    final title = appInstalling
        ? 'Installing Yutaka'
        : percent == null ? 'Updating Yutaka…' : 'Updating Yutaka… ${percent!.clamp(0, 100)}%';
    final message = appInstalling ? installationMessage : 'Downloading the latest update…';
    return UpdateProgressBanner(
      active: appUpdating || appInstalling,
      kind: appInstalling ? 'app-install' : 'app-download',
      title: title,
      message: message,
      semanticLabel: '$title. $message',
      onDismiss: appInstalling ? onDismissInstallation : null,
    );
  }
}

/// Persistent Worker feedback using the shared top popup layout.
class WorkerUpdateBanner extends StatelessWidget {
  const WorkerUpdateBanner({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => UpdateProgressBanner(
        active: active,
        kind: 'worker',
        title: 'Updating Worker',
        message: 'Installing the latest update…',
        semanticLabel: 'Updating Worker. Installing the latest update.',
      );
}

/// One safe-area card for downloads, installation and Worker deployment.
class UpdateProgressBanner extends StatelessWidget {
  const UpdateProgressBanner({
    super.key,
    required this.active,
    required this.kind,
    required this.title,
    required this.message,
    required this.semanticLabel,
    this.onDismiss,
  });

  final bool active;
  final String kind;
  final String title;
  final String message;
  final String semanticLabel;
  final VoidCallback? onDismiss;

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
      ignoring: onDismiss == null,
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
                  ? SizedBox.shrink(key: ValueKey('$kind-update-idle'))
                  : Semantics(
                      key: ValueKey('$kind-update-active'),
                      container: true,
                      liveRegion: true,
                      label: semanticLabel,
                      onTap: onDismiss,
                      hint: onDismiss == null ? null : 'Dismiss update progress. Installation continues.',
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            key: ValueKey('$kind-update-card'),
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
                                        title,
                                        softWrap: true,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        message,
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
                                if (onDismiss != null) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Dismiss update progress',
                                    onPressed: onDismiss,
                                    icon: const Icon(Icons.close_rounded),
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
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
