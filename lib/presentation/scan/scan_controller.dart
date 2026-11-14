import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/scan/isolate_scanner.dart';
import '../../data/scan/scan_cache.dart';
import '../../domain/scan/scan_engine.dart';
import '../../domain/scan/scan_progress.dart';
import '../../domain/scan/volume_scan.dart';
import '../../domain/storage_volume_info.dart';

sealed class VolumeScanState {
  const VolumeScanState();
}

final class ScanNotLoaded extends VolumeScanState {
  const ScanNotLoaded();
}

final class ScanIdle extends VolumeScanState {
  const ScanIdle();
}

final class ScanRunning extends VolumeScanState {
  const ScanRunning(this.progress);

  final ScanProgress? progress;
}

final class ScanDone extends VolumeScanState {
  const ScanDone(this.scan);

  final VolumeScan scan;
}

final class ScanFailed extends VolumeScanState {
  const ScanFailed(this.message, {this.previous});

  final String message;
  final VolumeScan? previous;
}

typedef ScanStarter = BackgroundJob<VolumeScan> Function(ScanRequest request);

/// État des analyses de tous les volumes. Une seule analyse à la fois,
/// pour limiter la charge disque et la batterie.
class ScanController extends ChangeNotifier {
  ScanController({required this._cache, ScanStarter? starter})
      : _starter = starter ?? startVolumeScan;

  final ScanCache _cache;
  final ScanStarter _starter;

  final _states = <String, VolumeScanState>{};
  final _loading = <String>{};
  BackgroundJob<VolumeScan>? _job;
  String? _runningVolumeId;
  StreamSubscription<ScanProgress>? _progressSub;
  bool _disposed = false;

  VolumeScanState stateOf(String volumeId) =>
      _states[volumeId] ?? const ScanNotLoaded();

  VolumeScan? scanOf(String volumeId) => switch (stateOf(volumeId)) {
        ScanDone(:final scan) => scan,
        ScanFailed(:final previous) => previous,
        _ => null,
      };

  bool get isBusy => _job != null;
  String? get runningVolumeId => _runningVolumeId;

  /// Charge la dernière analyse enregistrée, si elle existe.
  Future<void> ensureLoaded(String volumeId) async {
    if (_states.containsKey(volumeId) || !_loading.add(volumeId)) return;
    final cached = await _cache.read(volumeId);
    _loading.remove(volumeId);
    if (_states.containsKey(volumeId)) return; // une analyse a démarré entre-temps
    _set(volumeId, cached == null ? const ScanIdle() : ScanDone(cached));
  }

  /// Démarre l'analyse. Renvoie `false` si une autre analyse est en cours
  /// ou si le volume n'a pas de point de montage lisible.
  bool start(StorageVolumeInfo volume) {
    if (_job != null || !volume.canBeScanned) return false;
    final previous = scanOf(volume.id);
    final job = _starter(ScanRequest(
      volumeId: volume.id,
      rootPath: volume.rootPath!,
    ));
    _job = job;
    _runningVolumeId = volume.id;
    _set(volume.id, const ScanRunning(null));

    _progressSub = job.progress.listen((p) {
      if (_runningVolumeId == volume.id) _set(volume.id, ScanRunning(p));
    });
    unawaited(_await(job, volume.id, previous));
    return true;
  }

  Future<void> _await(
    BackgroundJob<VolumeScan> job,
    String volumeId,
    VolumeScan? previous,
  ) async {
    try {
      final scan = await job.result;
      _set(volumeId, ScanDone(scan));
      await _cache.write(scan);
    } on ScanCancelledException {
      _set(volumeId, previous == null ? const ScanIdle() : ScanDone(previous));
    } on Object catch (e) {
      debugPrint('Analyse échouée : ${e.runtimeType}');
      _set(
        volumeId,
        ScanFailed("L'analyse n'a pas pu aboutir.", previous: previous),
      );
    } finally {
      if (identical(_job, job)) {
        _job = null;
        _runningVolumeId = null;
        await _progressSub?.cancel();
        _progressSub = null;
        if (!_disposed) notifyListeners();
      }
    }
  }

  void cancel() => _job?.cancel();

  void _set(String volumeId, VolumeScanState state) {
    if (_disposed) return;
    _states[volumeId] = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _job?.cancel();
    unawaited(_progressSub?.cancel());
    super.dispose();
  }
}
