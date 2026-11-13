/// Formate une taille en octets avec les unités décimales (SI) en français.
///
/// Android (Paramètres > Stockage) affiche les tailles en base 1000 :
/// on fait de même pour que les chiffres correspondent à ce que voit
/// l'utilisateur ailleurs sur son téléphone.
library;

const _units = ['o', 'Ko', 'Mo', 'Go', 'To', 'Po'];
const _nbsp = ' ';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0${_nbsp}o';

  var value = bytes.toDouble();
  var unit = 0;
  // Seuil 999,5 : évite d'afficher « 1000 Mo » au lieu de « 1 Go ».
  while (value >= 999.5 && unit < _units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${_formatNumber(value, unit)}$_nbsp${_units[unit]}';
}

String _formatNumber(double value, int unit) {
  if (unit == 0 || value >= 100) return value.round().toString();
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.truncateToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// Pourcentage entier, borné entre 0 et 100.
String formatPercent(double fraction) {
  final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
  return '${(clamped * 100).round()}$_nbsp%';
}
