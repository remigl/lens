import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/scan/volume_scan.dart';

/// Dernière analyse de chaque volume, compressée (gzip), dans le
/// répertoire privé de l'application (exclu des sauvegardes).
class ScanCache {
  ScanCache(this._directory);

  final Future<Directory> Function() _directory;

  static const folderName = 'scans';

  Future<File> _fileFor(String volumeId) async {
    final base = await _directory();
    final safeId = volumeId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${base.path}/$folderName/$safeId.json.gz');
  }

  Future<VolumeScan?> read(String volumeId) async {
    try {
      final file = await _fileFor(volumeId);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final json = await compute(_decode, bytes);
      final scan = VolumeScan.fromJson(json);
      return scan?.volumeId == volumeId ? scan : null;
    } on Object catch (e) {
      debugPrint('Cache illisible : ${e.runtimeType}');
      return null;
    }
  }

  Future<bool> write(VolumeScan scan) async {
    try {
      final file = await _fileFor(scan.volumeId);
      await file.parent.create(recursive: true);
      final bytes = await compute(_encode, scan.toJson());
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return true;
    } on Object catch (e) {
      debugPrint('Écriture du cache impossible : ${e.runtimeType}');
      return false;
    }
  }

  static Object? _decode(List<int> bytes) =>
      jsonDecode(utf8.decode(gzip.decode(bytes)));

  static List<int> _encode(Map<String, Object> json) =>
      gzip.encode(utf8.encode(jsonEncode(json)));
}
