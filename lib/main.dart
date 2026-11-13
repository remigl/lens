import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/file_scan_metadata_store.dart';
import 'data/platform_file_access_repository.dart';
import 'data/platform_storage_repository.dart';
import 'platform/storage_channel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final channel = StorageChannel();
  runApp(
    StorageLensApp(
      storageRepository: PlatformStorageRepository(channel),
      metadataStore: FileScanMetadataStore.fromChannel(channel),
      fileAccessRepository: PlatformFileAccessRepository(channel),
    ),
  );
}
