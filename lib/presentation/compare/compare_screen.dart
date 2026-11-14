import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../data/scan/isolate_scanner.dart';
import '../../domain/scan/file_category.dart';
import '../../domain/scan/scan_progress.dart';
import '../../domain/scan/volume_scan.dart';
import '../../domain/storage_volume_info.dart';
import '../common/size_bar.dart';
import '../scan/scan_controller.dart';

typedef CrossComparer = BackgroundJob<List<CrossVolumeMatch>> Function(
  VolumeScan a,
  VolumeScan b,
);

/// Compare deux supports : occupation, catégories, et fichiers identiques
/// présents sur les deux (contenu vérifié octet par octet).
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    required this.volumes,
    required this.scans,
    this.comparer = startCrossVolumeComparison,
  });

  final List<StorageVolumeInfo> volumes;
  final ScanController scans;
  final CrossComparer comparer;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late String _a = widget.volumes.first.id;
  late String _b = widget.volumes.length > 1 ? widget.volumes[1].id : _a;

  BackgroundJob<List<CrossVolumeMatch>>? _job;
  ScanProgress? _progress;
  List<CrossVolumeMatch>? _matches;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final v in widget.volumes) {
      unawaited(widget.scans.ensureLoaded(v.id));
    }
  }

  @override
  void dispose() {
    _job?.cancel();
    super.dispose();
  }

  StorageVolumeInfo _volume(String id) =>
      widget.volumes.firstWhere((v) => v.id == id);

  void _select({String? a, String? b}) {
    _job?.cancel();
    setState(() {
      _a = a ?? _a;
      _b = b ?? _b;
      _job = null;
      _matches = null;
      _progress = null;
      _error = null;
    });
  }

  Future<void> _findCommon(VolumeScan a, VolumeScan b) async {
    final job = widget.comparer(a, b);
    setState(() {
      _job = job;
      _matches = null;
      _error = null;
      _progress = null;
    });
    final sub = job.progress.listen((p) {
      if (mounted && identical(_job, job)) setState(() => _progress = p);
    });
    try {
      final matches = await job.result;
      if (mounted && identical(_job, job)) setState(() => _matches = matches);
    } on ScanCancelledException {
      // Annulé par l'utilisateur ou par un changement de sélection.
    } on Object {
      if (mounted && identical(_job, job)) {
        setState(() => _error = 'La comparaison n\'a pas pu aboutir.');
      }
    } finally {
      await sub.cancel();
      if (mounted && identical(_job, job)) setState(() => _job = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer deux supports')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.scans,
          builder: (context, _) {
            final volA = _volume(_a);
            final volB = _volume(_b);
            final scanA = widget.scans.scanOf(_a);
            final scanB = widget.scans.scanOf(_b);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _picker('Support A', _a, (id) => _select(a: id)),
                const SizedBox(height: 12),
                _picker('Support B', _b, (id) => _select(b: id)),
                const SizedBox(height: 16),
                if (_a == _b)
                  const Text('Choisissez deux supports différents.')
                else ...[
                  _ComparisonTable(volA: volA, volB: volB, scanA: scanA, scanB: scanB),
                  if (scanA == null || scanB == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Analysez ${scanA == null ? volA.label : volB.label} '
                        'pour comparer le détail des fichiers.',
                      ),
                    )
                  else
                    _commonSection(scanA, scanB, volA, volB),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _picker(String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final v in widget.volumes)
          DropdownMenuItem(value: v.id, child: Text(v.label)),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }

  Widget _commonSection(
    VolumeScan a,
    VolumeScan b,
    StorageVolumeInfo volA,
    StorageVolumeInfo volB,
  ) {
    final job = _job;
    final matches = _matches;
    final children = <Widget>[
      const SectionTitle('Fichiers présents sur les deux supports'),
    ];

    if (job != null) {
      final fraction = _progress?.duplicateFraction;
      children.addAll([
        LinearProgressIndicator(value: fraction),
        const SizedBox(height: 8),
        Text(fraction == null
            ? 'Préparation…'
            : '${(fraction * 100).round()} % du contenu comparé'),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: job.cancel, child: const Text('Annuler')),
      ]);
    } else if (matches == null) {
      children.addAll([
        Text(
          'Cherche les fichiers de 1 Mo et plus au contenu identique sur '
          '${volA.label} et ${volB.label}. Les deux supports doivent être '
          'branchés.',
        ),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _findCommon(a, b),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Chercher les fichiers communs'),
        ),
      ]);
    } else if (matches.isEmpty) {
      children.add(const Text('Aucun fichier identique sur les deux supports.'));
    } else {
      final bytesOnB = matches.fold(0, (s, m) => s + m.size * m.pathsB.length);
      children.add(Text(
        '${matches.length} fichier${matches.length > 1 ? 's' : ''} en commun · '
        '${formatBytes(bytesOnB)} sur ${volB.label} existent aussi sur ${volA.label}',
      ));
      children.add(const SizedBox(height: 8));
      for (final m in matches.take(200)) {
        children.add(Card(
          child: ListTile(
            title: Text(m.pathsA.first, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('↔ ${m.pathsB.first}', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: Text(formatBytes(m.size)),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.volA,
    required this.volB,
    required this.scanA,
    required this.scanB,
  });

  final StorageVolumeInfo volA;
  final StorageVolumeInfo volB;
  final VolumeScan? scanA;
  final VolumeScan? scanB;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String)>[
      ('Capacité', formatBytes(volA.totalBytes), formatBytes(volB.totalBytes)),
      ('Utilisé', formatBytes(volA.usedBytes), formatBytes(volB.usedBytes)),
      ('Libre', formatBytes(volA.freeBytes), formatBytes(volB.freeBytes)),
      if (scanA != null || scanB != null) ...[
        for (final c in FileCategory.values)
          if ((scanA?.category(c).count ?? 0) + (scanB?.category(c).count ?? 0) > 0)
            (c.label, _cat(scanA, c), _cat(scanB, c)),
        ('Doublons (copies)', _dup(scanA), _dup(scanB)),
      ],
    ];
    final header = Theme.of(context).textTheme.labelLarge;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.3),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              const SizedBox(),
              _cell(volA.label, header, align: TextAlign.end),
              _cell(volB.label, header, align: TextAlign.end),
            ]),
            for (final (label, a, b) in rows)
              TableRow(children: [
                _cell(label, null),
                _cell(a, null, align: TextAlign.end),
                _cell(b, null, align: TextAlign.end),
              ]),
          ],
        ),
      ),
    );
  }

  static String _cat(VolumeScan? scan, FileCategory c) =>
      scan == null ? '—' : formatBytes(scan.category(c).bytes);

  static String _dup(VolumeScan? scan) =>
      scan == null ? '—' : formatBytes(scan.duplicateExtraBytes);

  static Widget _cell(String text, TextStyle? style, {TextAlign? align}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: style, textAlign: align, maxLines: 2, overflow: TextOverflow.ellipsis),
      );
}
