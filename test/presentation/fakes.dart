import 'dart:async';

import 'package:storage_lens/domain/file_access_repository.dart';
import 'package:storage_lens/domain/scan_metadata_store.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/domain/storage_volume_info.dart';

StorageVolumeInfo internalVolume({
  int total = 128000000000,
  int free = 36600000000,
}) =>
    StorageVolumeInfo.sanitized(
      id: 'primary',
      label: 'Stockage interne',
      kind: VolumeKind.primary,
      totalBytes: total,
      freeBytes: free,
    );

class FakeStorageRepository implements StorageRepository {
  FakeStorageRepository(this.volumes);

  List<StorageVolumeInfo> volumes;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<StorageVolumeInfo>> loadVolumes() async {
    calls++;
    if (gate != null) await gate!.future;
    final e = error;
    if (e != null) throw e;
    return volumes;
  }
}

class FakeScanMetadataStore implements ScanMetadataStore {
  DateTime? stored;
  bool failWrites = false;

  @override
  Future<DateTime?> readLastScan() async => stored;

  @override
  Future<bool> writeLastScan(DateTime scannedAt) async {
    if (failWrites) return false;
    stored = scannedAt;
    return true;
  }
}

class FakeFileAccessRepository implements FileAccessRepository {
  FakeFileAccessRepository({this.granted = false, this.settingsAvailable = true});

  bool granted;
  bool settingsAvailable;
  int settingsOpened = 0;

  @override
  Future<bool> hasAllFilesAccess() async => granted;

  @override
  Future<bool> openAllFilesAccessSettings() async {
    if (!settingsAvailable) return false;
    settingsOpened++;
    return true;
  }
}
