/// Formate la date du dernier scan de façon lisible, sans dépendance `intl`.
String formatLastScan(DateTime scan, {required DateTime now}) {
  final local = scan.toLocal();
  final current = now.toLocal();
  final time = '${_two(local.hour)}:${_two(local.minute)}';

  // Comparaison en jours calendaires via UTC pour ignorer les changements d'heure.
  final scanDay = DateTime.utc(local.year, local.month, local.day);
  final today = DateTime.utc(current.year, current.month, current.day);
  final days = today.difference(scanDay).inDays;

  return switch (days) {
    0 => "Aujourd'hui à $time",
    1 => 'Hier à $time',
    _ => '${_two(local.day)}/${_two(local.month)}/${local.year} à $time',
  };
}

String _two(int n) => n.toString().padLeft(2, '0');
