import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/scan/file_category.dart';
import 'package:storage_lens/domain/scan/scan_engine.dart';
import 'package:storage_lens/domain/scan/scan_progress.dart';
import 'package:storage_lens/domain/scan/volume_scan.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('scan_engine_'));
  tearDown(() {
    // Restaure les droits éventuellement retirés avant suppression.
    Process.runSync('chmod', ['-R', 'u+rwx', root.path]);
    root.deleteSync(recursive: true);
  });

  File write(String relative, int size, {int fill = 0}) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List.filled(size, fill));
    return file;
  }

  VolumeScan scan({ScanEngine Function(ScanRequest)? build, int minCandidate = 1}) {
    final request = ScanRequest(
      volumeId: 'v',
      rootPath: root.path,
      candidateMinBytes: minCandidate,
    );
    return (build?.call(request) ?? ScanEngine(request)).run();
  }

  test('catégories, totaux et dossiers cumulés', () {
    write('DCIM/Camera/IMG_1.jpg', 3000);
    write('DCIM/Camera/VID_1.mp4', 10000);
    write('Music/song.MP3', 2000);
    write('Documents/rapport.pdf', 1000);
    write('Download/app.apk', 4000);
    write('Download/backup.zip', 500);
    write('notes', 7);

    final result = scan();

    expect(result.category(FileCategory.images), isA<SizeStat>());
    expect(result.category(FileCategory.images).bytes, 3000);
    expect(result.category(FileCategory.videos).bytes, 10000);
    expect(result.category(FileCategory.audio).bytes, 2000);
    expect(result.category(FileCategory.documents).bytes, 1000);
    expect(result.category(FileCategory.apks).bytes, 4000);
    expect(result.category(FileCategory.archives).bytes, 500);
    expect(result.category(FileCategory.other).bytes, 7);
    expect(result.total.bytes, 20507);
    expect(result.total.count, 7);
    expect(result.downloads.bytes, 4500);
    expect(result.sortedCategories.first, FileCategory.videos);

    final tree = result.tree;
    expect(tree.totalBytes[0], 20507);
    final dcim = tree.childrenOf(0).first;
    expect(tree.names[dcim], 'DCIM');
    expect(tree.totalBytes[dcim], 13000);
    expect(tree.fileCounts[dcim], 2);
    expect(tree.directBytes[0], 7);
  });

  test('plus gros fichiers triés, chemin relatif et date', () {
    write('a/petit.txt', 10);
    write('b/gros.mkv', 900);
    write('b/moyen.mkv', 500);

    final files = scan().largestFiles();
    expect(files.map((f) => f.size), [900, 500, 10]);
    expect(files.first.relativePath, '/b/gros.mkv');
    expect(files.first.folder, '/b');
    expect(files.first.name, 'gros.mkv');
    expect(files.first.modified, isNotNull);
  });

  test('limite du nombre de gros fichiers conservés par catégorie', () {
    for (var i = 1; i <= 30; i++) {
      write('v/$i.mp4', i * 10);
    }
    final result = ScanEngine(ScanRequest(
      volumeId: 'v',
      rootPath: root.path,
      largestPerCategory: 5,
    )).run();
    expect(
      result.largestByCategory[FileCategory.videos]!.map((f) => f.size),
      [300, 290, 280, 270, 260],
    );
    expect(result.category(FileCategory.videos).count, 30);
  });

  test('dossier vide et volume vide', () {
    Directory('${root.path}/vide').createSync();
    final result = scan();
    expect(result.total.count, 0);
    expect(result.tree.length, 2);
    expect(result.duplicates, isEmpty);
  });

  test('noms Unicode et caractères spéciaux', () {
    const names = [
      'Été 2026/photo été ✓.jpg',
      '日本語/ファイル.pdf',
      'emoji 🚲/vidéo #1 (copie) [final].mp4',
      "espace et 'apostrophe'/a&b;c.txt",
    ];
    for (final n in names) {
      write(n, 100);
    }
    final result = scan();
    final paths = result.largestFiles().map((f) => f.relativePath).toSet();
    for (final n in names) {
      expect(paths, contains('/$n'));
    }
  });

  test('liens symboliques jamais suivis (pas de boucle)', () {
    write('reel/fichier.bin', 1000);
    Link('${root.path}/boucle').createSync(root.path);
    Link('${root.path}/vers_fichier').createSync('${root.path}/reel/fichier.bin');

    final result = scan();
    expect(result.total.bytes, 1000);
    expect(result.issues.skippedLinks, 2);
  });

  test('dossier illisible : compté, analyse poursuivie', () {
    write('ok/a.txt', 10);
    write('prive/secret.txt', 99);
    Process.runSync('chmod', ['000', '${root.path}/prive']);

    final result = scan();
    expect(result.total.bytes, 10);
    expect(result.issues.unreadableDirs, 1);
  }, skip: _isRoot() ? 'root ignore les droits' : false);

  test('fichier supprimé pendant le scan : compté comme disparu', () {
    write('a/stable.txt', 10);
    write('a/ephemere.txt', 20);

    final result = scan(
      build: (request) => ScanEngine(request)
        ..beforeStat = (path) {
          if (path.endsWith('ephemere.txt')) File(path).deleteSync();
        },
    );
    expect(result.total.bytes, 10);
    expect(result.issues.vanishedFiles, 1);
  });

  test('Android/data et Android/obb non parcourus et signalés', () {
    write('Android/data/com.app/x.bin', 50);
    write('Android/obb/com.game/y.obb', 50);
    write('Android/media/z.jpg', 5);

    final result = scan();
    expect(result.total.bytes, 5);
    expect(result.issues.protectedDirs, containsAll(['/Android/data', '/Android/obb']));
  });

  test('corbeille et fichiers temporaires détectés', () {
    write('DCIM/.trashed-1700000000-IMG.jpg', 300);
    write('Android/.Trash/com.gallery/x.jpg', 200);
    write('appdata/cache/c.bin', 50);
    write('DCIM/.thumbnails/t.jpg', 5);
    write('notes/brouillon.tmp', 1);

    final result = scan();
    expect(result.trash.bytes, 500);
    expect(result.temporary.bytes, 56);
  });

  test('doublons : contenu identique, noms différents', () {
    write('a/vacances.mp4', 5000, fill: 7);
    write('b/copie de vacances.mp4', 5000, fill: 7);
    write('c/autre.mp4', 5000, fill: 8); // même taille, contenu différent
    write('d/vacances.mp4', 4000, fill: 7); // même nom, taille différente

    final result = scan();
    expect(result.duplicates, hasLength(1));
    final group = result.duplicates.single;
    expect(group.paths.toSet(), {'/a/vacances.mp4', '/b/copie de vacances.mp4'});
    expect(group.extraBytes, 5000);
    expect(result.duplicateExtraBytes, 5000);
  });

  test('progression réelle et croissante', () {
    for (var i = 0; i < 20; i++) {
      write('f/$i.bin', 100);
    }
    final seen = <ScanProgress>[];
    ScanEngine(
      ScanRequest(volumeId: 'v', rootPath: root.path, candidateMinBytes: 1),
      onProgress: seen.add,
      progressInterval: Duration.zero,
    ).run();

    final listing = seen.where((p) => p.phase == ScanPhase.listing).toList();
    expect(listing.last.filesSeen, 20);
    expect(listing.last.bytesSeen, 2000);
    for (var i = 1; i < listing.length; i++) {
      expect(listing[i].bytesSeen, greaterThanOrEqualTo(listing[i - 1].bytesSeen));
    }
  });

  test('racine inexistante : résultat vide, pas d\'exception', () {
    final result = ScanEngine(ScanRequest(
      volumeId: 'v',
      rootPath: '${root.path}/absent',
    )).run();
    expect(result.total.count, 0);
    expect(result.issues.unreadableDirs, 1);
  });

  test('volume de nombreux fichiers', () {
    for (var d = 0; d < 50; d++) {
      for (var f = 0; f < 100; f++) {
        write('d$d/f$f.txt', 1);
      }
    }
    final watch = Stopwatch()..start();
    final result = scan(minCandidate: 1 << 20);
    expect(result.total.count, 5000);
    expect(result.tree.length, 51);
    expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
  });

  test('le parcours ne modifie aucun fichier', () {
    final file = write('a/b.jpg', 100);
    final before = file.statSync();
    scan();
    final after = file.statSync();
    expect(after.modified, before.modified);
    expect(after.size, before.size);
    expect(file.readAsBytesSync(), List.filled(100, 0));
  });
}

bool _isRoot() {
  final result = Process.runSync('id', ['-u']);
  return result.stdout.toString().trim() == '0';
}
