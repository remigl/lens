import 'file_category.dart';

/// Taille et nombre de fichiers d'un ensemble.
class SizeStat {
  const SizeStat(this.bytes, this.count);

  static const zero = SizeStat(0, 0);

  final int bytes;
  final int count;

  SizeStat add(int size) => SizeStat(bytes + size, count + 1);

  List<int> toJson() => [bytes, count];

  static SizeStat fromJson(Object? json) {
    if (json is List && json.length == 2 && json[0] is int && json[1] is int) {
      return SizeStat(json[0] as int, json[1] as int);
    }
    return zero;
  }
}

/// Un fichier remarquable (volumineux). Chemin relatif à la racine du volume.
class FileEntry {
  const FileEntry({
    required this.relativePath,
    required this.size,
    required this.modifiedMs,
    required this.category,
  });

  final String relativePath;
  final int size;
  final int modifiedMs;
  final FileCategory category;

  String get name {
    final slash = relativePath.lastIndexOf('/');
    return slash < 0 ? relativePath : relativePath.substring(slash + 1);
  }

  String get folder {
    final slash = relativePath.lastIndexOf('/');
    return slash <= 0 ? '/' : relativePath.substring(0, slash);
  }

  DateTime? get modified => modifiedMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(modifiedMs, isUtc: true)
      : null;

  List<Object> toJson() => [relativePath, size, modifiedMs, category.index];

  static FileEntry? fromJson(Object? json) {
    if (json is! List || json.length != 4) return null;
    final [path, size, mtime, cat] = json;
    if (path is! String || size is! int || mtime is! int || cat is! int) {
      return null;
    }
    if (cat < 0 || cat >= FileCategory.values.length) return null;
    return FileEntry(
      relativePath: path,
      size: size,
      modifiedMs: mtime,
      category: FileCategory.values[cat],
    );
  }
}

/// Arborescence compacte des dossiers (tableaux parallèles, index 0 = racine).
/// Les tailles sont cumulées (sous-dossiers inclus).
class DirTree {
  DirTree({
    required this.names,
    required this.parents,
    required this.totalBytes,
    required this.fileCounts,
    required this.directBytes,
  });

  final List<String> names;
  final List<int> parents;
  final List<int> totalBytes;
  final List<int> fileCounts;
  final List<int> directBytes;

  int get length => names.length;

  List<List<int>>? _children;

  /// Sous-dossiers de [index], triés par taille décroissante.
  List<int> childrenOf(int index) {
    final children = _children ??= _buildChildren();
    return children[index];
  }

  List<List<int>> _buildChildren() {
    final result = List.generate(length, (_) => <int>[]);
    for (var i = 1; i < length; i++) {
      final parent = parents[i];
      if (parent >= 0 && parent < length) result[parent].add(i);
    }
    for (final list in result) {
      list.sort((a, b) => totalBytes[b].compareTo(totalBytes[a]));
    }
    return result;
  }

  String pathOf(int index) {
    final parts = <String>[];
    for (var i = index; i > 0; i = parents[i]) {
      parts.add(names[i]);
    }
    return '/${parts.reversed.join('/')}';
  }

  Map<String, Object> toJson() => {
        'names': names,
        'parents': parents,
        'total': totalBytes,
        'counts': fileCounts,
        'direct': directBytes,
      };

  static DirTree? fromJson(Object? json) {
    if (json is! Map) return null;
    final names = _list<String>(json['names']);
    final parents = _list<int>(json['parents']);
    final total = _list<int>(json['total']);
    final counts = _list<int>(json['counts']);
    final direct = _list<int>(json['direct']);
    if (names == null ||
        parents == null ||
        total == null ||
        counts == null ||
        direct == null) {
      return null;
    }
    final n = names.length;
    if (n == 0 ||
        parents.length != n ||
        total.length != n ||
        counts.length != n ||
        direct.length != n) {
      return null;
    }
    // Chaque parent doit précéder son enfant : garantit l'absence de cycle.
    for (var i = 1; i < n; i++) {
      if (parents[i] < 0 || parents[i] >= i) return null;
    }
    return DirTree(
      names: names,
      parents: parents,
      totalBytes: total,
      fileCounts: counts,
      directBytes: direct,
    );
  }
}

List<T>? _list<T>(Object? json) {
  if (json is! List) return null;
  final out = <T>[];
  for (final e in json) {
    if (e is! T) return null;
    out.add(e);
  }
  return out;
}

/// Fichiers au contenu strictement identique (vérifié octet par octet).
class DuplicateGroup {
  const DuplicateGroup({required this.size, required this.paths});

  final int size;
  final List<String> paths;

  int get totalBytes => size * paths.length;

  /// Espace occupé par les copies au-delà de la première.
  int get extraBytes => size * (paths.length - 1);

  Map<String, Object> toJson() => {'size': size, 'paths': paths};

  static DuplicateGroup? fromJson(Object? json) {
    if (json is! Map) return null;
    final size = json['size'];
    final paths = _list<String>(json['paths']);
    if (size is! int || paths == null || paths.length < 2) return null;
    return DuplicateGroup(size: size, paths: paths);
  }
}

/// Fichier candidat (taille ≥ seuil) conservé pour les comparaisons.
class Candidate {
  const Candidate(this.relativePath, this.size);

  final String relativePath;
  final int size;
}

/// Ce que l'analyse n'a pas pu voir : affiché honnêtement à l'utilisateur.
class ScanIssues {
  const ScanIssues({
    this.unreadableDirs = 0,
    this.vanishedFiles = 0,
    this.skippedLinks = 0,
    this.protectedDirs = const [],
    this.unreadableForDuplicates = 0,
  });

  final int unreadableDirs;
  final int vanishedFiles;
  final int skippedLinks;
  final List<String> protectedDirs;
  final int unreadableForDuplicates;

  bool get isEmpty =>
      unreadableDirs == 0 &&
      vanishedFiles == 0 &&
      skippedLinks == 0 &&
      protectedDirs.isEmpty &&
      unreadableForDuplicates == 0;

  Map<String, Object> toJson() => {
        'unreadable': unreadableDirs,
        'vanished': vanishedFiles,
        'links': skippedLinks,
        'protected': protectedDirs,
        'dupUnreadable': unreadableForDuplicates,
      };

  static ScanIssues fromJson(Object? json) {
    if (json is! Map) return const ScanIssues();
    int i(String k) => json[k] is int ? json[k] as int : 0;
    return ScanIssues(
      unreadableDirs: i('unreadable'),
      vanishedFiles: i('vanished'),
      skippedLinks: i('links'),
      protectedDirs: _list<String>(json['protected']) ?? const [],
      unreadableForDuplicates: i('dupUnreadable'),
    );
  }
}

/// Résultat complet de l'analyse d'un volume.
class VolumeScan {
  VolumeScan({
    required this.volumeId,
    required this.rootPath,
    required this.scannedAt,
    required this.duration,
    required this.categories,
    required this.downloads,
    required this.trash,
    required this.temporary,
    required this.largestByCategory,
    required this.tree,
    required this.duplicates,
    required this.candidates,
    required this.issues,
  });

  static const schemaVersion = 1;

  final String volumeId;
  final String rootPath;
  final DateTime scannedAt;
  final Duration duration;
  final Map<FileCategory, SizeStat> categories;
  final SizeStat downloads;
  final SizeStat trash;
  final SizeStat temporary;
  final Map<FileCategory, List<FileEntry>> largestByCategory;
  final DirTree tree;
  final List<DuplicateGroup> duplicates;
  final List<Candidate> candidates;
  final ScanIssues issues;

  SizeStat get total => categories.values.fold(
        SizeStat.zero,
        (a, b) => SizeStat(a.bytes + b.bytes, a.count + b.count),
      );

  SizeStat category(FileCategory c) => categories[c] ?? SizeStat.zero;

  /// Catégories non vides, de la plus volumineuse à la plus petite.
  List<FileCategory> get sortedCategories => FileCategory.values
      .where((c) => category(c).count > 0)
      .toList()
    ..sort((a, b) => category(b).bytes.compareTo(category(a).bytes));

  /// Les [limit] plus gros fichiers, toutes catégories confondues.
  List<FileEntry> largestFiles({int limit = 100}) {
    final all = largestByCategory.values.expand((e) => e).toList()
      ..sort((a, b) => b.size.compareTo(a.size));
    return all.length > limit ? all.sublist(0, limit) : all;
  }

  int get duplicateExtraBytes =>
      duplicates.fold(0, (sum, g) => sum + g.extraBytes);

  String absolutePath(String relativePath) =>
      rootPath.endsWith('/') ? '$rootPath${relativePath.substring(1)}' : '$rootPath$relativePath';

  Map<String, Object> toJson() => {
        'v': schemaVersion,
        'volumeId': volumeId,
        'root': rootPath,
        'at': scannedAt.toUtc().millisecondsSinceEpoch,
        'durationMs': duration.inMilliseconds,
        'categories': [
          for (final c in FileCategory.values) category(c).toJson(),
        ],
        'downloads': downloads.toJson(),
        'trash': trash.toJson(),
        'temporary': temporary.toJson(),
        'largest': [
          for (final c in FileCategory.values)
            [for (final f in largestByCategory[c] ?? const <FileEntry>[]) f.toJson()],
        ],
        'tree': tree.toJson(),
        'duplicates': [for (final g in duplicates) g.toJson()],
        'candidates': [
          for (final c in candidates) [c.relativePath, c.size],
        ],
        'issues': issues.toJson(),
      };

  /// Lecture défensive : renvoie `null` si le cache est invalide.
  static VolumeScan? fromJson(Object? json) {
    if (json is! Map || json['v'] != schemaVersion) return null;
    final volumeId = json['volumeId'];
    final root = json['root'];
    final at = json['at'];
    final durationMs = json['durationMs'];
    final cats = json['categories'];
    final largest = json['largest'];
    final tree = DirTree.fromJson(json['tree']);
    if (volumeId is! String ||
        root is! String ||
        at is! int ||
        durationMs is! int ||
        cats is! List ||
        cats.length != FileCategory.values.length ||
        largest is! List ||
        largest.length != FileCategory.values.length ||
        tree == null) {
      return null;
    }

    final candidates = <Candidate>[];
    final rawCandidates = json['candidates'];
    if (rawCandidates is List) {
      for (final c in rawCandidates) {
        if (c is List && c.length == 2 && c[0] is String && c[1] is int) {
          candidates.add(Candidate(c[0] as String, c[1] as int));
        }
      }
    }
    final rawDuplicates = json['duplicates'];

    return VolumeScan(
      volumeId: volumeId,
      rootPath: root,
      scannedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      duration: Duration(milliseconds: durationMs),
      categories: {
        for (final c in FileCategory.values) c: SizeStat.fromJson(cats[c.index]),
      },
      downloads: SizeStat.fromJson(json['downloads']),
      trash: SizeStat.fromJson(json['trash']),
      temporary: SizeStat.fromJson(json['temporary']),
      largestByCategory: {
        for (final c in FileCategory.values)
          c: [
            if (largest[c.index] is List)
              for (final f in largest[c.index] as List)
                ?FileEntry.fromJson(f),
          ],
      },
      tree: tree,
      duplicates: [
        if (rawDuplicates is List)
          for (final g in rawDuplicates) ?DuplicateGroup.fromJson(g),
      ],
      candidates: candidates,
      issues: ScanIssues.fromJson(json['issues']),
    );
  }
}
