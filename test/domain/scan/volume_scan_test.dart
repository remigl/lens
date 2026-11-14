import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/data/scan/scan_cache.dart';
import 'package:storage_lens/domain/scan/file_category.dart';
import 'package:storage_lens/domain/scan/scan_engine.dart';
import 'package:storage_lens/domain/scan/volume_scan.dart';

void main() {
  late Directory root;
  late Directory appDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('vs_root_');
    appDir = Directory.systemTemp.createTempSync('vs_app_');
  });
  tearDown(() {
    root.deleteSync(recursive: true);
    appDir.deleteSync(recursive: true);
  });

  VolumeScan makeScan({String volumeId = 'primary'}) {
    void w(String p, List<int> b) {
      final f = File('${root.path}/$p')..parent.createSync(recursive: true);
      f.writeAsBytesSync(b);
    }

    w('DCIM/a.jpg', List.filled(2000, 1));
    w('DCIM/b.jpg', List.filled(2000, 1));
    w('Download/é.pdf', List.filled(300, 2));
    return ScanEngine(ScanRequest(
      volumeId: volumeId,
      rootPath: root.path,
      candidateMinBytes: 1,
    )).run();
  }

  group('FileCategory', () {
    test('extensions en majuscules et noms sans extension', () {
      expect(FileCategory.of('IMG.JPG'), FileCategory.images);
      expect(FileCategory.of('film.MKV'), FileCategory.videos);
      expect(FileCategory.of('archive.tar.gz'), FileCategory.archives);
      expect(FileCategory.of('Makefile'), FileCategory.other);
      expect(FileCategory.of('.nomedia'), FileCategory.other);
      expect(FileCategory.of('fin.'), FileCategory.other);
      expect(FileCategory.of('app.apk'), FileCategory.apks);
    });
  });

  test('aller-retour JSON sans perte', () {
    final scan = makeScan();
    final json = jsonDecode(jsonEncode(scan.toJson()));
    final back = VolumeScan.fromJson(json)!;

    expect(back.volumeId, scan.volumeId);
    expect(back.total.bytes, scan.total.bytes);
    expect(back.category(FileCategory.images).count, 2);
    expect(back.downloads.bytes, 300);
    expect(back.largestFiles().map((f) => f.relativePath),
        scan.largestFiles().map((f) => f.relativePath));
    expect(back.tree.pathOf(back.tree.length - 1), scan.tree.pathOf(scan.tree.length - 1));
    expect(back.duplicates.single.paths.toSet(), {'/DCIM/a.jpg', '/DCIM/b.jpg'});
    expect(back.candidates, hasLength(3));
  });

  test('JSON invalide ou d\'une autre version → null', () {
    expect(VolumeScan.fromJson(null), isNull);
    expect(VolumeScan.fromJson({'v': 99}), isNull);
    final json = makeScan().toJson()..['tree'] = {'names': ['x'], 'parents': [5]};
    expect(VolumeScan.fromJson(json), isNull);
  });

  test('arbre corrompu (cycle) refusé', () {
    final tree = DirTree.fromJson({
      'names': ['', 'a', 'b'],
      'parents': [-1, 2, 1],
      'total': [0, 0, 0],
      'counts': [0, 0, 0],
      'direct': [0, 0, 0],
    });
    expect(tree, isNull);
  });

  group('ScanCache', () {
    test('écriture puis lecture', () async {
      final cache = ScanCache(() async => appDir);
      final scan = makeScan(volumeId: '1A2B-3C4D');
      expect(await cache.write(scan), isTrue);
      final back = await cache.read('1A2B-3C4D');
      expect(back?.total.bytes, scan.total.bytes);
      expect(await cache.read('autre'), isNull);
    });

    test('identifiant de volume assaini (pas de traversée de chemin)', () async {
      final cache = ScanCache(() async => appDir);
      final scan = makeScan(volumeId: '../../evil');
      expect(await cache.write(scan), isTrue);
      final written = Directory('${appDir.path}/${ScanCache.folderName}')
          .listSync()
          .map((e) => e.path.split('/').last);
      expect(written.single, '______evil.json.gz');
    });

    test('fichier de cache corrompu → null', () async {
      final cache = ScanCache(() async => appDir);
      final file = File('${appDir.path}/${ScanCache.folderName}/primary.json.gz')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('pas du gzip');
      expect(file.existsSync(), isTrue);
      expect(await cache.read('primary'), isNull);
    });

    test('répertoire indisponible → échec propre', () async {
      final cache = ScanCache(() async => throw StateError('x'));
      expect(await cache.read('primary'), isNull);
      expect(await cache.write(makeScan()), isFalse);
    });
  });
}
