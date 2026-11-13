import 'package:flutter/foundation.dart';

import '../../domain/file_access_repository.dart';
import '../../domain/scan_metadata_store.dart';
import '../../domain/storage_repository.dart';
import '../../domain/storage_volume_info.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded({
    required this.volumes,
    required this.lastScan,
    required this.hasFullAccess,
    this.isRefreshing = false,
  });

  final List<StorageVolumeInfo> volumes;
  final DateTime? lastScan;
  final bool hasFullAccess;
  final bool isRefreshing;

  StorageVolumeInfo? get primary {
    for (final v in volumes) {
      if (v.kind == VolumeKind.primary) return v;
    }
    return volumes.isEmpty ? null : volumes.first;
  }

  Iterable<StorageVolumeInfo> get secondary =>
      volumes.where((v) => !identical(v, primary));

  HomeLoaded copyWith({bool? isRefreshing}) => HomeLoaded(
        volumes: volumes,
        lastScan: lastScan,
        hasFullAccess: hasFullAccess,
        isRefreshing: isRefreshing ?? this.isRefreshing,
      );
}

final class HomeError extends HomeState {
  const HomeError(this.message);

  final String message;
}

class HomeController extends ChangeNotifier {
  HomeController({
    required StorageRepository storage,
    required ScanMetadataStore metadata,
    required FileAccessRepository access,
    DateTime Function()? clock,
  })  : _storage = storage,
        _metadata = metadata,
        _access = access,
        _clock = clock ?? DateTime.now;

  final StorageRepository _storage;
  final ScanMetadataStore _metadata;
  final FileAccessRepository _access;
  final DateTime Function() _clock;

  HomeState _state = const HomeLoading();
  bool _busy = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Lecture initiale : statistiques système + date du dernier scan.
  Future<void> load() => _refresh(recordScan: false);

  /// Étape 1 du MVP : rafraîchit les statistiques et enregistre la date.
  /// L'analyse détaillée (catégories, fichiers) arrive aux étapes suivantes.
  Future<void> analyze() => _refresh(recordScan: true);

  /// Ouvre l'écran système d'autorisation. L'état est relu au retour
  /// dans l'application (voir [load], appelé à la reprise).
  Future<bool> requestFullAccess() => _access.openAllFilesAccessSettings();

  Future<void> _refresh({required bool recordScan}) async {
    if (_busy) return;
    _busy = true;
    final previous = _state;
    if (previous is HomeLoaded) _emit(previous.copyWith(isRefreshing: true));

    try {
      final volumes = await _storage.loadVolumes();
      final hasFullAccess = await _access.hasAllFilesAccess();
      var lastScan = await _metadata.readLastScan();
      if (recordScan) {
        final now = _clock();
        if (await _metadata.writeLastScan(now)) lastScan = now;
      }
      _emit(HomeLoaded(
        volumes: volumes,
        lastScan: lastScan,
        hasFullAccess: hasFullAccess,
      ));
    } on StorageUnavailableException catch (e) {
      _emit(HomeError(e.message));
    } on Object catch (e) {
      debugPrint('Erreur inattendue : ${e.runtimeType}');
      _emit(const HomeError('Une erreur inattendue est survenue.'));
    } finally {
      _busy = false;
    }
  }

  void _emit(HomeState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
