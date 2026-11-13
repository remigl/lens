import 'package:flutter/services.dart';

/// Pont bas niveau vers le code Kotlin (`StorageMethodHandler`).
///
/// Ne contient aucune logique : le parsing et la validation sont faits
/// dans la couche `data`.
class StorageChannel {
  StorageChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(name);

  static const name = 'storage_lens/storage';

  final MethodChannel _channel;

  Future<List<Object?>> getVolumes() async {
    final result = await _channel.invokeListMethod<Object?>('getVolumes');
    return result ?? const [];
  }

  /// Répertoire interne privé de l'application (`Context.getFilesDir()`).
  Future<String> getPrivateFilesDir() async {
    final path = await _channel.invokeMethod<String>('getPrivateFilesDir');
    if (path == null || path.isEmpty) {
      throw const FormatException('Répertoire privé indisponible');
    }
    return path;
  }

  /// `Environment.isExternalStorageManager()` côté Android.
  Future<bool> hasAllFilesAccess() async =>
      await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;

  /// Ouvre l'écran système d'autorisation. `false` si introuvable.
  Future<bool> openAllFilesAccessSettings() async =>
      await _channel.invokeMethod<bool>('openAllFilesAccessSettings') ?? false;
}
