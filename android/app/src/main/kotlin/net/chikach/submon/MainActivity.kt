package net.chikach.submon

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.PersistableBundle
import android.util.Log
import android.widget.Toast
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationChannelGroupCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

val chromiumBrowserPackages = listOf(
    "com.android.chrome",
    "com.chrome.beta",
    "com.chrome.dev",
    "com.chrome.canary",
    "com.microsoft.emmx",
    "com.microsoft.emmx.beta",
    "com.microsoft.emmx.dev",
    "com.microsoft.emmx.canary",
    "com.brave.browser",
    "com.vivaldi.browser",
    "com.opera.browser",
    "com.sec.android.app.sbrowser",
    "com.sec.android.app.sbrowser.beta",
)

const val REMINDER_CHANNEL = "reminder"
const val TIMETABLE_CHANNEL = "timetable"

const val METHOD_CHANNEL_MAIN = "submon/main"
const val METHOD_CHANNEL_NOTIFICATION = "submon/notification"
const val METHOD_CHANNEL_ACTIONS = "submon/actions"

class MainActivity : FlutterActivity() {
    lateinit var mainMethodChannel: MethodChannel
    var pendingAction: String? = null
    var pendingActionArgument: Int? = null

    companion object {
        const val EXTRA_FLUTTER_ACTION = "FLUTTER_ACTION"
        const val EXTRA_FLUTTER_ACTION_ARGUMENT_ID = "FLUTTER_ACTION_ARGUMENT_ID"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (intent.hasExtra(EXTRA_FLUTTER_ACTION)) {
            val mc =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_ACTIONS)

            pendingAction = intent.getStringExtra(EXTRA_FLUTTER_ACTION)
            pendingActionArgument = intent.getIntExtra(EXTRA_FLUTTER_ACTION_ARGUMENT_ID, -1)
            mc.invokeMethod(pendingAction!!, pendingActionArgument)
        }

        mainMethodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_MAIN)
        mainMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openWebPage" -> {
                    val title = call.argument<String>("title")
                    val url = call.argument<String>("url")
                    startActivity(
                        Intent(this, WebPageActivity::class.java)
                            .putExtra("title", title)
                            .putExtra("url", url)
                    )
                    result.success(null)
                }
                "openCustomTabs" -> {
                    val ctIntent = CustomTabsIntent.Builder().build()
                    val pm = packageManager
                    if (!chromiumBrowserPackages.contains(
                            pm.resolveActivity(
                                Intent("android.intent.action.VIEW", Uri.parse("http://")),
                                PackageManager.MATCH_DEFAULT_ONLY
                            )?.activityInfo?.packageName
                        )
                    ) {
                        val `package` = chromiumBrowserPackages.firstOrNull {
                            try {
                                pm.getApplicationEnabledSetting(it) == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                            } catch (e: IllegalArgumentException) {
                                false
                            }
                        }
                        if (`package` != null) {
                            ctIntent.intent.setPackage(`package`)
                        } else {
                            Toast.makeText(
                                this,
                                "Google Chromeもしくは、それ以外のChromium系ブラウザーをインストールする必要があります",
                                Toast.LENGTH_SHORT
                            ).show()
                            return@setMethodCallHandler
                        }
                    }
                    ctIntent.launchUrl(this, Uri.parse(call.argument("url")))
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        val notificationMethodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NOTIFICATION)
        notificationMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isGranted" -> {
                    result.success(true)
                }
                "registerReminder" -> {
                    Utils.registerReminderNotification(
                        this,
                        call.argument("title")!!,
                        call.argument("body")!!,
                        call.argument("hour")!!,
                        call.argument("minute")!!,
                    )
                    result.success(null)
                }
                "unregisterReminder" -> {
                    Utils.cancelReminderNotification(this)
                    result.success(null)
                }
                "registerTimetable" -> {
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        val amc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_ACTIONS)
        amc.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingAction" -> {
                    result.success(pendingAction)
                    pendingAction = null
                }
                "getPendingActionArgument" -> {
                    result.success(pendingActionArgument)
                    pendingActionArgument = null
                }
            }
        }

        val notificationMgr = NotificationManagerCompat.from(context)
        notificationMgr.createNotificationChannelGroup(
            NotificationChannelGroupCompat.Builder("main")
                .setName("メイン")
                .build()
        )
        notificationMgr.createNotificationChannel(
            NotificationChannelCompat.Builder(REMINDER_CHANNEL, NotificationManager.IMPORTANCE_HIGH)
                .setName("リマインダー通知")
                .setGroup("main")
                .build()
        )
        notificationMgr.createNotificationChannel(
            NotificationChannelCompat.Builder(
                TIMETABLE_CHANNEL,
                NotificationManager.IMPORTANCE_DEFAULT
            )
                .setName("時間割通知")
                .setGroup("main")
                .build()
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 10) {
            Log.d("result", data.toString())
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.data != null) mainMethodChannel.invokeMethod("onUriData", intent.data!!.query)

        Log.d("onnewintent", "called")
        if (intent.hasExtra(EXTRA_FLUTTER_ACTION) && flutterEngine != null) {
            val mc =
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, METHOD_CHANNEL_ACTIONS)
            mc.invokeMethod(
                intent.getStringExtra(EXTRA_FLUTTER_ACTION)!!, intent.getIntExtra(
                    EXTRA_FLUTTER_ACTION_ARGUMENT_ID, -1
                )
            )
        }
    }

}
