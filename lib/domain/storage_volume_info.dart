import 'package:flutter/foundation.dart';

enum VolumeKind { primary, removable, other }

/// Espace d'un volume de stockage, tel que rapporté par le système.
@immutable
class StorageVolumeInfo {
  const StorageVolumeInfo._({
    required this.id,
    required this.label,
    required this.kind,
    required this.totalBytes,
    required this.freeBytes,
    required this.rootPath,
  });

  /// Construit un volume en corrigeant les valeurs incohérentes
  /// (négatives, libre > total) plutôt que de planter.
  factory StorageVolumeInfo.sanitized({
    required String id,
    required String label,
    required VolumeKind kind,
    required int totalBytes,
    required int freeBytes,
    String? rootPath,
  }) {
    final total = totalBytes < 0 ? 0 : totalBytes;
    final free = freeBytes.clamp(0, total);
    return StorageVolumeInfo._(
      id: id,
      label: label,
      kind: kind,
      totalBytes: total,
      freeBytes: free,
      rootPath: rootPath,
    );
  }

  /// Seuil sous lequel on considère le stockage « presque plein ».
  static const almostFullThreshold = 0.10;

  final String id;
  final String label;
  final VolumeKind kind;
  final int totalBytes;
  final int freeBytes;

  /// Point de montage lisible par l'analyse, ou `null` si inconnu.
  final String? rootPath;

  bool get canBeScanned => rootPath != null && rootPath!.isNotEmpty;

  int get usedBytes => totalBytes - freeBytes;

  double get usedFraction => totalBytes == 0 ? 0 : usedBytes / totalBytes;

  bool get isAlmostFull =>
      totalBytes > 0 && freeBytes / totalBytes < almostFullThreshold;

  @override
  bool operator ==(Object other) =>
      other is StorageVolumeInfo &&
      other.id == id &&
      other.label == label &&
      other.kind == kind &&
      other.totalBytes == totalBytes &&
      other.freeBytes == freeBytes &&
      other.rootPath == rootPath;

  @override
  int get hashCode => Object.hash(id, label, kind, totalBytes, freeBytes, rootPath);
}
