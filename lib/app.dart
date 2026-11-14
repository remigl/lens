import 'package:material_ui/material_ui.dart';

import 'data/scan/scan_cache.dart';
import 'domain/file_access_repository.dart';
import 'domain/storage_repository.dart';
import 'presentation/home/home_controller.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/scan/scan_controller.dart';
import 'presentation/theme/app_theme.dart';

class StorageLensApp extends StatefulWidget {
  const StorageLensApp({
    super.key,
    required this.storageRepository,
    required this.fileAccessRepository,
    required this.scanCache,
  });

  final StorageRepository storageRepository;
  final FileAccessRepository fileAccessRepository;
  final ScanCache scanCache;

  @override
  State<StorageLensApp> createState() => _StorageLensAppState();
}

class _StorageLensAppState extends State<StorageLensApp> {
  late final HomeController _homeController = HomeController(
    storage: widget.storageRepository,
    access: widget.fileAccessRepository,
  )..load();

  late final ScanController _scanController = ScanController(
    cache: widget.scanCache,
  );

  // Relit les volumes (carte SD/clé USB branchée ou retirée) et l'accès
  // aux fichiers au retour dans l'application.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _homeController.load);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scanController.dispose();
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
      home: HomeScreen(
        controller: _homeController,
        scans: _scanController,
      ),
    );
  }
}
