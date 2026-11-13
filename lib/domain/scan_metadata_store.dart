/// Persistance locale des métadonnées de scan (privée à l'application).
///
/// Contrat : ne lève jamais d'exception. Une lecture impossible renvoie
/// `null`, une écriture impossible renvoie `false`.
abstract interface class ScanMetadataStore {
  Future<DateTime?> readLastScan();

  Future<bool> writeLastScan(DateTime scannedAt);
}
