import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/core/format/byte_formatter.dart';

const _s = ' ';

void main() {
  group('formatBytes', () {
    test('zéro et valeurs négatives', () {
      expect(formatBytes(0), '0${_s}o');
      expect(formatBytes(-42), '0${_s}o');
    });

    test('octets sans décimale', () {
      expect(formatBytes(1), '1${_s}o');
      expect(formatBytes(999), '999${_s}o');
    });

    test('exemples du cahier des charges', () {
      expect(formatBytes(128000000000), '128${_s}Go');
      expect(formatBytes(91400000000), '91,4${_s}Go');
      expect(formatBytes(36600000000), '36,6${_s}Go');
    });

    test('virgule décimale et suppression du ,0', () {
      expect(formatBytes(1500), '1,5${_s}Ko');
      expect(formatBytes(2000000), '2${_s}Mo');
    });

    test('pas de « 1000 Mo » : passage à l\'unité supérieure', () {
      expect(formatBytes(999600000), '1${_s}Go');
      expect(formatBytes(999400000), '999${_s}Mo');
    });

    test('arrondi à 100 sans décimale', () {
      expect(formatBytes(99960000000), '100${_s}Go');
    });

    test('très grands volumes', () {
      expect(formatBytes(2000000000000), '2${_s}To');
      expect(formatBytes(1024 * 1024 * 1024 * 1024 * 1024), '1,1${_s}Po');
    });
  });

  group('formatPercent', () {
    test('bornes et arrondi', () {
      expect(formatPercent(0), '0$_s%');
      expect(formatPercent(0.714), '71$_s%');
      expect(formatPercent(1.5), '100$_s%');
      expect(formatPercent(-1), '0$_s%');
      expect(formatPercent(double.nan), '0$_s%');
    });
  });
}
