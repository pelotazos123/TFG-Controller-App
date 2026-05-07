package com.example.flutter_rccontroller_app

import android.content.Context
import android.net.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetAddress
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "flutter_rccontroller_app/network"
        private const val WIFI_BIND_TIMEOUT_MS = 5000L
    }

    private val handler = Handler(Looper.getMainLooper())

    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var timeoutRunnable: Runnable? = null
    private var boundNetwork: Network? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "bindToWifi" -> bindToWifi(
                    call.argument<String>("targetHost"),
                    result
                )

                "isWifiBound" -> result.success(boundNetwork != null)

                "clearBinding" -> {
                    clearBinding()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun bindToWifi(targetHost: String?, result: MethodChannel.Result) {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val targetAddress = parseTargetAddress(targetHost)

        val existingWifi = findMatchingWifiNetwork(connectivityManager, targetAddress)

        if (existingWifi != null) {
            if (boundNetwork == existingWifi) {
                registerLossCallback(connectivityManager)
                result.success(true)
                return
            }

            clearBinding()

            if (bindProcessToNetworkCompat(connectivityManager, existingWifi)) {
                boundNetwork = existingWifi
                registerLossCallback(connectivityManager)
                result.success(true)
            } else {
                result.error(
                    "WIFI_BIND_FAILED",
                    "Failed to bind to existing Wi-Fi network",
                    null
                )
            }

            return
        }

        clearBinding()

        requestWifiNetwork(connectivityManager, targetAddress, result)
    }

    private fun requestWifiNetwork(
        connectivityManager: ConnectivityManager,
        targetAddress: InetAddress?,
        result: MethodChannel.Result
    ) {
        val completed = AtomicBoolean(false)

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                }
            }
            .build()

        val callback = object : ConnectivityManager.NetworkCallback() {

            override fun onAvailable(network: Network) {
                if (targetAddress != null &&
                    !networkCanReachTarget(connectivityManager, network, targetAddress)
                ) {
                    return
                }

                if (!completed.compareAndSet(false, true)) return

                clearTimeout()

                if (bindProcessToNetworkCompat(connectivityManager, network)) {
                    boundNetwork = network
                    networkCallback = this
                    result.success(true)
                } else {
                    cleanupCallback(connectivityManager, this)
                    result.error(
                        "WIFI_BIND_FAILED",
                        "Wi-Fi found but binding failed",
                        null
                    )
                }
            }

            override fun onUnavailable() {
                if (!completed.compareAndSet(false, true)) return

                clearTimeout()
                cleanupCallback(connectivityManager, this)

                result.error(
                    "WIFI_UNAVAILABLE",
                    "No Wi-Fi network available",
                    null
                )
            }

            override fun onLost(network: Network) {
                if (network == boundNetwork) {
                    bindProcessToNetworkCompat(connectivityManager, null)
                    boundNetwork = null
                    cleanupCallback(connectivityManager, this)
                }
            }
        }

        networkCallback = callback

        timeoutRunnable = Runnable {
            if (!completed.compareAndSet(false, true)) return@Runnable

            cleanupCallback(connectivityManager, callback)

            result.error(
                "WIFI_BIND_TIMEOUT",
                "Timed out waiting for Wi-Fi network",
                null
            )
        }

        try {
            connectivityManager.requestNetwork(request, callback)
            handler.postDelayed(timeoutRunnable!!, WIFI_BIND_TIMEOUT_MS)

        } catch (e: SecurityException) {
            cleanupCallback(connectivityManager, callback)
            result.error("WIFI_PERMISSION_DENIED", e.message, null)

        } catch (e: Exception) {
            cleanupCallback(connectivityManager, callback)
            result.error("WIFI_BIND_ERROR", e.message, null)
        }
    }

    private fun findMatchingWifiNetwork(
        connectivityManager: ConnectivityManager,
        targetAddress: InetAddress?
    ): Network? {
        return connectivityManager.allNetworks.firstOrNull { network ->
            isUsableWifiNetwork(connectivityManager, network) &&
                    (targetAddress == null ||
                            networkCanReachTarget(connectivityManager, network, targetAddress))
        }
    }

    private fun isUsableWifiNetwork(
        connectivityManager: ConnectivityManager,
        network: Network
    ): Boolean {
        val caps = connectivityManager.getNetworkCapabilities(network) ?: return false
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_SUSPENDED)
        ) {
            return false
        }

        val linkProperties =
            connectivityManager.getLinkProperties(network) ?: return false

        return linkProperties.linkAddresses.isNotEmpty()
    }

    private fun networkCanReachTarget(
        connectivityManager: ConnectivityManager,
        network: Network,
        targetAddress: InetAddress
    ): Boolean {
        val linkProperties =
            connectivityManager.getLinkProperties(network) ?: return false

        if (linkProperties.routes.any { it.matches(targetAddress) }) {
            return true
        }

        return linkProperties.linkAddresses.any { linkAddress ->
            val localAddress = linkAddress.address

            localAddress.javaClass == targetAddress.javaClass &&
                    isSameSubnet(
                        localAddress,
                        targetAddress,
                        linkAddress.prefixLength
                    )
        }
    }

    private fun isSameSubnet(
        localAddress: InetAddress,
        targetAddress: InetAddress,
        prefixLength: Int
    ): Boolean {
        val localBytes = localAddress.address
        val targetBytes = targetAddress.address

        if (localBytes.size != targetBytes.size) return false

        val fullBytes = prefixLength / 8
        val remainingBits = prefixLength % 8

        for (i in 0 until fullBytes) {
            if (localBytes[i] != targetBytes[i]) return false
        }

        if (remainingBits == 0) return true

        val mask = (0xFF shl (8 - remainingBits)) and 0xFF

        return (localBytes[fullBytes].toInt() and mask) ==
                (targetBytes[fullBytes].toInt() and mask)
    }

    private fun parseTargetAddress(targetHost: String?): InetAddress? {
        if (targetHost.isNullOrBlank()) return null

        return runCatching {
            InetAddress.getByName(targetHost)
        }.getOrNull()
    }

    private fun clearBinding() {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        clearTimeout()

        bindProcessToNetworkCompat(connectivityManager, null)
        boundNetwork = null

        networkCallback?.let {
            cleanupCallback(connectivityManager, it)
        }

        networkCallback = null
    }

    private fun registerLossCallback(connectivityManager: ConnectivityManager) {
        if (networkCallback != null) return

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onLost(network: Network) {
                if (network == boundNetwork) {
                    clearBinding()
                }
            }
        }

        networkCallback = callback

        try {
            connectivityManager.registerNetworkCallback(request, callback)
        } catch (_: Exception) {
            networkCallback = null
        }
    }

    private fun clearTimeout() {
        timeoutRunnable?.let(handler::removeCallbacks)
        timeoutRunnable = null
    }

    @Suppress("DEPRECATION")
    private fun bindProcessToNetworkCompat(
        connectivityManager: ConnectivityManager,
        network: Network?
    ): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            connectivityManager.bindProcessToNetwork(network)
        } else {
            ConnectivityManager.setProcessDefaultNetwork(network)
        }
    }

    private fun cleanupCallback(
        connectivityManager: ConnectivityManager,
        callback: ConnectivityManager.NetworkCallback
    ) {
        try {
            connectivityManager.unregisterNetworkCallback(callback)
        } catch (_: Exception) {
        }

        if (networkCallback == callback) {
            networkCallback = null
        }
    }
}