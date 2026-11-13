import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/core/format/date_formatter.dart';

void main() {
  final now = DateTime(2026, 11, 13, 18, 30);

  test("aujourd'hui", () {
    expect(
      formatLastScan(DateTime(2026, 11, 13, 9, 5), now: now),
      "Aujourd'hui à 09:05",
    );
  });

  test('hier, y compris juste avant minuit', () {
    expect(
      formatLastScan(DateTime(2026, 11, 12, 23, 59), now: now),
      'Hier à 23:59',
    );
  });

  test('date complète au-delà', () {
    expect(
      formatLastScan(DateTime(2026, 1, 2, 7, 0), now: now),
      '02/01/2026 à 07:00',
    );
  });

  test('changement d\'heure (fin mars) : reste « hier »', () {
    expect(
      formatLastScan(
        DateTime(2026, 3, 28, 22, 0),
        now: DateTime(2026, 3, 29, 1, 0),
      ),
      'Hier à 22:00',
    );
  });
}
