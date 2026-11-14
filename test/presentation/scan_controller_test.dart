import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/scan/scan_progress.dart';
import 'package:storage_lens/presentation/scan/scan_controller.dart';

import 'fakes.dart';

void main() {
  late Directory root;
  late MemoryScanCache cache;
  late ManualScan manual;
  late ScanController controller;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ctrl_');
    writeBytes(root, 'a.jpg', List.filled(100, 1));
    cache = MemoryScanCache();
    manual = ManualScan();
    controller = ScanController(cache: cache, starter: manual.start);
  });

  tearDown(() {
    controller.dispose();
    root.deleteSync(recursive: true);
  });

  test('sans cache → ScanIdle ; avec cache → ScanDone', () async {
    await controller.ensureLoaded('primary');
    expect(controller.stateOf('primary'), isA<ScanIdle>());

    cache.stored['sd'] = scanOf(root, volumeId: 'sd');
    await controller.ensureLoaded('sd');
    expect(controller.scanOf('sd'), isNotNull);
  });

  test('analyse : progression puis résultat mis en cache', () async {
    expect(controller.start(internalVolume(rootPath: root.path)), isTrue);
    expect(manual.request?.rootPath, root.path);
    expect(controller.isBusy, isTrue);

    manual.progress.add(const ScanProgress(
      phase: ScanPhase.listing,
      filesSeen: 3,
      bytesSeen: 30,
    ));
    await Future<void>.delayed(Duration.zero);
    expect((controller.stateOf('primary') as ScanRunning).progress?.filesSeen, 3);

    final result = scanOf(root);
    manual.completer.complete(result);
    await pumpEventQueue();

    expect(controller.scanOf('primary'), same(result));
    expect(cache.stored['primary'], same(result));
    expect(controller.isBusy, isFalse);
  });

  test('une seule analyse à la fois', () {
    expect(controller.start(internalVolume()), isTrue);
    expect(controller.start(sdCard()), isFalse);
  });

  test('volume sans point de montage : refusé', () {
    expect(controller.start(internalVolume(rootPath: null)), isFalse);
  });

  test('annulation : retour au résultat précédent', () async {
    final previous = scanOf(root);
    cache.stored['primary'] = previous;
    await controller.ensureLoaded('primary');

    controller.start(internalVolume());
    controller.cancel();
    await pumpEventQueue();

    expect(manual.cancelled, isTrue);
    expect(controller.scanOf('primary'), same(previous));
    expect(controller.isBusy, isFalse);
  });

  test('échec : message et résultat précédent conservé', () async {
    final previous = scanOf(root);
    cache.stored['primary'] = previous;
    await controller.ensureLoaded('primary');

    controller.start(internalVolume());
    manual.completer.completeError(StateError('io'));
    await pumpEventQueue();

    final state = controller.stateOf('primary') as ScanFailed;
    expect(state.previous, same(previous));
    expect(controller.scanOf('primary'), same(previous));
  });
}
