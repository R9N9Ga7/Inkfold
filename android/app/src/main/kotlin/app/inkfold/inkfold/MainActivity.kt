package app.inkfold.inkfold

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSLATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "translate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (text.isEmpty()) {
                    result.error("EMPTY_TEXT", "No text was selected.", null)
                    return@setMethodCallHandler
                }
                result.success(openGoogleTranslate(text))
            }
    }

    private fun openGoogleTranslate(text: String): Boolean {
        val intent = Intent(Intent.ACTION_PROCESS_TEXT).apply {
            type = "text/plain"
            setPackage(GOOGLE_TRANSLATE_PACKAGE)
            putExtra(Intent.EXTRA_PROCESS_TEXT, text)
            putExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true)
        }
        if (intent.resolveActivity(packageManager) == null) return false
        startActivity(intent)
        return true
    }

    companion object {
        private const val TRANSLATION_CHANNEL = "app.inkfold/translation"
        private const val GOOGLE_TRANSLATE_PACKAGE = "com.google.android.apps.translate"
    }
}
