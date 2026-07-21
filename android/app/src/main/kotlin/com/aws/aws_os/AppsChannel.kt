package com.aws.aws_os

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/// Installed-app info + APK gathering + install. Works on every device with no
/// Shizuku/root — APKs at publicSourceDir are world-readable, and install goes
/// through the system PackageInstaller (shows the confirm UI).
class AppsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.aws.aws_os/apps"
        const val INSTALL_ACTION = "com.aws.aws_os.INSTALL_COMPLETE"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listApps" -> {
                val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                result.success(listApps(includeSystem))
            }
            "getApkPaths" -> {
                val pkg = call.argument<String>("package")
                if (pkg == null) {
                    result.error("ARG", "package required", null)
                } else {
                    try {
                        result.success(getApkPaths(pkg))
                    } catch (e: Exception) {
                        result.error("PM", e.message, null)
                    }
                }
            }
            "installApks" -> {
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                installApks(paths, result)
            }
            "getAppIcon" -> {
                val pkg = call.argument<String>("package")
                val size = call.argument<Int>("size") ?: 128
                if (pkg == null) {
                    result.error("ARG", "package required", null)
                } else {
                    result.success(getAppIcon(pkg, size))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun listApps(includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val out = ArrayList<Map<String, Any?>>()
        for (ai in apps) {
            if (ai.packageName == context.packageName) continue
            val system = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (system && !includeSystem) continue
            val label = try { pm.getApplicationLabel(ai).toString() } catch (e: Exception) { ai.packageName }
            val apkSize = try {
                var total = File(ai.sourceDir).length()
                ai.splitSourceDirs?.forEach { total += File(it).length() }
                total
            } catch (e: Exception) { 0L }
            var versionName: String? = null
            try {
                versionName = pm.getPackageInfo(ai.packageName, 0).versionName
            } catch (e: Exception) {}
            out.add(
                mapOf(
                    "package" to ai.packageName,
                    "label" to label,
                    "system" to system,
                    "apkSize" to apkSize,
                    "versionName" to versionName,
                    "hasSplits" to (ai.splitSourceDirs?.isNotEmpty() == true)
                )
            )
        }
        out.sortWith(compareBy { (it["label"] as String).lowercase() })
        return out
    }

    /// base.apk first, then any split APKs — all world-readable file paths.
    private fun getApkPaths(pkg: String): List<String> {
        val ai = context.packageManager.getApplicationInfo(pkg, 0)
        val paths = ArrayList<String>()
        paths.add(ai.sourceDir)
        ai.splitSourceDirs?.let { paths.addAll(it) }
        return paths
    }

    /// The app's launcher icon rendered to a square PNG (adaptive icons included).
    /// Returns null if the icon can't be resolved.
    private fun getAppIcon(pkg: String, size: Int): ByteArray? {
        return try {
            val drawable = context.packageManager.getApplicationIcon(pkg)
            val bitmap = drawableToBitmap(drawable, size.coerceIn(24, 512))
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable, size: Int): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun installApks(paths: List<String>, result: MethodChannel.Result) {
        if (paths.isEmpty()) {
            result.error("ARG", "no apks", null)
            return
        }
        try {
            val installer = context.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
            )
            val sessionId = installer.createSession(params)
            val session = installer.openSession(sessionId)
            for (path in paths) {
                val file = File(path)
                if (!file.exists()) continue
                session.openWrite(file.name, 0, file.length()).use { out ->
                    file.inputStream().use { input -> input.copyTo(out) }
                    session.fsync(out)
                }
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            val pi = PendingIntent.getBroadcast(
                context,
                sessionId,
                Intent(INSTALL_ACTION).setPackage(context.packageName),
                flags
            )
            session.commit(pi.intentSender)
            session.close()
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL", e.message, null)
        }
    }
}
