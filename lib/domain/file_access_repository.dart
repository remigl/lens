/// Accès aux fichiers du stockage partagé.
///
/// Contrat : ne lève jamais d'exception. En cas de doute, l'accès est
/// considéré comme non accordé.
abstract interface class FileAccessRepository {
  Future<bool> hasAllFilesAccess();

  /// Ouvre l'écran système où l'utilisateur décide. Renvoie `false`
  /// si cet écran n'existe pas sur l'appareil.
  Future<bool> openAllFilesAccessSettings();
}
