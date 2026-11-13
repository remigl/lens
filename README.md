# Storage Lens

Application Android (Flutter) **en lecture seule** qui répond à une question : *pourquoi mon téléphone est-il presque plein ?*
Aucune suppression, aucun réseau, aucun compte, aucune collecte.

## Architecture

```
lib/
  core/format/      formatage tailles (base 1000, « 91,4 Go ») et dates
  domain/           modèles + interfaces (StorageVolumeInfo, StorageRepository, ScanMetadataStore)
  data/             implémentations (canal plateforme, fichier JSON privé)
  platform/         pont MethodChannel Dart ↔ Kotlin
  presentation/     écrans, ChangeNotifier, thème Material 3
android/app/src/main/kotlin/.../platform/
  StorageMethodHandler.kt   canal + exécution hors thread UI
  VolumeStatsReader.kt      StorageStatsManager / StatFs
```

État : `ChangeNotifier` + `ListenableBuilder` (Flutter SDK, pas de package).
Seule dépendance : `material_ui` (Material 3 officiel, sorti du SDK depuis Flutter 3.47).

## Prérequis

- Flutter stable ≥ 3.47 (Dart ≥ 3.13), JDK 17+, Android SDK 36
- Appareil ou émulateur Android 11+ (API 30)

## Installation

Le dépôt ne contient que les fichiers propres au projet. Générez une seule fois
les fichiers standard (wrapper Gradle, ressources, icônes) — `flutter create`
**ne remplace pas** les fichiers existants :

```bash
cd storage_lens
flutter create --org be.gladieu --project-name storage_lens --platforms android .
flutter pub get
```

## Lancement / build

```bash
flutter run                      # debug
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

La build release est signée avec la clé debug : configurez votre propre keystore avant distribution.

## Tests

```bash
flutter analyze
flutter test
# Vérifier qu'aucune permission n'est déclarée dans l'APK release :
$ANDROID_HOME/build-tools/36.0.0/aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
```

## Permissions

| Permission | Pourquoi |
|---|---|
| `MANAGE_EXTERNAL_STORAGE` (« Accès à tous les fichiers ») | mesurer documents, téléchargements, archives, APK. Accordée **manuellement** par l'utilisateur dans les Paramètres ; utilisée en **lecture seule** (aucun code d'écriture/suppression). |
| aucune pour total/libre | `StorageStatsManager.getTotalBytes/getFreeBytes` |

`INTERNET` est absent du manifeste et retiré explicitement de la build release (vérifié en CI).
Sauvegarde cloud et transfert d'appareil désactivés pour les données de l'app.

> Google Play examine les apps qui demandent l'accès à tous les fichiers. Cette variante vise le sideload ; une variante « médias uniquement » sera ajoutée pour le Play Store si nécessaire.

## APK de test

Chaque push sur `main` déclenche `.github/workflows/android.yml` : analyse, tests, build, vérification des permissions, puis publication de l'APK dans la release **`dev`** (Releases → « Build de développement » → `storage-lens.apk`).

L'APK est signé avec une clé debug générée par la CI : si une mise à jour refuse de s'installer, désinstallez la version précédente.

## Limitations Android

- Même avec « Accès à tous les fichiers », `Android/data` et `Android/obb` des autres apps restent inaccessibles.
- Le sélecteur de dossiers (SAF) refuse la racine du stockage et `Download/` depuis Android 11.
- La taille des applications par app exige l'accès aux statistiques d'utilisation : non demandé.

L'application affiche ces limites au lieu de les contourner.

## Confidentialité

Aucune donnée envoyée ni collectée, aucun compte, analyse 100 % locale, lecture seule. Voir l'écran « Confidentialité » de l'app.
