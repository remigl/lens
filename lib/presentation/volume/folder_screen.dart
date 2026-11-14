import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../domain/scan/volume_scan.dart';
import '../common/size_bar.dart';

/// Exploration des dossiers par taille cumulée (sous-dossiers inclus).
class FolderScreen extends StatelessWidget {
  const FolderScreen({
    super.key,
    required this.tree,
    required this.volumeLabel,
    this.index = 0,
  });

  final DirTree tree;
  final String volumeLabel;
  final int index;

  @override
  Widget build(BuildContext context) {
    final children = tree.childrenOf(index);
    final total = tree.totalBytes[index];
    final direct = tree.directBytes[index];
    final path = tree.pathOf(index);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? volumeLabel : tree.names[index]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatBytes(total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${filesLabel(tree.fileCounts[index])} · $path',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            for (final child in children)
              SizeBarTile(
                icon: Icons.folder_outlined,
                label: tree.names[child],
                subtitle: filesLabel(tree.fileCounts[child]),
                bytes: tree.totalBytes[child],
                maxBytes: total,
                onTap: tree.childrenOf(child).isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FolderScreen(
                              tree: tree,
                              volumeLabel: volumeLabel,
                              index: child,
                            ),
                          ),
                        ),
              ),
            if (direct > 0)
              SizeBarTile(
                icon: Icons.insert_drive_file_outlined,
                label: 'Fichiers de ce dossier',
                bytes: direct,
                maxBytes: total,
              ),
            if (children.isEmpty && direct == 0)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Dossier vide.'),
              ),
          ],
        ),
      ),
    );
  }
}
