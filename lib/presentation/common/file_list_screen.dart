import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/byte_formatter.dart';
import '../../domain/scan/volume_scan.dart';
import 'category_style.dart';

/// Liste de fichiers, informative uniquement : aucune action sur les fichiers.
class FileListScreen extends StatelessWidget {
  const FileListScreen({
    super.key,
    required this.title,
    required this.files,
    this.footnote,
  });

  final String title;
  final List<FileEntry> files;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: files.isEmpty
            ? const Center(child: Text('Aucun fichier.'))
            : ListView.builder(
                itemCount: files.length + (footnote == null ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i == files.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        footnote!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return FileTile(file: files[i]);
                },
              ),
      ),
    );
  }
}

class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file});

  final FileEntry file;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(file.category.icon),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(file.folder, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatBytes(file.size),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () => showFileDetails(context, file),
    );
  }
}

Future<void> showFileDetails(BuildContext context, FileEntry file) {
  final modified = file.modified?.toLocal();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(file.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailRow('Taille', '${formatBytes(file.size)} (${file.size} octets)'),
            _DetailRow('Type', file.category.label),
            _DetailRow('Emplacement', file.folder),
            if (modified != null)
              _DetailRow(
                'Modifié le',
                '${_two(modified.day)}/${_two(modified.month)}/${modified.year} '
                    'à ${_two(modified.hour)}:${_two(modified.minute)}',
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.relativePath));
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copier le chemin'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(value, style: text.bodyLarge),
        ],
      ),
    );
  }
}
