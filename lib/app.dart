import 'package:material_ui/material_ui.dart';

import 'domain/file_access_repository.dart';
import 'domain/scan_metadata_store.dart';
import 'domain/storage_repository.dart';
import 'presentation/home/home_controller.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/theme/app_theme.dart';

class StorageLensApp extends StatefulWidget {
  const StorageLensApp({
    super.key,
    required this.storageRepository,
    required this.metadataStore,
    required this.fileAccessRepository,
  });

  final StorageRepository storageRepository;
  final ScanMetadataStore metadataStore;
  final FileAccessRepository fileAccessRepository;

  @override
  State<StorageLensApp> createState() => _StorageLensAppState();
}

class _StorageLensAppState extends State<StorageLensApp> {
  late final HomeController _homeController = HomeController(
    storage: widget.storageRepository,
    metadata: widget.metadataStore,
    access: widget.fileAccessRepository,
  )..load();

  // Relit l'état (dont l'accès aux fichiers) au retour des Paramètres.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _homeController.load);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _homeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Lens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(controller: _homeController),
    );
  }
}
