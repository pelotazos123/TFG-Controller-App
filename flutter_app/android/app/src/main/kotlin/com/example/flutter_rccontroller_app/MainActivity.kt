package com.example.flutter_rccontroller_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
	private val channelName = "flutter_rccontroller_app/network"
	private val handler = Handler(Looper.getMainLooper())

	private var wifiCallback: ConnectivityManager.NetworkCallback? = null
	private var boundNetwork: Network? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"bindToWifi" -> bindToWifi(result)
					"isWifiBound" -> result.success(isWifiBound())
					"clearBinding" -> {
						clearBinding()
						result.success(true)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun bindToWifi(result: MethodChannel.Result) {
		val connectivityManager =
			getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

		clearBinding()

		val connectedWifi = findConnectedWifiNetwork(connectivityManager)
		if (connectedWifi != null) {
			val bound = bindProcessToNetworkCompat(connectivityManager, connectedWifi)
			if (bound) {
				boundNetwork = connectedWifi
				registerWifiLossCallback(connectivityManager)
				result.success(true)
				return
			}

			result.error(
				"WIFI_BIND_FAILED",
				"Connected Wi-Fi network found but process binding failed",
				null
			)
			return
		}

		val requestBuilder = NetworkRequest.Builder()
			.addTransportType(NetworkCapabilities.TRANSPORT_WIFI)

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			requestBuilder.removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
		}

		val request = requestBuilder.build()

		val completed = AtomicBoolean(false)
		lateinit var callback: ConnectivityManager.NetworkCallback

		val timeoutRunnable = Runnable {
			if (!completed.compareAndSet(false, true)) return@Runnable
			safeUnregister(connectivityManager, callback)
			wifiCallback = null
			result.error("WIFI_BIND_TIMEOUT", "Timed out waiting for a Wi-Fi network", null)
		}

		callback = object : ConnectivityManager.NetworkCallback() {
			override fun onAvailable(network: Network) {
				if (!completed.compareAndSet(false, true)) return
				handler.removeCallbacks(timeoutRunnable)

				val bound = bindProcessToNetworkCompat(connectivityManager, network)
				if (bound) {
					boundNetwork = network
					result.success(true)
				} else {
					safeUnregister(connectivityManager, this)
					wifiCallback = null
					result.error("WIFI_BIND_FAILED", "Wi-Fi network found but process binding failed", null)
				}
			}

			override fun onUnavailable() {
				if (!completed.compareAndSet(false, true)) return
				handler.removeCallbacks(timeoutRunnable)
				safeUnregister(connectivityManager, this)
				wifiCallback = null
				result.error("WIFI_UNAVAILABLE", "No Wi-Fi network available to bind", null)
			}

			override fun onLost(network: Network) {
				if (boundNetwork == network) {
					bindProcessToNetworkCompat(connectivityManager, null)
					boundNetwork = null
				}
			}
		}

		wifiCallback = callback
		try {
			connectivityManager.requestNetwork(request, callback)
			handler.postDelayed(timeoutRunnable, 5000)
		} catch (e: SecurityException) {
			if (completed.compareAndSet(false, true)) {
				safeUnregister(connectivityManager, callback)
				wifiCallback = null
				result.error("WIFI_PERMISSION_DENIED", e.message, null)
			}
		} catch (e: Exception) {
			if (completed.compareAndSet(false, true)) {
				safeUnregister(connectivityManager, callback)
				wifiCallback = null
				result.error("WIFI_BIND_ERROR", e.message, null)
			}
		}
	}

	private fun findConnectedWifiNetwork(connectivityManager: ConnectivityManager): Network? {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			val active = connectivityManager.activeNetwork
			if (active != null) {
				val caps = connectivityManager.getNetworkCapabilities(active)
				if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
					return active
				}
			}
		}

		for (network in connectivityManager.allNetworks) {
			val caps = connectivityManager.getNetworkCapabilities(network) ?: continue
			if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
				return network
			}
		}

		return null
	}

	private fun registerWifiLossCallback(connectivityManager: ConnectivityManager) {
		val request = NetworkRequest.Builder()
			.addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
			.build()

		val callback = object : ConnectivityManager.NetworkCallback() {
			override fun onLost(network: Network) {
				if (boundNetwork == network) {
					bindProcessToNetworkCompat(connectivityManager, null)
					boundNetwork = null
				}
			}
		}

		wifiCallback = callback
		try {
			connectivityManager.registerNetworkCallback(request, callback)
		} catch (_: Exception) {
			// Keep connection active even if callback registration fails.
		}
	}

	private fun isWifiBound(): Boolean {
		return boundNetwork != null
	}

	private fun clearBinding() {
		val connectivityManager =
			getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

		handler.removeCallbacksAndMessages(null)
		bindProcessToNetworkCompat(connectivityManager, null)
		boundNetwork = null

		wifiCallback?.let { callback ->
			safeUnregister(connectivityManager, callback)
		}
		wifiCallback = null
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

	private fun safeUnregister(
		connectivityManager: ConnectivityManager,
		callback: ConnectivityManager.NetworkCallback
	) {
		try {
			connectivityManager.unregisterNetworkCallback(callback)
		} catch (_: Exception) {
			// Ignore stale callback unregistration errors.
		}
	}
}
