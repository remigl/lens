import 'storage_volume_info.dart';

abstract interface class StorageRepository {
  /// Volumes montés et lisibles, volume principal en premier.
  ///
  /// Lève [StorageUnavailableException] si le système ne répond pas.
  Future<List<StorageVolumeInfo>> loadVolumes();
}

class StorageUnavailableException implements Exception {
  const StorageUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'StorageUnavailableException: $message';
}
