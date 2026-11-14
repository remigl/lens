import 'package:flutter/foundation.dart';

import '../../domain/file_access_repository.dart';
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
    required this.hasFullAccess,
    this.isRefreshing = false,
  });

  final List<StorageVolumeInfo> volumes;
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
    required this._storage,
    required this._access,
  });

  final StorageRepository _storage;
  final FileAccessRepository _access;

  HomeState _state = const HomeLoading();
  bool _busy = false;
  bool _disposed = false;

  HomeState get state => _state;

  /// Lit (ou relit) les volumes montés et l'état de l'accès aux fichiers.
  Future<void> load() => _refresh();

  /// Ouvre l'écran système d'autorisation. L'état est relu au retour
  /// dans l'application (voir [load], appelé à la reprise).
  Future<bool> requestFullAccess() => _access.openAllFilesAccessSettings();

  Future<void> _refresh() async {
    if (_busy) return;
    _busy = true;
    final previous = _state;
    if (previous is HomeLoaded) _emit(previous.copyWith(isRefreshing: true));

    try {
      final volumes = await _storage.loadVolumes();
      final hasFullAccess = await _access.hasAllFilesAccess();
      _emit(HomeLoaded(
        volumes: volumes,
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
