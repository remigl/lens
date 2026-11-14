/// Capacité commerciale d'un volume (« 128 Go »), comme l'affichent
/// les Paramètres Android et les fabricants.
///
/// Selon le fabricant, `StorageStatsManager.getTotalBytes` renvoie soit la
/// capacité arrondie en base 1000 (AOSP : 128 000 000 000), soit en base 1024
/// (Samsung : 128 × 2³⁰ = 137,4 Go). `StatFs` renvoie la taille brute, plus
/// petite. Dans tous les cas, on retient la plus petite puissance de deux
/// (en Gio, tolérance 1 %) qui contient le volume, exprimée en milliards
/// d'octets.
library;

const _gib = 1 << 30;
const _tolerance = 1.01;

int marketedCapacityBytes(int rawTotalBytes) {
  if (rawTotalBytes < _gib) return rawTotalBytes;
  final gib = rawTotalBytes / _gib;
  var capacity = 1;
  while (capacity * _tolerance < gib) {
    capacity *= 2;
  }
  return capacity * 1000000000;
}
