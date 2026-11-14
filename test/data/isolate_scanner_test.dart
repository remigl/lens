import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/data/scan/isolate_scanner.dart';
import 'package:storage_lens/domain/scan/scan_engine.dart';
import 'package:storage_lens/domain/scan/scan_progress.dart';
import 'package:storage_lens/domain/scan/volume_scan.dart';

void main() {
  late Directory a;
  late Directory b;

  setUp(() {
    a = Directory.systemTemp.createTempSync('iso_a_');
    b = Directory.systemTemp.createTempSync('iso_b_');
  });
  tearDown(() {
    a.deleteSync(recursive: true);
    b.deleteSync(recursive: true);
  });

  void write(Directory root, String path, int size, int fill) {
    final f = File('${root.path}/$path')..parent.createSync(recursive: true);
    f.writeAsBytesSync(List.filled(size, fill));
  }

  Future<VolumeScan> scan(Directory root, String id) => startVolumeScan(
        ScanRequest(volumeId: id, rootPath: root.path, candidateMinBytes: 1),
      ).result;

  test('analyse en arrière-plan avec progression', () async {
    write(a, 'x/1.jpg', 1000, 1);
    final job = startVolumeScan(ScanRequest(volumeId: 'a', rootPath: a.path));
    final progress = <ScanProgress>[];
    job.progress.listen(progress.add);
    final result = await job.result;
    expect(result.total.bytes, 1000);
    expect(progress, isNotEmpty);
  });

  test('annulation : résultat en erreur ScanCancelledException', () async {
    for (var i = 0; i < 200; i++) {
      write(a, 'd$i/f.bin', 10, 0);
    }
    final job = startVolumeScan(ScanRequest(volumeId: 'a', rootPath: a.path));
    job.cancel();
    await expectLater(job.result, throwsA(isA<ScanCancelledException>()));
  });

  test('erreur dans le travail → ScanFailedException', () async {
    final job = BackgroundJob.start<int>((_) => throw StateError('boom'));
    await expectLater(job.result, throwsA(isA<ScanFailedException>()));
  });

  test('comparaison de deux supports : fichiers communs vérifiés', () async {
    write(a, 'DCIM/vacances.mp4', 4000, 7);
    write(b, 'Sauvegarde/2026/v.mp4', 4000, 7); // identique, autre nom
    write(a, 'doc.pdf', 3000, 1);
    write(b, 'doc.pdf', 3000, 2); // même nom et taille, contenu différent
    write(a, 'DCIM/copie_locale.mp4', 4000, 7); // doublon interne à A

    final scanA = await scan(a, 'a');
    final scanB = await scan(b, 'b');
    final matches = await startCrossVolumeComparison(scanA, scanB).result;

    expect(matches, hasLength(1));
    expect(matches.single.pathsA.toSet(), {'/DCIM/vacances.mp4', '/DCIM/copie_locale.mp4'});
    expect(matches.single.pathsB, ['/Sauvegarde/2026/v.mp4']);
  });

  test('comparaison sans fichier commun', () async {
    write(a, 'a.bin', 100, 1);
    write(b, 'b.bin', 200, 1);
    final matches = await startCrossVolumeComparison(
      await scan(a, 'a'),
      await scan(b, 'b'),
    ).result;
    expect(matches, isEmpty);
  });
}
