package com.dvara.bulkprocessing

import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "db_channel"
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

                    Log.d(TAG, "Dispatching SMS (fire-and-forget) to: $phone | Message: $message")
                    println("[$TAG] Firing SMS to: $phone")

                    // Save sent SMS to native Messages App DB immediately
                    writeSmsToSentBox(context, phone, message)

                    // Fire-and-forget: invoke the modem call and return immediately.
                    // No sent-intent tracking, no delivery/result-code wait — the caller
                    // only cares that the OS accepted the send request.
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
                        smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                        Log.i(TAG, "sendMultipartTextMessage invoked for $phone")
                        println("[$TAG] FIRED: sendMultipartTextMessage invoked for $phone")
                        result.success("SUCCESS")
                    } catch (e: Exception) {
                        val exMsg = "Exception in sendMultipartTextMessage: ${e.localizedMessage}"
                        Log.e(TAG, exMsg, e)
                        println("[$TAG] EXCEPTION: $exMsg")
                        result.error("EXCEPTION", exMsg, null)
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
