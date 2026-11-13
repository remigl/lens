import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/presentation/home/home_controller.dart';

import 'fakes.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 11, 13, 17, 0);
  late FakeStorageRepository repo;
  late FakeScanMetadataStore meta;
  late FakeFileAccessRepository access;
  late HomeController controller;

  setUp(() {
    repo = FakeStorageRepository([internalVolume()]);
    meta = FakeScanMetadataStore();
    access = FakeFileAccessRepository();
    controller = HomeController(
      storage: repo,
      metadata: meta,
      access: access,
      clock: () => fixedNow,
    );
  });

  tearDown(() => controller.dispose());

  test('état initial : chargement', () {
    expect(controller.state, isA<HomeLoading>());
  });

  test('load : volumes chargés, pas de date enregistrée', () async {
    await controller.load();
    final state = controller.state as HomeLoaded;
    expect(state.primary?.usedBytes, 91400000000);
    expect(state.lastScan, isNull);
    expect(meta.stored, isNull);
  });

  test('analyze : enregistre la date du scan', () async {
    await controller.analyze();
    expect((controller.state as HomeLoaded).lastScan, fixedNow);
    expect(meta.stored, fixedNow);
  });

  test("analyze : échec d'écriture → ancienne date conservée", () async {
    final previous = DateTime.utc(2026, 11, 1);
    meta
      ..stored = previous
      ..failWrites = true;
    await controller.analyze();
    expect((controller.state as HomeLoaded).lastScan, previous);
  });

  test('erreur de stockage → HomeError avec message', () async {
    repo.error = const StorageUnavailableException('indisponible');
    await controller.load();
    expect((controller.state as HomeError).message, 'indisponible');
  });

  test('erreur inattendue → HomeError générique, pas de crash', () async {
    repo.error = StateError('boom');
    await controller.load();
    expect(controller.state, isA<HomeError>());
  });

  test('appels concurrents ignorés pendant une analyse', () async {
    await controller.load();
    repo.gate = Completer<void>();
    final first = controller.analyze();
    expect((controller.state as HomeLoaded).isRefreshing, isTrue);
    await controller.analyze();
    repo.gate!.complete();
    await first;
    expect(repo.calls, 2); // load + un seul analyze
    expect((controller.state as HomeLoaded).isRefreshing, isFalse);
  });

  test('aucune notification après dispose', () async {
    final local =
        HomeController(storage: repo, metadata: meta, access: access);
    repo.gate = Completer<void>();
    final pending = local.load();
    local.dispose();
    repo.gate!.complete();
    await expectLater(pending, completes);
  });

  test("état de l'accès aux fichiers relu à chaque chargement", () async {
    await controller.load();
    expect((controller.state as HomeLoaded).hasFullAccess, isFalse);
    access.granted = true;
    await controller.load();
    expect((controller.state as HomeLoaded).hasFullAccess, isTrue);
  });

  test("demande d'accès : ouvre l'écran système", () async {
    expect(await controller.requestFullAccess(), isTrue);
    expect(access.settingsOpened, 1);
    access.settingsAvailable = false;
    expect(await controller.requestFullAccess(), isFalse);
  });
}
