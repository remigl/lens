import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storage_lens/domain/scan/volume_scan.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/domain/storage_volume_info.dart';
import 'package:storage_lens/presentation/compare/compare_screen.dart';
import 'package:storage_lens/presentation/home/home_controller.dart';
import 'package:storage_lens/presentation/home/home_screen.dart';
import 'package:storage_lens/presentation/privacy/privacy_screen.dart';
import 'package:storage_lens/presentation/scan/scan_controller.dart';
import 'package:storage_lens/presentation/volume/volume_screen.dart';

import 'fakes.dart';

/// Fait défiler la liste jusqu'à ce que [finder] soit construit et visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  final now = DateTime(2026, 11, 13, 18, 0);

  Future<(HomeController, ScanController, MemoryScanCache)> pumpHome(
    WidgetTester tester,
    List<StorageVolumeInfo> volumes, {
    FakeFileAccessRepository? access,
    Object? error,
    ManualScan? manual,
    Map<String, VolumeScan> cached = const {},
  }) async {
    final repo = FakeStorageRepository(volumes)..error = error;
    final controller = HomeController(
      storage: repo,
      access: access ?? FakeFileAccessRepository(granted: true),
    );
    final cache = MemoryScanCache()..stored.addAll(cached);
    final scans = ScanController(
      cache: cache,
      starter: (manual ?? ManualScan()).start,
    );
    addTearDown(controller.dispose);
    addTearDown(scans.dispose);
    // Taille d'un téléphone courant (1080 × 2400 px, ~412 × 915 dp).
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await controller.load();
    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(controller: controller, scans: scans, clock: () => now),
    ));
    await tester.pumpAndSettle();
    return (controller, scans, cache);
  }

  testWidgets('affiche utilisé / total / libre', (tester) async {
    await pumpHome(tester, [internalVolume()]);

    expect(find.text('91,4 Go utilisés'), findsOneWidget);
    expect(find.text('sur 128 Go'), findsOneWidget);
    expect(find.text('36,6 Go libres'), findsOneWidget);
    expect(find.text('71 %'), findsOneWidget);
    expect(find.text('Stockage presque plein'), findsNothing);
    await scrollTo(tester, find.text('Aucune analyse effectuée'));
    expect(find.text('Aucune analyse effectuée'), findsOneWidget);
  });

  testWidgets('alerte quand le stockage est presque plein', (tester) async {
    await pumpHome(tester, [internalVolume(free: 2000000000)]);
    expect(find.text('Stockage presque plein'), findsOneWidget);
  });

  testWidgets('Analyser ouvre le volume et lance l\'analyse', (tester) async {
    final manual = ManualScan();
    await pumpHome(tester, [internalVolume()], manual: manual);

    await scrollTo(tester, find.text('Analyser'));
    await tester.tap(find.text('Analyser'));
    // Barre de progression indéterminée : animation continue, donc
    // on avance le temps au lieu d'attendre la stabilisation.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(VolumeScreen), findsOneWidget);
    expect(manual.request?.rootPath, '/storage/emulated/0');
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(manual.cancelled, isTrue);
    expect(find.text("Lancer l'analyse"), findsOneWidget);
  });

  testWidgets('sans accès aux fichiers, Analyser est désactivé', (tester) async {
    await pumpHome(tester, [internalVolume()], access: FakeFileAccessRepository());
    await scrollTo(tester, find.text('Analyser'));
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Analyser'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('résumé des catégories après une analyse', (tester) async {
    final root = Directory.systemTemp.createTempSync('home_scan_');
    addTearDown(() => root.deleteSync(recursive: true));
    writeBytes(root, 'DCIM/a.jpg', List.filled(3000, 1));
    writeBytes(root, 'Movies/b.mp4', List.filled(5000, 2));

    await pumpHome(
      tester,
      [internalVolume()],
      cached: {'primary': scanOf(root)},
    );

    expect(find.text('Vidéos'), findsOneWidget);
    expect(find.text('Photos et images'), findsOneWidget);
    expect(find.text('Système et applications'), findsOneWidget);
  });

  testWidgets('aucun volume → message explicite', (tester) async {
    await pumpHome(tester, []);
    expect(find.text('Aucun volume lisible'), findsOneWidget);
  });

  testWidgets('erreur → bouton Réessayer', (tester) async {
    final (controller, _, _) = await pumpHome(
      tester,
      [internalVolume()],
      error: const StorageUnavailableException('Lecture impossible'),
    );
    expect(find.text('Lecture impossible'), findsOneWidget);
    expect(controller.state, isA<HomeError>());
  });

  testWidgets('comparaison proposée avec deux supports', (tester) async {
    await pumpHome(tester, [internalVolume(), sdCard()]);
    await scrollTo(tester, find.text('Comparer deux supports'));
    await tester.tap(find.text('Comparer deux supports'));
    await tester.pumpAndSettle();
    expect(find.byType(CompareScreen), findsOneWidget);
    expect(find.text('Capacité'), findsOneWidget);
  });

  testWidgets('pas de comparaison avec un seul support', (tester) async {
    await pumpHome(tester, [internalVolume()]);
    expect(find.text('Comparer deux supports'), findsNothing);
  });

  testWidgets("aucune action destructive dans l'interface", (tester) async {
    await pumpHome(tester, [internalVolume(), sdCard()]);
    for (final word in ['Supprimer', 'Nettoyer', 'Déplacer', 'Partager']) {
      expect(find.textContaining(word), findsNothing);
    }
  });

  testWidgets('accès à la page Confidentialité', (tester) async {
    await pumpHome(tester, [internalVolume()]);
    await tester.tap(find.byTooltip('Confidentialité'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('Lecture seule'), findsOneWidget);
  });

  testWidgets('accès non accordé : explication + bouton', (tester) async {
    final access = FakeFileAccessRepository();
    await pumpHome(tester, [internalVolume()], access: access);

    expect(find.text('Accès aux fichiers requis'), findsOneWidget);
    await scrollTo(tester, find.text('Ouvrir les paramètres'));
    await tester.tap(find.text('Ouvrir les paramètres'));
    await tester.pumpAndSettle();
    expect(access.settingsOpened, 1);
  });

  testWidgets("écran système introuvable : message d'aide", (tester) async {
    await pumpHome(
      tester,
      [internalVolume()],
      access: FakeFileAccessRepository(settingsAvailable: false),
    );
    await scrollTo(tester, find.text('Ouvrir les paramètres'));
    await tester.tap(find.text('Ouvrir les paramètres'));
    await tester.pump();
    expect(find.textContaining('Écran introuvable'), findsOneWidget);
  });
}
