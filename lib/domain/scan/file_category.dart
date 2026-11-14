/// Catégories de fichiers, déterminées uniquement par l'extension
/// (le contenu des fichiers n'est jamais ouvert pour les classer).
enum FileCategory {
  videos('Vidéos'),
  images('Photos et images'),
  audio('Audio'),
  documents('Documents'),
  archives('Archives'),
  apks('APK'),
  other('Autres fichiers');

  const FileCategory(this.label);

  final String label;

  static FileCategory of(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return FileCategory.other;
    return _byExtension[fileName.substring(dot + 1).toLowerCase()] ??
        FileCategory.other;
  }

  static final Map<String, FileCategory> _byExtension = {
    for (final e in const [
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'avif', 'bmp', //
      'dng', 'raw', 'cr2', 'cr3', 'nef', 'arw', 'orf', 'rw2', 'tif', 'tiff',
      'svg', 'ico',
    ])
      e: FileCategory.images,
    for (final e in const [
      'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', '3g2', 'm4v', 'ts', 'mts', //
      'm2ts', 'wmv', 'flv', 'mpg', 'mpeg',
    ])
      e: FileCategory.videos,
    for (final e in const [
      'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'oga', 'opus', 'amr', //
      'wma', 'mid', 'midi', 'aiff', 'aif',
    ])
      e: FileCategory.audio,
    for (final e in const [
      'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'md', 'xls', 'xlsx', 'ods', //
      'csv', 'ppt', 'pptx', 'odp', 'epub', 'mobi', 'azw3', 'gpx', 'kml',
    ])
      e: FileCategory.documents,
    for (final e in const [
      'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'xz', 'zst', 'lz4', //
    ])
      e: FileCategory.archives,
    for (final e in const ['apk', 'apks', 'xapk', 'apkm', 'aab'])
      e: FileCategory.apks,
  };
}
