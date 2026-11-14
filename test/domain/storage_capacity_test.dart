import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/storage_capacity.dart';

const _gib = 1 << 30;

void main() {
  test('Samsung : 128 Gio (137,4 Go) → 128 Go', () {
    expect(marketedCapacityBytes(128 * _gib), 128000000000);
  });

  test('AOSP : déjà arrondi en base 1000 → inchangé', () {
    expect(marketedCapacityBytes(128000000000), 128000000000);
    expect(marketedCapacityBytes(256000000000), 256000000000);
  });

  test('taille brute StatFs (partition plus petite) → capacité supérieure', () {
    expect(marketedCapacityBytes(110 * _gib), 128000000000);
    expect(marketedCapacityBytes(59 * _gib), 64000000000);
  });

  test('légèrement au-dessus (≤ 1 %) → reste sur la même capacité', () {
    expect(marketedCapacityBytes((128.5 * _gib).round()), 128000000000);
  });

  test('1 To et 2 To', () {
    expect(marketedCapacityBytes(1024 * _gib), 1024000000000);
    expect(marketedCapacityBytes(2000000000000), 2048000000000);
  });

  test('petits volumes (< 1 Gio) laissés tels quels', () {
    expect(marketedCapacityBytes(10), 10);
    expect(marketedCapacityBytes(0), 0);
  });
}
