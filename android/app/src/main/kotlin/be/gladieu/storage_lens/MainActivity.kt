package be.gladieu.storage_lens

import be.gladieu.storage_lens.platform.StorageMethodHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var storageHandler: StorageMethodHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        storageHandler = StorageMethodHandler(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        storageHandler?.dispose()
        storageHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
