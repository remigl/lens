import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/data/file_scan_metadata_store.dart';

void main() {
  late Directory dir;
  late FileScanMetadataStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('storage_lens_test_');
    store = FileScanMetadataStore(() async => dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File metadataFile() => File('${dir.path}/${FileScanMetadataStore.fileName}');

  test('aucun fichier → null', () async {
    expect(await store.readLastScan(), isNull);
  });

  test('aller-retour écriture / lecture', () async {
    final at = DateTime.utc(2026, 11, 13, 17, 30);
    expect(await store.writeLastScan(at), isTrue);
    expect(await store.readLastScan(), at);
    expect(await File('${metadataFile().path}.tmp').exists(), isFalse);
  });

  test('fichier corrompu → null, sans exception', () async {
    await metadataFile().writeAsString('{pas du json');
    expect(await store.readLastScan(), isNull);
  });

  test('schéma inattendu → null', () async {
    await metadataFile().writeAsString('{"lastScanUtcMs": "hier"}');
    expect(await store.readLastScan(), isNull);
    await metadataFile().writeAsString('[1, 2, 3]');
    expect(await store.readLastScan(), isNull);
  });

  test('répertoire disparu → écriture refusée proprement', () async {
    await dir.delete(recursive: true);
    expect(await store.writeLastScan(DateTime.now()), isFalse);
    expect(await store.readLastScan(), isNull);
  });

  test('répertoire introuvable via le canal → null / false', () async {
    final broken = FileScanMetadataStore(() async => throw StateError('x'));
    expect(await broken.readLastScan(), isNull);
    expect(await broken.writeLastScan(DateTime.now()), isFalse);
  });
}
