import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/data/platform_storage_repository.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/domain/storage_volume_info.dart';
import 'package:storage_lens/platform/storage_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(StorageChannel.name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late PlatformStorageRepository repository;

  void respondWith(Future<Object?> Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, handler);

  setUp(() => repository = PlatformStorageRepository(StorageChannel()));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('parse les volumes et place le principal en premier', () async {
    respondWith((_) async => [
          {
            'id': '1A2B-3C4D',
            'label': 'Carte SD SanDisk',
            'primary': false,
            'removable': true,
            'totalBytes': 64000000000,
            'freeBytes': 10000000000,
          },
          {
            'id': 'primary',
            'label': 'Stockage interne partagé',
            'primary': true,
            'removable': false,
            'totalBytes': 128000000000,
            'freeBytes': 36600000000,
          },
        ]);

    final volumes = await repository.loadVolumes();

    expect(volumes, hasLength(2));
    expect(volumes.first.kind, VolumeKind.primary);
    expect(volumes.first.usedBytes, 91400000000);
    expect(volumes.last.kind, VolumeKind.removable);
  });

  test('ignore les entrées mal formées sans planter', () async {
    respondWith((_) async => [
          'pas une map',
          {'id': 'x'},
          {'id': 'y', 'label': 'Y', 'totalBytes': '12', 'freeBytes': 1},
          {'id': 'z', 'label': 'Z', 'totalBytes': 0, 'freeBytes': 0},
          null,
          {'id': 'ok', 'label': 'OK', 'totalBytes': 10, 'freeBytes': 5},
        ]);

    final volumes = await repository.loadVolumes();

    expect(volumes.map((v) => v.id), ['ok']);
    expect(volumes.single.kind, VolumeKind.other);
  });

  test('libellés Unicode et caractères spéciaux conservés', () async {
    const label = 'Mémoire « 外部 » 💾 / \\ <&>';
    respondWith((_) async => [
          {'id': 'u', 'label': label, 'totalBytes': 10, 'freeBytes': 1},
        ]);

    final volumes = await repository.loadVolumes();
    expect(volumes.single.label, label);
  });

  test('liste vide ou null → aucun volume', () async {
    respondWith((_) async => null);
    expect(await repository.loadVolumes(), isEmpty);
  });

  test('PlatformException → StorageUnavailableException', () async {
    respondWith((_) async => throw PlatformException(code: 'storage_error'));
    expect(
      repository.loadVolumes(),
      throwsA(isA<StorageUnavailableException>()),
    );
  });

  test('canal non implémenté → StorageUnavailableException', () async {
    // Aucun handler : MissingPluginException côté Flutter.
    expect(
      repository.loadVolumes(),
      throwsA(isA<StorageUnavailableException>()),
    );
  });
}
