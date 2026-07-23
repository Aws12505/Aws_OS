package com.aws.aws_os

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Local sharing: joins the sender's phone to the receiver's Wi-Fi Direct group
 * or guided hotspot by SSID+password, using WifiNetworkSpecifier so the app can
 * request a specific network without touching global Wi-Fi state or sending
 * the user to system Settings. Android 10+ (API 29) only — callers fall back
 * to the manual "join in Wi-Fi settings" flow when [connect] returns false.
 */
class WifiConnectChannel(context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.aws.aws_os/wifi_connect"
        private const val TIMEOUT_MS = 20000L
    }

    private val connectivityManager =
        context.applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val ssid = call.argument<String>("ssid")
                if (ssid.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                connect(ssid, call.argument<String>("password"), result)
            }
            "disconnect" -> {
                disconnect()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun connect(ssid: String, password: String?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // No app-scoped network API before Android 10 — let the caller fall
            // back to the manual join flow instead.
            result.success(false)
            return
        }
        disconnect()

        val specifierBuilder = WifiNetworkSpecifier.Builder().setSsid(ssid)
        if (!password.isNullOrEmpty()) {
            specifierBuilder.setWpa2Passphrase(password)
        }

        val request =
            NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                // These groups/hotspots have no upstream internet — the default
                // request otherwise requires NET_CAPABILITY_INTERNET and never matches.
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifierBuilder.build())
                .build()

        var finished = false
        val cb =
            object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (finished) return
                    finished = true
                    timeoutHandler.removeCallbacksAndMessages(null)
                    try {
                        connectivityManager.bindProcessToNetwork(network)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                override fun onUnavailable() {
                    if (finished) return
                    finished = true
                    timeoutHandler.removeCallbacksAndMessages(null)
                    result.success(false)
                }

                override fun onLost(network: Network) {
                    if (connectivityManager.boundNetworkForProcess == network) {
                        try {
                            connectivityManager.bindProcessToNetwork(null)
                        } catch (e: Exception) {}
                    }
                }
            }
        callback = cb
        connectivityManager.requestNetwork(request, cb)
        timeoutHandler.postDelayed({
            if (!finished) {
                finished = true
                try {
                    connectivityManager.unregisterNetworkCallback(cb)
                } catch (e: Exception) {}
                result.success(false)
            }
        }, TIMEOUT_MS)
    }

    private fun disconnect() {
        try {
            connectivityManager.bindProcessToNetwork(null)
        } catch (e: Exception) {}
        callback?.let {
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {}
        }
        callback = null
    }
}
