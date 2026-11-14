import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../core/format/date_formatter.dart';
import '../../domain/scan/file_category.dart';
import '../../domain/scan/scan_progress.dart';
import '../../domain/scan/volume_scan.dart';
import '../../domain/storage_volume_info.dart';
import '../common/category_style.dart';
import '../common/file_list_screen.dart';
import '../common/size_bar.dart';
import '../scan/scan_controller.dart';
import 'duplicates_screen.dart';
import 'folder_screen.dart';

/// Analyse détaillée d'un volume (téléphone, carte SD, clé USB…).
class VolumeScreen extends StatefulWidget {
  const VolumeScreen({
    super.key,
    required this.volume,
    required this.scans,
    required this.hasFullAccess,
    this.startImmediately = false,
    this.clock = DateTime.now,
  });

  final StorageVolumeInfo volume;
  final ScanController scans;
  final bool hasFullAccess;
  final bool startImmediately;
  final DateTime Function() clock;

  @override
  State<VolumeScreen> createState() => _VolumeScreenState();
}

class _VolumeScreenState extends State<VolumeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.scans.ensureLoaded(widget.volume.id).then((_) {
      if (widget.startImmediately && mounted) _start();
    }));
  }

  void _start() {
    final started = widget.scans.start(widget.volume);
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Une autre analyse est en cours.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.volume.label)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.scans,
          builder: (context, _) {
            final state = widget.scans.stateOf(widget.volume.id);
            return switch (state) {
              ScanNotLoaded() => const Center(child: CircularProgressIndicator()),
              ScanIdle() => _IdleView(
                  hasFullAccess: widget.hasFullAccess,
                  canScan: widget.volume.canBeScanned,
                  onStart: _start,
                ),
              ScanRunning(:final progress) => _RunningView(
                  progress: progress,
                  usedBytes: widget.volume.usedBytes,
                  onCancel: widget.scans.cancel,
                ),
              ScanDone(:final scan) => _ResultView(
                  volume: widget.volume,
                  scan: scan,
                  now: widget.clock(),
                  onRescan: _start,
                ),
              ScanFailed(:final message, :final previous) => previous == null
                  ? _MessageView(message: message, onRetry: _start)
                  : _ResultView(
                      volume: widget.volume,
                      scan: previous,
                      now: widget.clock(),
                      onRescan: _start,
                      error: message,
                    ),
            };
          },
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.hasFullAccess,
    required this.canScan,
    required this.onStart,
  });

  final bool hasFullAccess;
  final bool canScan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final String message;
    if (!canScan) {
      message = "Android n'indique pas d'emplacement lisible pour ce support.";
    } else if (!hasFullAccess) {
      message = "Accordez l'accès aux fichiers depuis l'écran d'accueil pour "
          'analyser ce support.';
    } else {
      message = "L'analyse parcourt les dossiers et lit la taille des "
          'fichiers, sans les ouvrir. Les doublons sont ensuite vérifiés '
          'octet par octet. Rien n\'est modifié.';
    }
    return _MessageView(
      message: message,
      actionLabel: "Lancer l'analyse",
      onRetry: canScan && hasFullAccess ? onStart : null,
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    this.onRetry,
    this.actionLabel = 'Réessayer',
  });

  final String message;
  final VoidCallback? onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
              icon: const Icon(Icons.search),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.progress,
    required this.usedBytes,
    required this.onCancel,
  });

  final ScanProgress? progress;
  final int usedBytes;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final text = Theme.of(context).textTheme;
    final String title;
    final String detail;
    final double? value;

    if (p == null) {
      title = 'Démarrage…';
      detail = '';
      value = null;
    } else if (p.phase == ScanPhase.listing) {
      title = 'Parcours des fichiers';
      detail = '${filesLabel(p.filesSeen)} · ${formatBytes(p.bytesSeen)}';
      // Repère réel : l'espace utilisé du volume. Les données système non
      // lisibles font que la barre n'atteint pas toujours 100 %.
      value = usedBytes > 0 ? (p.bytesSeen / usedBytes).clamp(0.0, 1.0) : null;
    } else {
      title = 'Vérification des doublons';
      detail = '${formatBytes(p.duplicateBytesChecked)} sur '
          '${formatBytes(p.duplicateBytesToCheck)} comparés';
      value = p.duplicateFraction;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleLarge),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: value, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Text(detail, style: text.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.volume,
    required this.scan,
    required this.now,
    required this.onRescan,
    this.error,
  });

  final StorageVolumeInfo volume;
  final VolumeScan scan;
  final DateTime now;
  final VoidCallback onRescan;
  final String? error;

  static const _minDuplicateLabel = '1 Mo';

  void _push(BuildContext context, Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final total = scan.total;
    final unmeasured = volume.usedBytes - total.bytes;
    final categories = scan.sortedCategories;
    final maxCategory = categories.isEmpty ? 0 : scan.category(categories.first).bytes;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (error != null)
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
              title: Text(error!, style: TextStyle(color: scheme.onErrorContainer)),
              subtitle: Text(
                'Résultats de l\'analyse précédente.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatBytes(total.bytes)} dans ${filesLabel(total.count)}',
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'sur ${formatBytes(volume.usedBytes)} utilisés',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (unmeasured > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${formatBytes(unmeasured)} non mesurables : système, '
                    'applications et leurs données privées (Android en '
                    'interdit la lecture).',
                    style: text.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Analysé ${formatLastScan(scan.scannedAt, now: now).replaceFirst("Aujourd'hui", "aujourd'hui").replaceFirst('Hier', 'hier')}'
                  ' en ${_duration(scan.duration)}',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Catégories'),
        Card(
          child: Column(
            children: [
              for (final c in categories)
                SizeBarTile(
                  icon: c.icon,
                  label: c.label,
                  subtitle: filesLabel(scan.category(c).count),
                  bytes: scan.category(c).bytes,
                  maxBytes: maxCategory,
                  onTap: () => _push(
                    context,
                    FileListScreen(
                      title: c.label,
                      files: scan.largestByCategory[c] ?? const [],
                      footnote: _largestFootnote(scan.category(c).count),
                    ),
                  ),
                ),
              if (categories.isEmpty)
                const ListTile(title: Text('Aucun fichier trouvé.')),
            ],
          ),
        ),
        const SectionTitle('Où chercher'),
        Card(
          child: Column(
            children: [
              _NavTile(
                icon: Icons.insert_drive_file_outlined,
                title: 'Fichiers volumineux',
                trailing: scan.largestFiles(limit: 1).isEmpty
                    ? null
                    : formatBytes(scan.largestFiles(limit: 1).first.size),
                subtitle: 'Les 100 plus gros fichiers',
                onTap: () => _push(
                  context,
                  FileListScreen(
                    title: 'Fichiers volumineux',
                    files: scan.largestFiles(),
                  ),
                ),
              ),
              _NavTile(
                icon: Icons.folder_outlined,
                title: 'Dossiers',
                subtitle: 'Taille de chaque dossier, sous-dossiers inclus',
                onTap: () => _push(
                  context,
                  FolderScreen(tree: scan.tree, volumeLabel: volume.label),
                ),
              ),
              _NavTile(
                icon: Icons.file_copy_outlined,
                title: 'Doublons',
                subtitle: scan.duplicates.isEmpty
                    ? 'Aucun fichier identique'
                    : '${scan.duplicates.length} groupe${scan.duplicates.length > 1 ? 's' : ''} de fichiers identiques',
                trailing: scan.duplicates.isEmpty
                    ? null
                    : formatBytes(scan.duplicateExtraBytes),
                onTap: () => _push(
                  context,
                  DuplicatesScreen(scan: scan, minBytesLabel: _minDuplicateLabel),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Emplacements particuliers'),
        Card(
          child: Column(
            children: [
              _StatTile(Icons.download_outlined, 'Téléchargements', scan.downloads),
              _StatTile(Icons.delete_outline, 'Corbeille', scan.trash),
              _StatTile(Icons.cached_outlined, 'Fichiers temporaires détectés', scan.temporary),
            ],
          ),
        ),
        const SectionTitle("Limites de l'analyse"),
        Card(child: _IssuesTile(issues: scan.issues)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRescan,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.refresh),
          label: const Text("Relancer l'analyse"),
        ),
      ],
    );
  }

  static String? _largestFootnote(int count) =>
      count > 100 ? 'Seuls les 100 plus gros fichiers sont listés.' : null;

  static String _duration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} s';
    return '${d.inMinutes} min ${d.inSeconds % 60} s';
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.title, this.stat);

  final IconData icon;
  final String title;
  final SizeStat stat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(filesLabel(stat.count)),
      trailing: Text(
        formatBytes(stat.bytes),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IssuesTile extends StatelessWidget {
  const _IssuesTile({required this.issues});

  final ScanIssues issues;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (final dir in issues.protectedDirs)
        '$dir : protégé par Android, non analysé.',
      if (issues.unreadableDirs > 0)
        '${formatCount(issues.unreadableDirs)} dossier(s) illisible(s), ignoré(s).',
      if (issues.vanishedFiles > 0)
        '${filesLabel(issues.vanishedFiles)} disparu(s) pendant l\'analyse.',
      if (issues.skippedLinks > 0)
        '${formatCount(issues.skippedLinks)} lien(s) symbolique(s) non suivi(s).',
      if (issues.unreadableForDuplicates > 0)
        '${filesLabel(issues.unreadableForDuplicates)} non comparable(s) pour les doublons.',
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lines.isEmpty) const Text('Aucune restriction rencontrée.'),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $line'),
            ),
          const SizedBox(height: 4),
          Text(
            'Les données internes des applications ne sont jamais lisibles par '
            'une autre application : leur taille n\'apparaît pas ici.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Exposé pour l'écran d'accueil : résumé compact des catégories.
List<FileCategory> topCategories(VolumeScan scan, {int limit = 5}) {
  final sorted = scan.sortedCategories;
  return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
}
