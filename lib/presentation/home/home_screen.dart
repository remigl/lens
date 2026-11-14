import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../core/format/date_formatter.dart';
import '../../domain/storage_volume_info.dart';
import '../common/category_style.dart';
import '../common/size_bar.dart';
import '../compare/compare_screen.dart';
import '../privacy/privacy_screen.dart';
import '../scan/scan_controller.dart';
import '../volume/volume_screen.dart';
import 'home_controller.dart';
import 'widgets/file_access_card.dart';
import 'widgets/primary_volume_card.dart';
import 'widgets/secondary_volume_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.scans,
    this.clock = DateTime.now,
  });

  final HomeController controller;
  final ScanController scans;
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
          listenable: Listenable.merge([controller, scans]),
          builder: (context, _) => switch (controller.state) {
            HomeLoading() => const Center(child: CircularProgressIndicator()),
            HomeError(:final message) =>
              _ErrorView(message: message, onRetry: controller.load),
            final HomeLoaded loaded => _LoadedView(
                state: loaded,
                scans: scans,
                now: clock(),
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

class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.state,
    required this.scans,
    required this.now,
    required this.onRequestAccess,
  });

  final HomeLoaded state;
  final ScanController scans;
  final DateTime now;
  final VoidCallback onRequestAccess;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  @override
  void initState() {
    super.initState();
    _loadCachedScans();
  }

  @override
  void didUpdateWidget(_LoadedView old) {
    super.didUpdateWidget(old);
    _loadCachedScans();
  }

  void _loadCachedScans() {
    for (final v in widget.state.volumes) {
      unawaited(widget.scans.ensureLoaded(v.id));
    }
  }

  void _openVolume(StorageVolumeInfo volume, {bool start = false}) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => VolumeScreen(
        volume: volume,
        scans: widget.scans,
        hasFullAccess: widget.state.hasFullAccess,
        startImmediately: start,
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final primary = state.primary;
    final textTheme = Theme.of(context).textTheme;
    final scan = primary == null ? null : widget.scans.scanOf(primary.id);
    final running = primary != null && widget.scans.runningVolumeId == primary.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (primary == null)
          const _EmptyVolumesCard()
        else
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openVolume(primary),
            child: PrimaryVolumeCard(volume: primary),
          ),
        if (primary != null && scan != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final c in topCategories(scan))
                    SizeBarTile(
                      icon: c.icon,
                      label: c.label,
                      bytes: scan.category(c).bytes,
                      maxBytes: primary.usedBytes,
                    ),
                  if (primary.usedBytes > scan.total.bytes)
                    SizeBarTile(
                      icon: Icons.apps_outlined,
                      label: 'Système et applications',
                      subtitle: 'Non mesurable en détail',
                      bytes: primary.usedBytes - scan.total.bytes,
                      maxBytes: primary.usedBytes,
                    ),
                  TextButton(
                    onPressed: () => _openVolume(primary),
                    child: const Text('Voir le détail'),
                  ),
                ],
              ),
            ),
          ),
        ],
        for (final volume in state.secondary) ...[
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openVolume(volume),
            child: SecondaryVolumeTile(volume: volume),
          ),
        ],
        const SizedBox(height: 12),
        FileAccessCard(
          granted: state.hasFullAccess,
          onRequest: widget.onRequestAccess,
        ),
        const SizedBox(height: 24),
        if (primary != null)
          FilledButton.icon(
            onPressed: state.hasFullAccess && !widget.scans.isBusy
                ? () => _openVolume(primary, start: true)
                : running
                    ? () => _openVolume(primary)
                    : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: Icon(running ? Icons.hourglass_top : Icons.search),
            label: Text(running ? 'Analyse en cours…' : 'Analyser'),
          ),
        const SizedBox(height: 12),
        Text(
          scan == null
              ? 'Aucune analyse effectuée'
              : 'Dernière analyse : ${formatLastScan(scan.scannedAt, now: widget.now)}',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.volumes.length >= 2) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => CompareScreen(
                volumes: state.volumes,
                scans: widget.scans,
              ),
            )),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Comparer deux supports'),
          ),
        ],
        if (scan != null && primary != null) ...[
          const SizedBox(height: 8),
          Text(
            '${formatBytes(scan.duplicateExtraBytes)} occupés par des doublons',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
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
