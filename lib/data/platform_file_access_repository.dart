import 'package:flutter/foundation.dart';

import '../domain/file_access_repository.dart';
import '../platform/storage_channel.dart';

class PlatformFileAccessRepository implements FileAccessRepository {
  PlatformFileAccessRepository(this._channel);

  final StorageChannel _channel;

  @override
  Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.hasAllFilesAccess();
    } on Object catch (e) {
      debugPrint('hasAllFilesAccess a échoué : ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> openAllFilesAccessSettings() async {
    try {
      return await _channel.openAllFilesAccessSettings();
    } on Object catch (e) {
      debugPrint('openAllFilesAccessSettings a échoué : ${e.runtimeType}');
      return false;
    }
  }
}
