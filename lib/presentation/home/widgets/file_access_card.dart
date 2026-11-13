import 'package:flutter/material.dart';

/// Explique l'accès complet aux fichiers et permet de l'accorder.
class FileAccessCard extends StatelessWidget {
  const FileAccessCard({
    super.key,
    required this.granted,
    required this.onRequest,
  });

  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (granted) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.verified_user_outlined, color: scheme.primary),
          title: const Text('Accès aux fichiers accordé'),
          subtitle: const Text('Utilisé uniquement en lecture.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Accès aux fichiers requis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Pour mesurer documents, téléchargements, archives et APK, "
              "Android exige l'autorisation « Accès à tous les fichiers ». "
              "Android l'accorde aussi en écriture, mais l'application ne "
              "contient aucun code capable de modifier, déplacer ou supprimer "
              "un fichier.",
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRequest,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Ouvrir les paramètres'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
