package be.gladieu.storage_lens.platform

import android.app.usage.StorageStatsManager
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import java.io.IOException
import java.util.UUID

data class VolumeStats(
    val id: String,
    val label: String,
    val isPrimary: Boolean,
    val isRemovable: Boolean,
    val totalBytes: Long,
    val freeBytes: Long,
    val source: String,
) {
    fun toChannelMap(): Map<String, Any> = mapOf(
        "id" to id,
        "label" to label,
        "primary" to isPrimary,
        "removable" to isRemovable,
        "totalBytes" to totalBytes,
        "freeBytes" to freeBytes,
        "source" to source,
    )
}

/**
 * Lit l'espace total/libre de chaque volume monté.
 *
 * - Volume principal : StorageStatsManager (mêmes chiffres que Paramètres,
 *   aucune permission requise pour getTotalBytes/getFreeBytes).
 * - Autres volumes : StorageStatsManager si le volume a un UUID de stockage
 *   (API 31+), sinon StatFs sur le point de montage.
 *
 * Un volume illisible est ignoré, jamais propagé en crash.
 */
class VolumeStatsReader(private val context: Context) {

    private val storageManager = context.getSystemService(StorageManager::class.java)
    private val statsManager = context.getSystemService(StorageStatsManager::class.java)

    fun readVolumes(): List<VolumeStats> =
        storageManager.storageVolumes
            .filter { it.isMountedReadable() }
            .mapNotNull { readSafely(it) }

    private fun StorageVolume.isMountedReadable(): Boolean =
        state == Environment.MEDIA_MOUNTED || state == Environment.MEDIA_MOUNTED_READ_ONLY

    private fun readSafely(volume: StorageVolume): VolumeStats? = try {
        read(volume)
    } catch (e: IOException) {
        null // Volume retiré entre l'énumération et la lecture.
    } catch (e: SecurityException) {
        null
    } catch (e: IllegalArgumentException) {
        null // Point de montage invalide pour StatFs.
    }

    private fun read(volume: StorageVolume): VolumeStats? {
        val statsUuid = statsUuidOf(volume)
        val total: Long
        val free: Long
        val source: String
        if (statsUuid != null) {
            total = statsManager.getTotalBytes(statsUuid)
            free = statsManager.getFreeBytes(statsUuid)
            source = SOURCE_STORAGE_STATS
        } else {
            val directory = volume.directory ?: return null
            val statFs = StatFs(directory.path)
            total = statFs.totalBytes
            free = statFs.availableBytes
            source = SOURCE_STATFS
        }
        if (total <= 0L) return null

        return VolumeStats(
            id = volume.uuid ?: PRIMARY_ID,
            label = volume.getDescription(context),
            isPrimary = volume.isPrimary,
            isRemovable = volume.isRemovable,
            totalBytes = total,
            freeBytes = free.coerceIn(0L, total),
            source = source,
        )
    }

    private fun statsUuidOf(volume: StorageVolume): UUID? = when {
        volume.isPrimary -> StorageManager.UUID_DEFAULT
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> volume.storageUuid
        else -> null
    }

    private companion object {
        const val PRIMARY_ID = "primary"
        const val SOURCE_STORAGE_STATS = "storageStats"
        const val SOURCE_STATFS = "statFs"
    }
}
