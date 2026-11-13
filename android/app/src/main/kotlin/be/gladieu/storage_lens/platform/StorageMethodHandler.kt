package be.gladieu.storage_lens.platform

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Point d'entrée du canal Flutter. Les appels système potentiellement lents
 * (IPC vers StorageStatsManager) sont exécutés hors du thread UI.
 *
 * Aucun chemin ni message d'exception brut n'est renvoyé à Dart.
 */
class StorageMethodHandler(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val volumeReader = VolumeStatsReader(context)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVolumes" -> runInBackground(result) {
                volumeReader.readVolumes().map { it.toChannelMap() }
            }
            "getPrivateFilesDir" -> result.success(context.filesDir.absolutePath)
            "hasAllFilesAccess" -> result.success(Environment.isExternalStorageManager())
            "openAllFilesAccessSettings" -> result.success(openAllFilesAccessSettings())
            else -> result.notImplemented()
        }
    }

    private fun runInBackground(result: MethodChannel.Result, task: () -> Any?) {
        try {
            executor.execute {
                val outcome = try {
                    Result.success(task())
                } catch (e: Exception) {
                    Result.failure(e)
                }
                mainHandler.post {
                    outcome.fold(
                        onSuccess = { result.success(it) },
                        onFailure = { result.error(ERROR_CODE, it.javaClass.simpleName, null) },
                    )
                }
            }
        } catch (e: RejectedExecutionException) {
            result.error(ERROR_CODE, "disposed", null)
        }
    }

    /**
     * Ouvre l'écran système où l'utilisateur accorde lui-même l'accès.
     * L'application ne peut pas s'accorder cette permission.
     */
    private fun openAllFilesAccessSettings(): Boolean {
        val candidates = listOf(
            Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.fromParts("package", context.packageName, null),
            ),
            Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
        )
        for (intent in candidates) {
            try {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                // Certains constructeurs suppriment l'écran par application.
            }
        }
        return false
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }

    private companion object {
        const val CHANNEL_NAME = "storage_lens/storage"
        const val ERROR_CODE = "storage_error"
    }
}
