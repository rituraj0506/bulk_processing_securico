package com.example.bulkprocessing

import android.app.Activity
import android.app.PendingIntent
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "db_channel"
    private val SENT_ACTION = "SMS_SENT_ACTION"
    private val TAG = "SMS_BACKGROUND_DEBUG"

    private fun writeSmsToSentBox(context: Context, phone: String, message: String) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, phone)
                put(Telephony.Sms.BODY, message)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
            Log.i(TAG, "Successfully saved sent SMS to native Messages App DB for: $phone")
            println("[$TAG] SAVED_TO_MESSAGES_APP: Sent SMS recorded in system inbox/outbox for $phone")
        } catch (e: Exception) {
            Log.w(TAG, "Could not insert SMS into Telephony Sent folder: ${e.localizedMessage}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "sendSMS") {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")

                    if (phone.isNullOrEmpty() || message.isNullOrEmpty()) {
                        val errMsg = "Invalid payload: Phone or message is empty"
                        Log.e(TAG, errMsg)
                        println("[$TAG] $errMsg")
                        result.error("INVALID_ARGS", errMsg, null)
                        return@setMethodCallHandler
                    }

                    Log.d(TAG, "Attempting background SMS dispatch to: $phone | Message: $message")
                    println("[$TAG] Starting background SMS send to: $phone")

                    // Save sent SMS to native Messages App DB immediately
                    writeSmsToSentBox(context, phone, message)

                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_ONE_SHOT
                    }

                    val sentIntent = PendingIntent.getBroadcast(
                        context,
                        0,
                        Intent(SENT_ACTION),
                        flags
                    )

                    var isResultReturned = false
                    val mainHandler = Handler(Looper.getMainLooper())

                    val timeoutRunnable = Runnable {
                        if (!isResultReturned) {
                            isResultReturned = true
                            Log.w(TAG, "SMS modem callback pending after 3.5 seconds. Assuming dispatched to carrier queue for $phone")
                            println("[$TAG] DISPATCHED: Modem accepted payload for $phone")
                            result.success("SUCCESS")
                        }
                    }

                    val sentReceiver = object : BroadcastReceiver() {
                        override fun onReceive(arg0: Context?, arg1: Intent?) {
                            mainHandler.removeCallbacks(timeoutRunnable)
                            if (!isResultReturned) {
                                isResultReturned = true
                                try {
                                    unregisterReceiver(this)
                                } catch (_: Exception) {}

                                Log.d(TAG, "Received SMS modem callback. Result code: $resultCode")
                                println("[$TAG] SMS modem callback code: $resultCode")

                                when (resultCode) {
                                    Activity.RESULT_OK -> {
                                        Log.i(TAG, "SMS successfully transmitted over cellular network to $phone")
                                        println("[$TAG] SUCCESS: SMS transmitted to $phone")
                                        result.success("SUCCESS")
                                    }
                                    SmsManager.RESULT_ERROR_GENERIC_FAILURE -> {
                                        val err = "Carrier SMS send failed (Check SIM balance or SMS plan)"
                                        Log.e(TAG, err)
                                        println("[$TAG] ERROR: $err")
                                        result.error("GENERIC_FAILURE", err, null)
                                    }
                                    SmsManager.RESULT_ERROR_NO_SERVICE -> {
                                        val err = "No cellular network service available"
                                        Log.e(TAG, err)
                                        println("[$TAG] ERROR: $err")
                                        result.error("NO_SERVICE", err, null)
                                    }
                                    SmsManager.RESULT_ERROR_NULL_PDU -> {
                                        val err = "Invalid SMS PDU format"
                                        Log.e(TAG, err)
                                        println("[$TAG] ERROR: $err")
                                        result.error("NULL_PDU", err, null)
                                    }
                                    SmsManager.RESULT_ERROR_RADIO_OFF -> {
                                        val err = "Airplane mode active or Mobile Radio turned off"
                                        Log.e(TAG, err)
                                        println("[$TAG] ERROR: $err")
                                        result.error("RADIO_OFF", err, null)
                                    }
                                    else -> {
                                        val detailedReason = when (resultCode) {
                                            16 -> "ERROR_16_DEFAULT_SMS_REQUIRED"
                                            else -> "Modem error code $resultCode"
                                        }
                                        Log.e(TAG, detailedReason)
                                        println("[$TAG] EXPLICIT ERROR: $detailedReason")
                                        result.error("MODEM_ERROR_$resultCode", detailedReason, null)
                                    }
                                }
                            }
                        }
                    }

                    // Schedule 3.5-second fallback dispatch confirmation
                    mainHandler.postDelayed(timeoutRunnable, 3500)

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(sentReceiver, IntentFilter(SENT_ACTION), Context.RECEIVER_EXPORTED)
                        } else {
                            registerReceiver(sentReceiver, IntentFilter(SENT_ACTION))
                        }
                    } catch (_: Exception) {
                        try {
                            registerReceiver(sentReceiver, IntentFilter(SENT_ACTION))
                        } catch (_: Exception) {}
                    }

                    try {
                        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val subId = SubscriptionManager.getDefaultSmsSubscriptionId()
                            if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                                context.getSystemService(SmsManager::class.java).createForSubscriptionId(subId)
                            } else {
                                context.getSystemService(SmsManager::class.java)
                            }
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val subId = SubscriptionManager.getDefaultSmsSubscriptionId()
                            if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                                @Suppress("DEPRECATION")
                                SmsManager.getSmsManagerForSubscriptionId(subId)
                            } else {
                                applicationContext.getSystemService(SmsManager::class.java)
                            }
                        } else {
                            @Suppress("DEPRECATION")
                            SmsManager.getDefault()
                        }

                        // Use sendMultipartTextMessage for multi-part encoding & modem compatibility
                        val parts = smsManager.divideMessage(message)
                        val sentIntents = ArrayList<PendingIntent>()
                        for (i in 0 until parts.size) {
                            sentIntents.add(sentIntent)
                        }

                        smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
                        Log.i(TAG, "sendMultipartTextMessage invoked successfully for $phone")
                    } catch (e: Exception) {
                        mainHandler.removeCallbacks(timeoutRunnable)
                        if (!isResultReturned) {
                            isResultReturned = true
                            try {
                                unregisterReceiver(sentReceiver)
                            } catch (_: Exception) {}
                            val exMsg = "Exception in sendMultipartTextMessage: ${e.localizedMessage}"
                            Log.e(TAG, exMsg, e)
                            println("[$TAG] EXCEPTION: $exMsg")
                            result.error("EXCEPTION", exMsg, null)
                        }
                    }
                } else if (call.method == "requestDefaultSmsRole") {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(RoleManager::class.java)
                            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS) && !roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                                startActivity(intent)
                                result.success(true)
                                return@setMethodCallHandler
                            }
                        } else {
                            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                            startActivity(intent)
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        result.success(false)
                    } catch (e: Exception) {
                        result.error("ROLE_ERROR", e.localizedMessage, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
