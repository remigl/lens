import 'package:flutter/material.dart';

/// Emplacement réservé à la répartition par catégories (étape 2).
class CategoriesPlaceholderCard extends StatelessWidget {
  const CategoriesPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.pie_chart_outline),
        title: Text('Répartition par catégories'),
        subtitle: Text(
          'Photos, vidéos, audio, documents… : disponible dans une prochaine version.',
        ),
      ),
    );
  }
}
