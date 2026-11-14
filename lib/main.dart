import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/platform_file_access_repository.dart';
import 'data/platform_storage_repository.dart';
import 'data/scan/scan_cache.dart';
import 'platform/storage_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final channel = StorageChannel();
  runApp(
    StorageLensApp(
      storageRepository: PlatformStorageRepository(channel),
      fileAccessRepository: PlatformFileAccessRepository(channel),
      scanCache: ScanCache(
        () async => Directory(await channel.getPrivateFilesDir()),
      ),
    ),
  );
}
