import 'package:material_ui/material_ui.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _items = [
    (
      Icons.cloud_off_outlined,
      'Aucune donnée envoyée',
      "L'application ne demande pas l'accès à Internet : rien ne peut quitter le téléphone.",
    ),
    (
      Icons.visibility_off_outlined,
      'Aucune donnée collectée',
      "Pas d'analytics, pas de suivi, pas de publicité, pas de télémétrie.",
    ),
    (
      Icons.person_off_outlined,
      'Aucun compte',
      "Aucune inscription ni connexion n'est nécessaire.",
    ),
    (
      Icons.phone_android_outlined,
      'Analyse locale',
      "Tous les calculs sont faits sur l'appareil. Les résultats restent dans "
          "l'espace privé de l'application et sont exclus des sauvegardes.",
    ),
    (
      Icons.lock_outline,
      'Lecture seule',
      "L'application ne supprime, ne déplace, ne modifie et ne partage aucun "
          "fichier.",
    ),
    (
      Icons.compare_outlined,
      'Contenu des fichiers',
      "L'analyse lit seulement les noms, tailles et dates. Pour confirmer un "
          "doublon, deux fichiers de même taille sont comparés octet par octet "
          "en mémoire : leur contenu n'est ni affiché, ni conservé.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final (icon, title, body) in _items)
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(body),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              ),
          ],
        ),
      ),
    );
  }
}
