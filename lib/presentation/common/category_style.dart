import 'package:material_ui/material_ui.dart';

import '../../domain/scan/file_category.dart';

extension CategoryStyle on FileCategory {
  IconData get icon => switch (this) {
        FileCategory.videos => Icons.movie_outlined,
        FileCategory.images => Icons.photo_outlined,
        FileCategory.audio => Icons.music_note_outlined,
        FileCategory.documents => Icons.description_outlined,
        FileCategory.archives => Icons.folder_zip_outlined,
        FileCategory.apks => Icons.android_outlined,
        FileCategory.other => Icons.insert_drive_file_outlined,
      };
}
