import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Blurs the app while it is inactive so balances don't show in the app
/// switcher.
class PrivacyOverlay extends StatefulWidget {
  const PrivacyOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<PrivacyOverlay> createState() => _PrivacyOverlayState();
}

class _PrivacyOverlayState extends State<PrivacyOverlay> {
  late final AppLifecycleListener _listener;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onInactive: () => _set(obscured: true),
      onHide: () => _set(obscured: true),
      onResume: () => _set(obscured: false),
    );
  }

  void _set({required bool obscured}) {
    if (mounted && obscured != _obscured) setState(() => _obscured = obscured);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_obscured)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: ColoredBox(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6)),
            ),
          ),
      ],
    );
  }
}
