enum ScanPhase { listing, duplicates }

/// Progression réelle, mesurée (jamais simulée).
class ScanProgress {
  const ScanProgress({
    required this.phase,
    required this.filesSeen,
    required this.bytesSeen,
    this.duplicateBytesChecked = 0,
    this.duplicateBytesToCheck = 0,
  });

  final ScanPhase phase;
  final int filesSeen;
  final int bytesSeen;
  final int duplicateBytesChecked;
  final int duplicateBytesToCheck;

  /// Fraction de la phase de vérification des doublons, si connue.
  double? get duplicateFraction => duplicateBytesToCheck <= 0
      ? null
      : (duplicateBytesChecked / duplicateBytesToCheck).clamp(0.0, 1.0);
}
