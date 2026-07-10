package com.aws.aws_os

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.File

/// Shizuku-backed access to other apps' OBB / Android-data (impossible without
/// root/Shizuku on Android 11+). Runs shell commands through Shizuku's
/// adb-privileged process to copy game data into an app-readable staging dir
/// (so the normal transport can stream it) and to restore + silently install on
/// the receiver. All paths are guarded; without Shizuku the caller uses the
/// APK-only path.
class ShizukuChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.aws.aws_os/shizuku"
        const val REQ_CODE = 4479
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(pingSafe())
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> {
                requestPermission()
                result.success(null)
            }
            "dirInfo" -> result.success(dirInfo(call.argument<String>("path") ?: ""))
            "stage" -> result.success(
                stage(
                    call.argument<String>("package") ?: "",
                    call.argument<Boolean>("obb") ?: false,
                    call.argument<Boolean>("data") ?: false,
                    call.argument<String>("stagingDir") ?: ""
                )
            )
            "restore" -> {
                @Suppress("UNCHECKED_CAST")
                val files = call.argument<List<Map<String, String>>>("files") ?: emptyList()
                result.success(restore(files))
            }
            "installApks" -> result.success(
                installApks(call.argument<List<String>>("paths") ?: emptyList())
            )
            else -> result.notImplemented()
        }
    }

    private fun pingSafe(): Boolean = try { Shizuku.pingBinder() } catch (e: Throwable) { false }

    private fun hasPermission(): Boolean = try {
        Shizuku.pingBinder() &&
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    } catch (e: Throwable) { false }

    private fun requestPermission() {
        try {
            if (Shizuku.pingBinder() &&
                Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED
            ) {
                Shizuku.requestPermission(REQ_CODE)
            }
        } catch (e: Throwable) {}
    }

    /// Run a shell command via Shizuku; returns (exitCode, stdout).
    ///
    /// `Shizuku.newProcess` is a hidden (@RestrictTo) API, so it and the
    /// returned ShizukuRemoteProcess are accessed reflectively — the approach
    /// used by file managers. This compiles regardless of the api version.
    private fun sh(cmd: String): Pair<Int, String> {
        return try {
            val newProcess = Shizuku::class.java.getMethod(
                "newProcess",
                Array<String>::class.java,
                Array<String>::class.java,
                String::class.java
            )
            newProcess.isAccessible = true
            val process = newProcess.invoke(
                null,
                arrayOf("sh", "-c", cmd),
                null,
                null
            ) ?: return Pair(-1, "no process")
            val cls = process.javaClass
            val stream = cls.getMethod("getInputStream")
                .invoke(process) as java.io.InputStream
            val out = stream.bufferedReader().readText()
            val exit = cls.getMethod("waitFor").invoke(process) as Int
            Pair(exit, out)
        } catch (e: Throwable) {
            Pair(-1, e.message ?: "")
        }
    }

    private fun dirInfo(path: String): Map<String, Any?> {
        if (path.isEmpty() || !hasPermission()) return mapOf("exists" to false, "size" to 0L)
        val (_, out) = sh("du -sb \"$path\" 2>/dev/null | cut -f1")
        val size = out.trim().lines().firstOrNull()?.toLongOrNull() ?: 0L
        return mapOf("exists" to (size > 0), "size" to size)
    }

    /// Copy a package's obb/data into [stagingDir]; return [{path, relPath}].
    private fun stage(
        pkg: String,
        includeObb: Boolean,
        includeData: Boolean,
        stagingDir: String
    ): List<Map<String, String>> {
        if (pkg.isEmpty() || stagingDir.isEmpty() || !hasPermission()) return emptyList()
        val out = ArrayList<Map<String, String>>()
        val roots = ArrayList<Pair<String, String>>()
        if (includeObb) roots.add(Pair("/sdcard/Android/obb/$pkg", "obb/$pkg"))
        if (includeData) roots.add(Pair("/sdcard/Android/data/$pkg", "data/$pkg"))
        for ((src, relRoot) in roots) {
            val destRoot = "$stagingDir/$relRoot"
            sh("mkdir -p \"$destRoot\" && cp -a \"$src/.\" \"$destRoot/\" 2>/dev/null")
            val (_, listing) = sh("cd \"$destRoot\" && find . -type f 2>/dev/null")
            for (line in listing.lines()) {
                val rel = line.trim().removePrefix("./")
                if (rel.isEmpty()) continue
                out.add(mapOf("path" to "$destRoot/$rel", "relPath" to "$relRoot/$rel"))
            }
        }
        return out
    }

    /// Copy received files (relPath under obb/…|data/…) back to /sdcard/Android.
    private fun restore(files: List<Map<String, String>>): Boolean {
        if (files.isEmpty() || !hasPermission()) return false
        var ok = true
        for (f in files) {
            val src = f["path"] ?: continue
            val rel = f["relPath"] ?: continue
            val dest = "/sdcard/Android/$rel"
            val destDir = dest.substringBeforeLast('/')
            val (exit, _) = sh("mkdir -p \"$destDir\" && cp -a \"$src\" \"$dest\"")
            if (exit != 0) ok = false
        }
        return ok
    }

    /// Silent split-aware install via `pm` (requires Shizuku).
    private fun installApks(paths: List<String>): Boolean {
        if (paths.isEmpty() || !hasPermission()) return false
        val total = paths.sumOf { File(it).length() }
        val (_, createOut) = sh("pm install-create -S $total")
        val sid = Regex("\\[(\\d+)]").find(createOut)?.groupValues?.get(1)
            ?: Regex("(\\d+)").find(createOut)?.groupValues?.get(1)
            ?: return false
        for (p in paths) {
            val file = File(p)
            sh("pm install-write -S ${file.length()} $sid \"${file.name}\" \"$p\"")
        }
        val (commit, _) = sh("pm install-commit $sid")
        return commit == 0
    }
}
