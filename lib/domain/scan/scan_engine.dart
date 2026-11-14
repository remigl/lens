import 'dart:io';

import 'package:flutter/foundation.dart';

import 'duplicate_finder.dart';
import 'file_category.dart';
import 'scan_progress.dart';
import 'volume_scan.dart';

/// Paramètres d'une analyse. Envoyables entre isolates (types simples).
class ScanRequest {
  const ScanRequest({
    required this.volumeId,
    required this.rootPath,
    this.findDuplicates = true,
    this.largestPerCategory = 100,
    this.candidateMinBytes = 1024 * 1024,
  });

  final String volumeId;
  final String rootPath;
  final bool findDuplicates;
  final int largestPerCategory;

  /// Taille minimale pour la recherche de doublons. En dessous, l'espace
  /// récupérable est négligeable et le coût de lecture ne se justifie pas.
  final int candidateMinBytes;
}

/// Parcours en lecture seule d'un volume.
///
/// - itératif (pile explicite) : pas de récursion profonde ;
/// - ne suit jamais les liens symboliques ;
/// - ne garde en mémoire que des agrégats, les plus gros fichiers et les
///   candidats aux doublons — jamais la liste complète des fichiers ;
/// - n'ouvre aucun fichier pendant le parcours (métadonnées uniquement) ;
/// - toute erreur d'accès est comptée, jamais propagée.
class ScanEngine {
  ScanEngine(
    this.request, {
    this.onProgress,
    this.progressInterval = const Duration(milliseconds: 200),
  });

  final ScanRequest request;
  final void Function(ScanProgress progress)? onProgress;
  final Duration progressInterval;

  /// Point d'injection pour les tests (simulation d'un fichier qui
  /// disparaît entre le listage et la lecture de ses métadonnées).
  @visibleForTesting
  void Function(String path)? beforeStat;

  static const _protectedChildren = {'data', 'obb'};
  static const _downloadDirs = {'download', 'downloads'};
  static const _trashDirs = {'.trash', '.trashes', '.recycle', '.recyclebin'};
  static const _tempDirs = {'.thumbnails', 'cache', '.cache', 'tmp', '.tmp', 'temp'};

  // Arborescence (tableaux parallèles).
  final _names = <String>[''];
  final _parents = <int>[-1];
  final _direct = <int>[0];
  final _counts = <int>[0];
  final _flags = <int>[0];

  static const _flagDownload = 1;
  static const _flagTrash = 2;
  static const _flagTemp = 4;

  final _categories = {for (final c in FileCategory.values) c: SizeStat.zero};
  var _downloads = SizeStat.zero;
  var _trash = SizeStat.zero;
  var _temporary = SizeStat.zero;
  final _largest = {for (final c in FileCategory.values) c: <FileEntry>[]};
  final _candidateDirs = <int>[];
  final _candidateNames = <String>[];
  final _candidateSizes = <int>[];

  var _unreadableDirs = 0;
  var _vanished = 0;
  var _links = 0;
  final _protected = <String>[];

  var _filesSeen = 0;
  var _bytesSeen = 0;
  final _sinceProgress = Stopwatch();

  VolumeScan run() {
    final total = Stopwatch()..start();
    _sinceProgress.start();
    _walk();
    _accumulateTree();
    final tree = DirTree(
      names: _names,
      parents: _parents,
      totalBytes: _direct.toList(), // cumulés par _accumulateTree
      fileCounts: _counts,
      directBytes: _directOwn,
    );

    final candidates = <Candidate>[
      for (var i = 0; i < _candidateNames.length; i++)
        Candidate(_relativeFilePath(tree, _candidateDirs[i], _candidateNames[i]),
            _candidateSizes[i]),
    ];

    var duplicates = const <DuplicateGroup>[];
    var unreadableForDuplicates = 0;
    if (request.findDuplicates) {
      final result = _findDuplicates(candidates);
      duplicates = result.$1;
      unreadableForDuplicates = result.$2;
    }

    return VolumeScan(
      volumeId: request.volumeId,
      rootPath: request.rootPath,
      scannedAt: DateTime.now().toUtc(),
      duration: total.elapsed,
      categories: Map.of(_categories),
      downloads: _downloads,
      trash: _trash,
      temporary: _temporary,
      largestByCategory: _largest,
      tree: tree,
      duplicates: duplicates,
      candidates: candidates,
      issues: ScanIssues(
        unreadableDirs: _unreadableDirs,
        vanishedFiles: _vanished,
        skippedLinks: _links,
        protectedDirs: _protected,
        unreadableForDuplicates: unreadableForDuplicates,
      ),
    );
  }

  late final List<int> _directOwn;

  void _walk() {
    final root = _trimTrailingSlash(request.rootPath);
    final stackIndex = <int>[0];
    final stackPath = <String>[root];

    while (stackIndex.isNotEmpty) {
      final dirIndex = stackIndex.removeLast();
      final dirPath = stackPath.removeLast();

      final List<FileSystemEntity> entries;
      try {
        entries = Directory(dirPath).listSync(followLinks: false);
      } on FileSystemException {
        _unreadableDirs++;
        continue;
      }

      for (final entity in entries) {
        final name = _baseName(entity.path);
        if (entity is Link) {
          _links++;
        } else if (entity is Directory) {
          if (_isProtected(dirIndex, name)) {
            _protected.add('/Android/$name');
            continue;
          }
          stackIndex.add(_addDir(dirIndex, name));
          stackPath.add(entity.path);
        } else if (entity is File) {
          _visitFile(dirIndex, entity, name);
        }
      }
    }
    _report(force: true);
  }

  bool _isProtected(int parentIndex, String name) =>
      _parents[parentIndex] == 0 &&
      _names[parentIndex] == 'Android' &&
      _protectedChildren.contains(name);

  int _addDir(int parent, String name) {
    final lower = name.toLowerCase();
    var flags = _flags[parent];
    if (parent == 0 && _downloadDirs.contains(lower)) flags |= _flagDownload;
    if (_trashDirs.contains(lower)) flags |= _flagTrash;
    if (_tempDirs.contains(lower)) flags |= _flagTemp;

    _names.add(name);
    _parents.add(parent);
    _direct.add(0);
    _counts.add(0);
    _flags.add(flags);
    return _names.length - 1;
  }

  void _visitFile(int dirIndex, File file, String name) {
    beforeStat?.call(file.path);
    final FileStat stat;
    try {
      stat = file.statSync();
    } on FileSystemException {
      _vanished++;
      return;
    }
    if (stat.type == FileSystemEntityType.notFound) {
      _vanished++;
      return;
    }
    if (stat.type != FileSystemEntityType.file) return;

    final size = stat.size < 0 ? 0 : stat.size;
    final category = FileCategory.of(name);
    _categories[category] = _categories[category]!.add(size);
    _direct[dirIndex] += size;
    _counts[dirIndex]++;

    final flags = _flags[dirIndex];
    final lower = name.toLowerCase();
    if (flags & _flagDownload != 0) _downloads = _downloads.add(size);
    if (flags & _flagTrash != 0 || lower.startsWith('.trashed-')) {
      _trash = _trash.add(size);
    }
    if (flags & _flagTemp != 0 || lower.endsWith('.tmp') || lower.endsWith('.temp')) {
      _temporary = _temporary.add(size);
    }

    _keepIfLarge(category, dirIndex, name, size, stat.modified);
    if (size >= request.candidateMinBytes) {
      _candidateDirs.add(dirIndex);
      _candidateNames.add(name);
      _candidateSizes.add(size);
    }

    _filesSeen++;
    _bytesSeen += size;
    _report();
  }

  // Les plus gros fichiers par catégorie : liste triée bornée
  // (insertion dichotomique, pas de tri global de tous les fichiers).
  final _pendingLargest = <FileCategory, List<(int, String, int, int)>>{
    for (final c in FileCategory.values) c: [],
  };

  void _keepIfLarge(
    FileCategory category,
    int dirIndex,
    String name,
    int size,
    DateTime modified,
  ) {
    final list = _pendingLargest[category]!;
    final limit = request.largestPerCategory;
    if (list.length >= limit && size <= list.last.$3) return;
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].$3 >= size) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    list.insert(lo, (dirIndex, name, size, modified.millisecondsSinceEpoch));
    if (list.length > limit) list.removeLast();
  }

  /// Cumule les tailles des sous-dossiers dans leurs parents. Les index
  /// enfants étant toujours supérieurs à ceux des parents, un seul passage
  /// en ordre inverse suffit.
  void _accumulateTree() {
    _directOwn = List.of(_direct);
    for (var i = _names.length - 1; i > 0; i--) {
      final parent = _parents[i];
      _direct[parent] += _direct[i];
      _counts[parent] += _counts[i];
    }
    final treeForPaths = DirTree(
      names: _names,
      parents: _parents,
      totalBytes: _direct,
      fileCounts: _counts,
      directBytes: _directOwn,
    );
    for (final category in FileCategory.values) {
      _largest[category] = [
        for (final (dir, name, size, mtime) in _pendingLargest[category]!)
          FileEntry(
            relativePath: _relativeFilePath(treeForPaths, dir, name),
            size: size,
            modifiedMs: mtime,
            category: category,
          ),
      ];
    }
  }

  (List<DuplicateGroup>, int) _findDuplicates(List<Candidate> candidates) {
    final finder = DuplicateFinder(
      onProgress: (checked, toCheck) => _reportDuplicates(checked, toCheck),
    );
    final root = _trimTrailingSlash(request.rootPath);
    final result = finder.find([
      for (final c in candidates) DuplicateInput('$root${c.relativePath}', c.size),
    ]);
    final groups = [
      for (final g in result.groups)
        DuplicateGroup(
          size: g.first.size,
          paths: [for (final f in g) f.path.substring(root.length)],
        ),
    ];
    return (groups, result.unreadable);
  }

  void _report({bool force = false}) {
    if (onProgress == null) return;
    if (!force && _sinceProgress.elapsed < progressInterval) return;
    _sinceProgress.reset();
    onProgress!(ScanProgress(
      phase: ScanPhase.listing,
      filesSeen: _filesSeen,
      bytesSeen: _bytesSeen,
    ));
  }

  void _reportDuplicates(int checked, int toCheck) {
    if (onProgress == null) return;
    if (checked != 0 &&
        checked != toCheck &&
        _sinceProgress.elapsed < progressInterval) {
      return;
    }
    _sinceProgress.reset();
    onProgress!(ScanProgress(
      phase: ScanPhase.duplicates,
      filesSeen: _filesSeen,
      bytesSeen: _bytesSeen,
      duplicateBytesChecked: checked,
      duplicateBytesToCheck: toCheck,
    ));
  }

  static String _relativeFilePath(DirTree tree, int dir, String name) {
    final dirPath = tree.pathOf(dir);
    return dirPath == '/' ? '/$name' : '$dirPath/$name';
  }

  static String _baseName(String path) {
    final trimmed = _trimTrailingSlash(path);
    final slash = trimmed.lastIndexOf(Platform.pathSeparator);
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static String _trimTrailingSlash(String path) =>
      path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}
