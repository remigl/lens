import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_lens/domain/storage_repository.dart';
import 'package:storage_lens/presentation/home/home_controller.dart';
import 'package:storage_lens/presentation/home/home_screen.dart';
import 'package:storage_lens/presentation/privacy/privacy_screen.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 11, 13, 18, 0);

  Future<HomeController> pumpHome(
    WidgetTester tester,
    FakeStorageRepository repo, {
    FakeScanMetadataStore? meta,
    FakeFileAccessRepository? access,
  }) async {
    final controller = HomeController(
      storage: repo,
      metadata: meta ?? FakeScanMetadataStore(),
      access: access ?? FakeFileAccessRepository(),
      clock: () => now,
    );
    addTearDown(controller.dispose);
    // Taille d'un téléphone courant (1080 × 2400 px, ~412 × 915 dp).
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(controller: controller, clock: () => now)),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('affiche utilisé / total / libre', (tester) async {
    await pumpHome(tester, FakeStorageRepository([internalVolume()]));

    expect(find.text('91,4 Go utilisés'), findsOneWidget);
    expect(find.text('sur 128 Go'), findsOneWidget);
    expect(find.text('36,6 Go libres'), findsOneWidget);
    expect(find.text('71 %'), findsOneWidget);
    expect(find.text('Aucune analyse effectuée'), findsOneWidget);
    expect(find.text('Stockage presque plein'), findsNothing);
  });

  testWidgets('alerte quand le stockage est presque plein', (tester) async {
    await pumpHome(
      tester,
      FakeStorageRepository([internalVolume(free: 2000000000)]),
    );
    expect(find.text('Stockage presque plein'), findsOneWidget);
  });

  testWidgets('Analyser enregistre et affiche la date', (tester) async {
    await pumpHome(tester, FakeStorageRepository([internalVolume()]));

    await tester.ensureVisible(find.text('Analyser'));
    await tester.tap(find.text('Analyser'));
    await tester.pumpAndSettle();

    expect(find.text("Dernière analyse : Aujourd'hui à 18:00"), findsOneWidget);
  });

  testWidgets('aucun volume → message explicite', (tester) async {
    await pumpHome(tester, FakeStorageRepository([]));
    expect(find.text('Aucun volume lisible'), findsOneWidget);
  });

  testWidgets('erreur → bouton Réessayer', (tester) async {
    final repo = FakeStorageRepository([internalVolume()])
      ..error = const StorageUnavailableException('Lecture impossible');
    await pumpHome(tester, repo);

    expect(find.text('Lecture impossible'), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('36,6 Go libres'), findsOneWidget);
  });

  testWidgets('aucune action destructive dans l\'interface', (tester) async {
    await pumpHome(tester, FakeStorageRepository([internalVolume()]));
    for (final word in ['Supprimer', 'Nettoyer', 'Déplacer', 'Partager']) {
      expect(find.textContaining(word), findsNothing);
    }
  });

  testWidgets('accès à la page Confidentialité', (tester) async {
    await pumpHome(tester, FakeStorageRepository([internalVolume()]));
    await tester.tap(find.byTooltip('Confidentialité'));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(find.text('Lecture seule'), findsOneWidget);
  });

  testWidgets("accès non accordé : explication + bouton", (tester) async {
    final access = FakeFileAccessRepository();
    await pumpHome(tester, FakeStorageRepository([internalVolume()]),
        access: access);

    expect(find.text('Accès aux fichiers requis'), findsOneWidget);
    await tester.ensureVisible(find.text('Ouvrir les paramètres'));
    await tester.tap(find.text('Ouvrir les paramètres'));
    await tester.pumpAndSettle();
    expect(access.settingsOpened, 1);
  });

  testWidgets("écran système introuvable : message d'aide", (tester) async {
    await pumpHome(
      tester,
      FakeStorageRepository([internalVolume()]),
      access: FakeFileAccessRepository(settingsAvailable: false),
    );
    await tester.ensureVisible(find.text('Ouvrir les paramètres'));
    await tester.tap(find.text('Ouvrir les paramètres'));
    await tester.pump();
    expect(find.textContaining('Écran introuvable'), findsOneWidget);
  });

  testWidgets('accès accordé : confirmation', (tester) async {
    await pumpHome(
      tester,
      FakeStorageRepository([internalVolume()]),
      access: FakeFileAccessRepository(granted: true),
    );
    expect(find.text('Accès aux fichiers accordé'), findsOneWidget);
    expect(find.text('Ouvrir les paramètres'), findsNothing);
  });
}
