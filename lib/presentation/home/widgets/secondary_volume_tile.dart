import 'package:material_ui/material_ui.dart';

import '../../../core/format/byte_formatter.dart';
import '../../../domain/storage_volume_info.dart';

class SecondaryVolumeTile extends StatelessWidget {
  const SecondaryVolumeTile({super.key, required this.volume});

  final StorageVolumeInfo volume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  volume.kind == VolumeKind.removable
                      ? Icons.sd_card_outlined
                      : Icons.storage_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(volume.label)),
                Text(
                  '${formatBytes(volume.usedBytes)} / '
                  '${formatBytes(volume.totalBytes)}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: volume.usedFraction,
                minHeight: 8,
                color: volume.isAlmostFull ? scheme.error : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                semanticsLabel: volume.label,
                semanticsValue: formatPercent(volume.usedFraction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
