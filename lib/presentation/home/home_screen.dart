import 'package:material_ui/material_ui.dart';

import '../../core/format/date_formatter.dart';
import '../privacy/privacy_screen.dart';
import 'home_controller.dart';
import 'widgets/categories_placeholder_card.dart';
import 'widgets/file_access_card.dart';
import 'widgets/primary_volume_card.dart';
import 'widgets/secondary_volume_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
  });

  final HomeController controller;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockage'),
        actions: [
          IconButton(
            tooltip: 'Confidentialité',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => switch (controller.state) {
            HomeLoading() => const Center(child: CircularProgressIndicator()),
            HomeError(:final message) =>
              _ErrorView(message: message, onRetry: controller.load),
            final HomeLoaded loaded => _LoadedView(
                state: loaded,
                now: clock(),
                onAnalyze: controller.analyze,
                onRequestAccess: () => _requestAccess(context),
              ),
          },
        ),
      ),
    );
  }

  Future<void> _requestAccess(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await controller.requestFullAccess();
    if (!opened) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          "Écran introuvable. Ouvrez Paramètres > Applications > Storage Lens "
          "> Accès à tous les fichiers.",
        ),
      ));
    }
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.now,
    required this.onAnalyze,
    required this.onRequestAccess,
  });

  final HomeLoaded state;
  final DateTime now;
  final VoidCallback onAnalyze;
  final VoidCallback onRequestAccess;

  @override
  Widget build(BuildContext context) {
    final primary = state.primary;
    final textTheme = Theme.of(context).textTheme;
    final lastScan = state.lastScan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (primary == null)
          const _EmptyVolumesCard()
        else
          PrimaryVolumeCard(volume: primary),
        for (final volume in state.secondary) ...[
          const SizedBox(height: 12),
          SecondaryVolumeTile(volume: volume),
        ],
        const SizedBox(height: 12),
        FileAccessCard(
          granted: state.hasFullAccess,
          onRequest: onRequestAccess,
        ),
        const SizedBox(height: 12),
        const CategoriesPlaceholderCard(),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: state.isRefreshing ? null : onAnalyze,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: state.isRefreshing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(state.isRefreshing ? 'Analyse…' : 'Analyser'),
        ),
        const SizedBox(height: 12),
        Text(
          lastScan == null
              ? 'Aucune analyse effectuée'
              : 'Dernière analyse : ${formatLastScan(lastScan, now: now)}',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyVolumesCard extends StatelessWidget {
  const _EmptyVolumesCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.sd_card_alert_outlined),
        title: Text('Aucun volume lisible'),
        subtitle: Text("Le système n'a renvoyé aucun stockage monté."),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
