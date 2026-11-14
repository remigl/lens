import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../domain/scan/volume_scan.dart';

/// Groupes de fichiers strictement identiques. Aucune suppression proposée.
class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key, required this.scan, required this.minBytesLabel});

  final VolumeScan scan;
  final String minBytesLabel;

  @override
  Widget build(BuildContext context) {
    final groups = scan.duplicates;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Doublons')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              groups.isEmpty
                  ? 'Aucun doublon trouvé.'
                  : '${groups.length} groupe${groups.length > 1 ? 's' : ''} · '
                      '${formatBytes(scan.duplicateExtraBytes)} occupés par les copies',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Contenu comparé octet par octet. Le nom des fichiers n\'est '
              'jamais pris en compte. Fichiers de $minBytesLabel et plus.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final group in groups) _GroupCard(group: group),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final DuplicateGroup group;

  @override
  Widget build(BuildContext context) {
    final first = group.paths.first;
    final name = first.substring(first.lastIndexOf('/') + 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          title: Text(
            '${group.paths.length} fichiers identiques — ${formatBytes(group.totalBytes)}',
          ),
          subtitle: Text(
            '$name · ${formatBytes(group.size)} chacun',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            for (final path in group.paths)
              ListTile(
                dense: true,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: SelectableText(path),
              ),
          ],
        ),
      ),
    );
  }
}
