import 'dart:io';
import 'dart:typed_data';

/// Fichier à examiner : chemin absolu + taille connue lors du parcours.
class DuplicateInput {
  const DuplicateInput(this.path, this.size);

  final String path;
  final int size;
}

class DuplicateResult {
  const DuplicateResult(this.groups, this.unreadable);

  /// Groupes de chemins au contenu strictement identique (≥ 2 chacun).
  final List<List<DuplicateInput>> groups;

  /// Fichiers illisibles ou disparus pendant la vérification.
  final int unreadable;
}

/// Détection prudente des doublons, en lecture seule :
///
/// 1. regroupement par taille (aucune lecture) ;
/// 2. empreinte rapide du début et de la fin (2 × 64 Kio) pour écarter
///    les fichiers manifestement différents ;
/// 3. **comparaison octet par octet** des candidats restants.
///
/// L'étape 3 est plus stricte qu'un hash cryptographique : deux fichiers ne
/// sont déclarés identiques que si tous leurs octets ont été comparés.
/// Le nom des fichiers n'intervient jamais.
class DuplicateFinder {
  DuplicateFinder({this.onProgress});

  /// (octets vérifiés, octets à vérifier) pendant l'étape 3.
  final void Function(int checked, int toCheck)? onProgress;

  static const _edgeBytes = 64 * 1024;
  static const _chunkBytes = 1024 * 1024;

  int _unreadable = 0;
  int _checked = 0;
  int _toCheck = 0;
  final _bufferA = Uint8List(_chunkBytes);
  final _bufferB = Uint8List(_chunkBytes);

  DuplicateResult find(Iterable<DuplicateInput> inputs) {
    final bySize = <int, List<DuplicateInput>>{};
    for (final input in inputs) {
      if (input.size <= 0) continue;
      (bySize[input.size] ??= []).add(input);
    }

    final suspects = <List<DuplicateInput>>[];
    for (final group in bySize.values) {
      if (group.length < 2) continue;
      suspects.addAll(_splitByEdges(group));
    }

    _toCheck = suspects.fold(0, (sum, g) => sum + g.first.size * g.length);
    onProgress?.call(0, _toCheck);

    final groups = <List<DuplicateInput>>[];
    for (final group in suspects) {
      groups.addAll(_splitByContent(group));
    }
    groups.sort((a, b) =>
        (b.first.size * (b.length - 1)).compareTo(a.first.size * (a.length - 1)));
    return DuplicateResult(groups, _unreadable);
  }

  List<List<DuplicateInput>> _splitByEdges(List<DuplicateInput> group) {
    final byKey = <int, List<DuplicateInput>>{};
    for (final input in group) {
      final key = _edgeFingerprint(input);
      if (key == null) {
        _unreadable++;
        continue;
      }
      (byKey[key] ??= []).add(input);
    }
    return [for (final g in byKey.values) if (g.length >= 2) g];
  }

  /// Partitionne en classes d'équivalence exactes, en comparant chaque
  /// fichier au représentant de chaque classe (2 fichiers ouverts au plus).
  List<List<DuplicateInput>> _splitByContent(List<DuplicateInput> group) {
    final classes = <List<DuplicateInput>>[];
    for (final input in group) {
      var placed = false;
      var readable = true;
      for (final members in classes) {
        final same = _sameContent(members.first, input);
        if (same == null) {
          readable = false;
          break;
        }
        if (same) {
          members.add(input);
          placed = true;
          break;
        }
      }
      if (!readable) {
        _unreadable++;
      } else if (!placed) {
        classes.add([input]);
      }
      _checked += input.size;
      onProgress?.call(_checked.clamp(0, _toCheck), _toCheck);
    }
    return [for (final c in classes) if (c.length >= 2) c];
  }

  /// `null` si l'un des fichiers ne peut pas être lu entièrement.
  bool? _sameContent(DuplicateInput a, DuplicateInput b) {
    RandomAccessFile? fa;
    RandomAccessFile? fb;
    try {
      fa = File(a.path).openSync();
      fb = File(b.path).openSync();
      if (fa.lengthSync() != a.size || fb.lengthSync() != b.size) return null;
      var remaining = a.size;
      while (remaining > 0) {
        final want = remaining < _chunkBytes ? remaining : _chunkBytes;
        final readA = fa.readIntoSync(_bufferA, 0, want);
        final readB = fb.readIntoSync(_bufferB, 0, want);
        if (readA != want || readB != want) return null;
        if (!_equalBytes(_bufferA, _bufferB, want)) return false;
        remaining -= want;
      }
      return true;
    } on FileSystemException {
      return null;
    } finally {
      _closeQuietly(fa);
      _closeQuietly(fb);
    }
  }

  int? _edgeFingerprint(DuplicateInput input) {
    RandomAccessFile? file;
    try {
      file = File(input.path).openSync();
      var hash = _fnvOffset;
      final headLength = input.size < _edgeBytes ? input.size : _edgeBytes;
      final head = file.readSync(headLength);
      if (head.length != headLength) return null;
      hash = _fnv1a(hash, head);
      if (input.size > _edgeBytes) {
        final tailStart =
            input.size - _edgeBytes > headLength ? input.size - _edgeBytes : headLength;
        file.setPositionSync(tailStart);
        final tail = file.readSync(input.size - tailStart);
        if (tail.length != input.size - tailStart) return null;
        hash = _fnv1a(hash, tail);
      }
      return hash;
    } on FileSystemException {
      return null;
    } finally {
      _closeQuietly(file);
    }
  }

  static bool _equalBytes(Uint8List a, Uint8List b, int length) {
    final words = length ~/ 8;
    if (words > 0) {
      final wa = a.buffer.asUint64List(a.offsetInBytes, words);
      final wb = b.buffer.asUint64List(b.offsetInBytes, words);
      for (var i = 0; i < words; i++) {
        if (wa[i] != wb[i]) return false;
      }
    }
    for (var i = words * 8; i < length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // FNV-1a 64 bits : simple pré-filtre (non cryptographique, jamais utilisé
  // seul pour conclure). Les entiers Dart natifs bouclent sur 64 bits.
  static const _fnvOffset = 0xcbf29ce484222325;
  static const _fnvPrime = 0x100000001b3;

  static int _fnv1a(int hash, List<int> bytes) {
    var h = hash;
    for (final b in bytes) {
      h ^= b;
      h *= _fnvPrime;
    }
    return h;
  }

  static void _closeQuietly(RandomAccessFile? file) {
    try {
      file?.closeSync();
    } on FileSystemException {
      // Rien à faire : fichier déjà fermé ou disparu.
    }
  }
}
