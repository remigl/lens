import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/storage_volume_info.dart';

StorageVolumeInfo _volume({required int total, required int free}) =>
    StorageVolumeInfo.sanitized(
      id: 'primary',
      label: 'Stockage interne',
      kind: VolumeKind.primary,
      totalBytes: total,
      freeBytes: free,
    );

void main() {
  test('calcule utilisé et fraction', () {
    final v = _volume(total: 128000000000, free: 36600000000);
    expect(v.usedBytes, 91400000000);
    expect(v.usedFraction, closeTo(0.714, 0.001));
    expect(v.isAlmostFull, isFalse);
  });

  test('libre > total est borné', () {
    final v = _volume(total: 100, free: 500);
    expect(v.freeBytes, 100);
    expect(v.usedBytes, 0);
  });

  test('valeurs négatives neutralisées', () {
    final v = _volume(total: -1, free: -1);
    expect(v.totalBytes, 0);
    expect(v.freeBytes, 0);
    expect(v.usedFraction, 0);
    expect(v.isAlmostFull, isFalse);
  });

  test('stockage presque plein (< 10 % libre)', () {
    expect(_volume(total: 1000, free: 99).isAlmostFull, isTrue);
    expect(_volume(total: 1000, free: 100).isAlmostFull, isFalse);
    expect(_volume(total: 1000, free: 0).isAlmostFull, isTrue);
  });

  test('très grand volume (2 To) sans débordement', () {
    final v = _volume(total: 2000000000000, free: 1);
    expect(v.usedBytes, 1999999999999);
  });
}
