package com.doorstepp.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    companion object {
        private const val CHANNEL = "com.doorstepp.app/google_config"
        private const val UPI_CHANNEL = "com.doorstepp.app/upi_native"
        private const val UPI_PAYMENT_REQUEST_CODE = 9988
    }

    private var pendingUpiResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, dataIntent: Intent?) {
        super.onActivityResult(requestCode, resultCode, dataIntent)

        if (requestCode == UPI_PAYMENT_REQUEST_CODE) {
            val callback = pendingUpiResult
            pendingUpiResult = null

            if (callback == null) return

            val rawResponse = dataIntent?.getStringExtra("response") ?: ""
            val extras = dataIntent?.extras
            val responseStr = if (rawResponse.isNotEmpty()) {
                rawResponse
            } else if (extras != null) {
                val sb = StringBuilder()
                for (key in extras.keySet()) {
                    if (sb.isNotEmpty()) sb.append("&")
                    sb.append(key).append("=").append(extras.get(key)?.toString() ?: "")
                }
                sb.toString()
            } else {
                ""
            }

            val resultMap = mutableMapOf<String, Any?>()
            resultMap["rawResponse"] = responseStr

            if (responseStr.isNotEmpty()) {
                val pairs = responseStr.split("&")
                for (pair in pairs) {
                    val parts = pair.split("=")
                    if (parts.size >= 2) {
                        val k = parts[0].trim()
                        val v = parts.subList(1, parts.size).joinToString("=").trim()
                        resultMap[k] = v
                    }
                }
            }

            val status = (resultMap["Status"] ?: resultMap["status"] ?: resultMap["STATUS"] ?: "").toString().uppercase()
            val approvalRefNo = (resultMap["ApprovalRefNo"] ?: resultMap["approvalRefNo"] ?: resultMap["txnRef"] ?: resultMap["approval_ref_no"] ?: "").toString()
            val txnId = (resultMap["txnId"] ?: resultMap["TxnId"] ?: resultMap["TXNID"] ?: "").toString()

            resultMap["approvalRefNo"] = approvalRefNo
            resultMap["txnId"] = txnId

            if (status.contains("SUCCESS")) {
                resultMap["status"] = "SUCCESS"
                callback.success(resultMap)
            } else if (status.contains("SUBMIT")) {
                resultMap["status"] = "SUBMITTED"
                callback.success(resultMap)
            } else if (status.contains("FAIL")) {
                resultMap["status"] = "FAILURE"
                resultMap["message"] = "Payment was declined or failed at the bank."
                callback.success(resultMap)
            } else {
                val cancelMap = mapOf(
                    "status" to "CANCELLED",
                    "message" to "Payment was cancelled or not completed.",
                    "rawResponse" to responseStr
                )
                callback.success(cancelMap)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Google Config Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGoogleWebApiKey" -> {
                    result.success(BuildConfig.GOOGLE_WEB_API_KEY)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Native UPI Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPI_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUpiPayment" -> {
                    val uriString = call.argument<String>("uri")
                    val appPackage = call.argument<String>("package")

                    if (uriString.isNullOrEmpty()) {
                        result.error("INVALID_ARGS", "UPI URI string is missing", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = Uri.parse(uriString)
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        if (!appPackage.isNullOrEmpty()) {
                            intent.setPackage(appPackage)
                        }

                        pendingUpiResult = result

                        if (intent.resolveActivity(packageManager) != null) {
                            startActivityForResult(intent, UPI_PAYMENT_REQUEST_CODE)
                        } else {
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, uri)
                            val chooser = Intent.createChooser(fallbackIntent, "Pay using UPI")
                            if (fallbackIntent.resolveActivity(packageManager) != null) {
                                startActivityForResult(chooser, UPI_PAYMENT_REQUEST_CODE)
                            } else {
                                pendingUpiResult = null
                                result.error("NO_UPI_APP", "No supported UPI app found on device", null)
                            }
                        }
                    } catch (e: Exception) {
                        pendingUpiResult = null
                        result.error("LAUNCH_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}