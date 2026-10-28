package com.octaviokonzen.lifelink

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Pôr um atalho (ex.: o contador de vida) direto na tela inicial. O
        // atalho é o mesmo do "segurar o ícone" (quick_actions): abrir pelo
        // ícone novo cai no mesmo lugar do app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lifelink/shortcuts").setMethodCallHandler { call, result ->
            if (call.method != "pin") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val id = call.argument<String>("id") ?: "counter"
            val label = call.argument<String>("label") ?: "Contador de vida"
            val icon = call.argument<String>("icon") ?: "ic_shortcut_counter"
            result.success(pin(id, label, icon))
        }
    }

    private fun pin(id: String, label: String, icon: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false
        return try {
            val info = if (manager.dynamicShortcuts.any { it.id == id }) {
                ShortcutInfo.Builder(this, id).build()
            } else {
                val res = resources.getIdentifier(icon, "drawable", packageName)
                val intent = packageManager.getLaunchIntentForPackage(packageName)!!
                    .setAction(Intent.ACTION_RUN)
                    .putExtra("some unique action key", id) // a chave do quick_actions
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                ShortcutInfo.Builder(this, id)
                    .setShortLabel(label)
                    .setIcon(if (res != 0) Icon.createWithResource(this, res) else Icon.createWithResource(this, R.mipmap.ic_launcher))
                    .setIntent(intent)
                    .build()
            }
            manager.requestPinShortcut(info, null)
        } catch (e: Exception) {
            false
        }
    }
}
