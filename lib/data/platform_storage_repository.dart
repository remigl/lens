import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/storage_repository.dart';
import '../domain/storage_volume_info.dart';
import '../platform/storage_channel.dart';

class PlatformStorageRepository implements StorageRepository {
  PlatformStorageRepository(this._channel);

  final StorageChannel _channel;

  static const _unavailableMessage =
      'Impossible de lire les statistiques de stockage du système.';

  @override
  Future<List<StorageVolumeInfo>> loadVolumes() async {
    final List<Object?> raw;
    try {
      raw = await _channel.getVolumes();
    } on PlatformException catch (e) {
      debugPrint('getVolumes a échoué : ${e.code}');
      throw const StorageUnavailableException(_unavailableMessage);
    } on MissingPluginException {
      throw const StorageUnavailableException(_unavailableMessage);
    }

    final volumes = raw.map(parseVolume).nonNulls.toList()
      ..sort((a, b) => _kindOrder(a.kind).compareTo(_kindOrder(b.kind)));
    return volumes;
  }

  /// Parse défensif : toute entrée mal formée est ignorée.
  @visibleForTesting
  static StorageVolumeInfo? parseVolume(Object? entry) {
    if (entry is! Map<Object?, Object?>) return null;
    final id = entry['id'];
    final label = entry['label'];
    final total = entry['totalBytes'];
    final free = entry['freeBytes'];
    if (id is! String || label is! String || total is! int || free is! int) {
      return null;
    }
    if (total <= 0) return null;

    return StorageVolumeInfo.sanitized(
      id: id,
      label: label,
      kind: _kindFrom(entry),
      totalBytes: total,
      freeBytes: free,
    );
  }

  static VolumeKind _kindFrom(Map<Object?, Object?> entry) {
    if (entry['primary'] == true) return VolumeKind.primary;
    if (entry['removable'] == true) return VolumeKind.removable;
    return VolumeKind.other;
  }

  static int _kindOrder(VolumeKind kind) => switch (kind) {
        VolumeKind.primary => 0,
        VolumeKind.removable => 1,
        VolumeKind.other => 2,
      };
}
