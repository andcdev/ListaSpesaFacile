package it.listaspesafacile.lista_spesa_facile

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Notifica toccata e non ancora aperta dall'app ("chat:12", "list:12").
    /// Vale anche per le notifiche mostrate dal servizio in background, ad app chiusa o dietro altre app.
    private var pendingPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Ricreata dal sistema (es. dopo una rotazione): la notifica era già stata aperta.
        if (savedInstanceState == null) capture(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        capture(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "listaspesafacile/notification_tap")
            .setMethodCallHandler { call, result ->
                if (call.method == "take") {
                    result.success(pendingPayload)
                    pendingPayload = null
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun capture(intent: Intent?) {
        if (intent == null || intent.action != "SELECT_NOTIFICATION") return
        // Riaperta dalle app recenti: stesso intent di prima, la notifica è già stata aperta.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        pendingPayload = intent.getStringExtra("payload") ?: return
    }
}
