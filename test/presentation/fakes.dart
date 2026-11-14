import 'dart:async';
import 'dart:io';

import 'package:storage_lens/data/scan/isolate_scanner.dart';
import 'package:storage_lens/data/scan/scan_cache.dart';
import 'package:storage_lens/domain/file_access_repository.dart';
import 'package:storage_lens/domain/scan/scan_engine.dart';
import 'package:storage_lens/domain/scan/scan_progress.dart';
import 'package:storage_lens/domain/scan/volume_scan.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/domain/storage_volume_info.dart';

StorageVolumeInfo internalVolume({
  int total = 128000000000,
  int free = 36600000000,
  String? rootPath = '/storage/emulated/0',
}) =>
    StorageVolumeInfo.sanitized(
      id: 'primary',
      label: 'Stockage interne',
      kind: VolumeKind.primary,
      totalBytes: total,
      freeBytes: free,
      rootPath: rootPath,
    );

StorageVolumeInfo sdCard({String? rootPath = '/storage/1A2B-3C4D'}) =>
    StorageVolumeInfo.sanitized(
      id: '1A2B-3C4D',
      label: 'Carte SD',
      kind: VolumeKind.removable,
      totalBytes: 64000000000,
      freeBytes: 40000000000,
      rootPath: rootPath,
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

/// Cache en mémoire (pas d'E/S dans les tests de widgets).
class MemoryScanCache extends ScanCache {
  MemoryScanCache() : super(() async => Directory.systemTemp);

  final stored = <String, VolumeScan>{};

  @override
  Future<VolumeScan?> read(String volumeId) async => stored[volumeId];

  @override
  Future<bool> write(VolumeScan scan) async {
    stored[scan.volumeId] = scan;
    return true;
  }
}

/// Analyse pilotée manuellement par le test.
class ManualScan {
  final completer = Completer<VolumeScan>();
  final progress = StreamController<ScanProgress>.broadcast();
  ScanRequest? request;
  bool cancelled = false;

  late final BackgroundJob<VolumeScan> job = BackgroundJob.manual(
    completer.future,
    progress.stream,
    () {
      cancelled = true;
      if (!completer.isCompleted) {
        completer.completeError(const ScanCancelledException());
      }
    },
  );

  BackgroundJob<VolumeScan> start(ScanRequest r) {
    request = r;
    return job;
  }
}

/// Crée une arborescence de test et l'analyse avec le vrai moteur.
VolumeScan scanOf(Directory root, {String volumeId = 'primary'}) =>
    ScanEngine(ScanRequest(volumeId: volumeId, rootPath: root.path)).run();

void writeBytes(Directory root, String relative, List<int> bytes) {
  final file = File('${root.path}/$relative');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
}
