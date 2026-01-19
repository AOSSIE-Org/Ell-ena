package org.aossie.ell_ena

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_shortcuts"
    private var pendingRoute: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        setIntent(intent) // Important: update the current intent
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Setup method call handler
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    result.success(pendingRoute)
                    pendingRoute = null // Clear after sending
                }
                else -> result.notImplemented()
            }
        }
        
        // Try to send initial route immediately if Flutter is ready
        sendRouteToFlutter()
    }

    private fun handleIntent(intent: Intent?) {
        // Method 1: Try to get route from deep link (app://shortcut/chat)
        val uri: Uri? = intent?.data
        
        if (uri != null && uri.scheme == "app" && uri.host == "shortcut") {
            val route = uri.path?.removePrefix("/") // Remove leading "/"
            pendingRoute = route
            return
        }
        
        // Method 2: Try to get screen index from extras (fallback)
        val screenIndex = intent?.getIntExtra("screen", -1)
        if (screenIndex != -1) {
            pendingRoute = when (screenIndex) {
                0 -> "dashboard"
                1 -> "calendar"
                2 -> "workspace"
                3 -> "chat"
                4 -> "profile"
                else -> null
            }
        }
    }

    private fun sendRouteToFlutter() {
        if (pendingRoute != null && methodChannel != null) {
            try {
                methodChannel?.invokeMethod("navigate", pendingRoute)
                pendingRoute = null
            } catch (e: Exception) {
                // Flutter might not be ready yet, route will be sent when getInitialRoute is called
            }
        }
    }
}