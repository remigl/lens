import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/scan/duplicate_finder.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('dupes_'));
  tearDown(() => root.deleteSync(recursive: true));

  DuplicateInput file(String name, List<int> bytes) {
    final f = File('${root.path}/$name')..writeAsBytesSync(bytes);
    return DuplicateInput(f.path, bytes.length);
  }

  List<int> pattern(int size, int seed) =>
      Uint8List.fromList(List.generate(size, (i) => (i * 31 + seed) & 0xff));

  Set<Set<String>> namesOf(DuplicateResult r) => {
        for (final g in r.groups)
          {for (final f in g) f.path.substring(root.path.length + 1)},
      };

  test('trois copies identiques → un groupe', () {
    final data = pattern(300000, 1);
    final result = DuplicateFinder().find([
      file('a', data),
      file('b', data),
      file('c', data),
    ]);
    expect(namesOf(result), {
      {'a', 'b', 'c'},
    });
  });

  test('même début et même fin, milieu différent → pas de doublon', () {
    final a = pattern(500000, 3);
    final b = Uint8List.fromList(a)..[250000] ^= 0xff;
    final result = DuplicateFinder().find([file('a', a), file('b', b)]);
    expect(result.groups, isEmpty);
  });

  test('un seul octet différent sur un petit fichier → pas de doublon', () {
    final a = pattern(1000, 5);
    final b = Uint8List.fromList(a)..[999] ^= 1;
    expect(DuplicateFinder().find([file('a', a), file('b', b)]).groups, isEmpty);
  });

  test('deux classes distinctes de même taille', () {
    final x = pattern(200000, 1);
    final y = pattern(200000, 2);
    final result = DuplicateFinder().find([
      file('x1', x),
      file('y1', y),
      file('x2', x),
      file('y2', y),
      file('seul', pattern(200000, 9)),
    ]);
    expect(namesOf(result), {
      {'x1', 'x2'},
      {'y1', 'y2'},
    });
  });

  test('tailles différentes : aucune lecture nécessaire', () {
    final result = DuplicateFinder().find([
      const DuplicateInput('/inexistant/a', 10),
      const DuplicateInput('/inexistant/b', 11),
    ]);
    expect(result.groups, isEmpty);
    expect(result.unreadable, 0);
  });

  test('fichier disparu avant comparaison : ignoré et compté', () {
    final data = pattern(1000, 1);
    final a = file('a', data);
    final b = file('b', data);
    File(b.path).deleteSync();
    final result = DuplicateFinder().find([a, b]);
    expect(result.groups, isEmpty);
    expect(result.unreadable, 1);
  });

  test('fichier modifié (taille changée) depuis le parcours : écarté', () {
    final data = pattern(1000, 1);
    final a = file('a', data);
    final b = file('b', data);
    final c = file('c', data);
    File(c.path).writeAsBytesSync(pattern(1200, 1));
    final result = DuplicateFinder().find([a, b, c]);
    expect(namesOf(result), {
      {'a', 'b'},
    });
  });

  test('progression : de 0 à 100 %', () {
    final data = pattern(3 * 1024 * 1024 + 5, 4);
    final calls = <(int, int)>[];
    DuplicateFinder(onProgress: (c, t) => calls.add((c, t))).find([
      file('a', data),
      file('b', data),
    ]);
    expect(calls.first.$1, 0);
    expect(calls.last.$1, calls.last.$2);
    expect(calls.last.$2, 2 * data.length);
  });

  test('groupes triés par espace occupé par les copies', () {
    final small = pattern(100, 1);
    final big = pattern(100000, 2);
    final result = DuplicateFinder().find([
      file('s1', small),
      file('s2', small),
      file('b1', big),
      file('b2', big),
    ]);
    expect(result.groups.first.first.size, 100000);
  });
}
