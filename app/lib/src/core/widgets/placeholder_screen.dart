import 'package:coin_pilot/src/core/l10n/l10n.dart';
import 'package:coin_pilot/src/core/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// Stand-in for screens that arrive in a later roadmap phase.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.phase,
    this.icon = Icons.construction_outlined,
    super.key,
  });

  final String title;

  /// Roadmap phase that delivers this screen (see docs/architecture.md).
  final int phase;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PlaceholderBody(phase: phase, icon: icon),
    );
  }
}

/// The body of [PlaceholderScreen], for tabs that own their own app bar.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({required this.phase, this.icon = Icons.construction_outlined, super.key});

  final int phase;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: context.l10n.comingSoonTitle,
      body: context.l10n.comingSoonBody(phase),
    );
  }
}
