import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/scan_metadata_store.dart';
import '../platform/storage_channel.dart';

/// Stocke la date du dernier scan dans un petit fichier JSON
/// du répertoire interne privé (non sauvegardé, non partagé).
class FileScanMetadataStore implements ScanMetadataStore {
  FileScanMetadataStore(this._directory);

  factory FileScanMetadataStore.fromChannel(StorageChannel channel) =>
      FileScanMetadataStore(
        () async => Directory(await channel.getPrivateFilesDir()),
      );

  static const fileName = 'scan_metadata.json';
  static const _schemaVersion = 1;

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<DateTime?> readLastScan() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      final millis = decoded['lastScanUtcMs'];
      if (millis is! int || millis <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } on Object catch (e) {
      debugPrint('Lecture des métadonnées impossible : ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<bool> writeLastScan(DateTime scannedAt) async {
    try {
      final target = await _file();
      final tmp = File('${target.path}.tmp');
      final payload = jsonEncode({
        'version': _schemaVersion,
        'lastScanUtcMs': scannedAt.toUtc().millisecondsSinceEpoch,
      });
      // Écriture atomique : fichier temporaire puis renommage.
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(target.path);
      return true;
    } on Object catch (e) {
      debugPrint('Écriture des métadonnées impossible : ${e.runtimeType}');
      return false;
    }
  }
}
