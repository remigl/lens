import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../domain/scan/duplicate_finder.dart';
import '../../domain/scan/scan_engine.dart';
import '../../domain/scan/scan_progress.dart';
import '../../domain/scan/volume_scan.dart';

class ScanCancelledException implements Exception {
  const ScanCancelledException();
}

class ScanFailedException implements Exception {
  const ScanFailedException(this.reason);

  final String reason;
}

/// Tâche longue exécutée dans un isolate séparé : l'interface reste fluide.
/// L'annulation tue l'isolate immédiatement (aucune écriture à interrompre :
/// l'analyse est en lecture seule).
class BackgroundJob<T> {
  BackgroundJob._(this._result, this._progress, this._cancel);

  /// Tâche pilotée à la main (tests).
  @visibleForTesting
  BackgroundJob.manual(this._result, this._progress, this._cancel);

  final Future<T> _result;
  final Stream<ScanProgress> _progress;
  final void Function() _cancel;

  Future<T> get result => _result;
  Stream<ScanProgress> get progress => _progress;
  void cancel() => _cancel();

  static BackgroundJob<T> start<T>(
    T Function(void Function(ScanProgress) report) work,
  ) {
    final progress = StreamController<ScanProgress>.broadcast();
    final completer = Completer<T>();
    final port = ReceivePort();
    Isolate? isolate;
    var cancelled = false;

    void finish() {
      port.close();
      if (!progress.isClosed) unawaited(progress.close());
    }

    port.listen((message) {
      switch (message) {
        case final ScanProgress p:
          if (!progress.isClosed) progress.add(p);
        case _Done(:final Object? value):
          if (!completer.isCompleted) completer.complete(value as T);
          finish();
        case _Failed(:final String reason):
          if (!completer.isCompleted) {
            completer.completeError(ScanFailedException(reason));
          }
          finish();
      }
    });

    Isolate.spawn<_Start<T>>(
      _entry<T>,
      _Start(port.sendPort, work),
      errorsAreFatal: true,
      debugName: 'storage_lens_scan',
    ).then((spawned) {
      isolate = spawned;
      if (cancelled) spawned.kill(priority: Isolate.immediate);
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.completeError(ScanFailedException(e.runtimeType.toString()));
      }
      finish();
    });

    void cancel() {
      if (completer.isCompleted) return;
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      completer.completeError(const ScanCancelledException());
      finish();
    }

    return BackgroundJob._(completer.future, progress.stream, cancel);
  }

  static void _entry<T>(_Start<T> start) {
    try {
      final value = start.work(start.port.send);
      start.port.send(_Done(value));
    } on Object catch (e) {
      // Type d'erreur uniquement : aucun chemin ni contenu ne sort.
      start.port.send(_Failed(e.runtimeType.toString()));
    }
  }
}

class _Start<T> {
  const _Start(this.port, this.work);

  final SendPort port;
  final T Function(void Function(ScanProgress)) work;
}

class _Done {
  const _Done(this.value);

  final Object? value;
}

class _Failed {
  const _Failed(this.reason);

  final String reason;
}

/// Lance l'analyse d'un volume en arrière-plan.
BackgroundJob<VolumeScan> startVolumeScan(ScanRequest request) =>
    BackgroundJob.start((report) => ScanEngine(request, onProgress: report).run());

/// Fichiers identiques présents sur deux volumes (contenu vérifié).
class CrossVolumeMatch {
  const CrossVolumeMatch({
    required this.size,
    required this.pathsA,
    required this.pathsB,
  });

  final int size;
  final List<String> pathsA;
  final List<String> pathsB;
}

/// Compare les candidats de deux analyses et ne garde que les groupes
/// identiques présents sur les deux volumes à la fois.
BackgroundJob<List<CrossVolumeMatch>> startCrossVolumeComparison(
  VolumeScan a,
  VolumeScan b,
) {
  final rootA = a.rootPath;
  final rootB = b.rootPath;
  final inputsA = [for (final c in a.candidates) (c.relativePath, c.size)];
  final inputsB = [for (final c in b.candidates) (c.relativePath, c.size)];

  return BackgroundJob.start((report) {
    final sizesB = {for (final c in inputsB) c.$2};
    final sizesA = {for (final c in inputsA) c.$2};
    // Seules les tailles présentes des deux côtés peuvent correspondre.
    final inputs = [
      for (final c in inputsA)
        if (sizesB.contains(c.$2)) DuplicateInput('$rootA${c.$1}', c.$2),
      for (final c in inputsB)
        if (sizesA.contains(c.$2)) DuplicateInput('$rootB${c.$1}', c.$2),
    ];
    final finder = DuplicateFinder(
      onProgress: (checked, toCheck) => report(ScanProgress(
        phase: ScanPhase.duplicates,
        filesSeen: inputs.length,
        bytesSeen: 0,
        duplicateBytesChecked: checked,
        duplicateBytesToCheck: toCheck,
      )),
    );
    final result = finder.find(inputs);
    final matches = <CrossVolumeMatch>[];
    for (final group in result.groups) {
      final inA = [
        for (final f in group)
          if (f.path.startsWith('$rootA/')) f.path.substring(rootA.length),
      ];
      final inB = [
        for (final f in group)
          if (f.path.startsWith('$rootB/')) f.path.substring(rootB.length),
      ];
      if (inA.isNotEmpty && inB.isNotEmpty) {
        matches.add(CrossVolumeMatch(
          size: group.first.size,
          pathsA: inA,
          pathsB: inB,
        ));
      }
    }
    return matches;
  });
}
