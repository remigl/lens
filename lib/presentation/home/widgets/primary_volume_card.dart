import 'package:flutter/material.dart';

import '../../../core/format/byte_formatter.dart';
import '../../../domain/storage_volume_info.dart';
import 'usage_ring.dart';

class PrimaryVolumeCard extends StatelessWidget {
  const PrimaryVolumeCard({super.key, required this.volume});

  final StorageVolumeInfo volume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = volume.isAlmostFull ? scheme.error : scheme.primary;
    final used = formatBytes(volume.usedBytes);
    final total = formatBytes(volume.totalBytes);
    final free = formatBytes(volume.freeBytes);

    return Card(
      child: Semantics(
        container: true,
        label: '${volume.label} : $used utilisés sur $total, $free libres',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(volume.label, style: text.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  UsageRing(
                    fraction: volume.usedFraction,
                    color: accent,
                    trackColor: scheme.surfaceContainerHighest,
                    child: Text(
                      formatPercent(volume.usedFraction),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$used utilisés',
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'sur $total',
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('$free libres', style: text.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
              if (volume.isAlmostFull) ...[
                const SizedBox(height: 16),
                _AlmostFullBanner(color: scheme.error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlmostFullBanner extends StatelessWidget {
  const _AlmostFullBanner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Stockage presque plein',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
