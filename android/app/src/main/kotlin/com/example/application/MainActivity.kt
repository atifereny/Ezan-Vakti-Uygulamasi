package com.example.application

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel      = "com.example.application/battery"
    private val alarmChannel = "com.example.application/alarms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Alarm planlama kanalı
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scheduleAlarm" -> {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            scheduleAlarm(
                                id         = args["id"] as Int,
                                title      = args["title"] as String,
                                body       = args["body"] as String,
                                epochMillis= (args["epochMillis"] as Number).toLong(),
                                channelId  = args["channelId"] as String,
                            )
                            result.success(null)
                        }
                        "cancelAlarm" -> {
                            cancelAlarm(call.arguments as Int)
                            result.success(null)
                        }
                        "cancelAlarmRange" -> {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val from = args["from"] as Int
                            val to   = args["to"] as Int
                            for (id in from..to) cancelAlarm(id)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ALARM_ERROR", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "isIgnoringBatteryOptimizations" -> {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                        "requestIgnoreBatteryOptimizations" -> {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(null)
                        }
                        "showPersistentNotification" -> {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            showPrayerNotification(args)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NOTIF_ERROR", e.message, null)
                }
            }
    }

    private fun pendingFlags() =
        PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    private fun scheduleAlarm(id: Int, title: String, body: String, epochMillis: Long, channelId: String) {
        val am = getSystemService(ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
            putExtra("id",        id)
            putExtra("title",     title)
            putExtra("body",      body)
            putExtra("channelId", channelId)
        }
        val pi = PendingIntent.getBroadcast(this, id, intent, pendingFlags())

        // setAlarmClock: uygulama tamamen kapalıyken bile çalışır.
        // Doze modu ve OEM pil optimizasyonu bypass edemez, Android garantisi var.
        val showPi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName) ?: Intent(),
            pendingFlags()
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(epochMillis, showPi), pi)
    }

    private fun cancelAlarm(id: Int) {
        val am = getSystemService(ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, PrayerAlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(this, id, intent, pendingFlags())
        am.cancel(pi)
        pi.cancel()
    }

    private fun showPrayerNotification(data: Map<String, Any>) {
        // Kanal oluşturmak için system service gerekli
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val sysNm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            sysNm.createNotificationChannel(
                NotificationChannel(
                    "persistent_channel",
                    "Namaz Vakitleri — Kalıcı",
                    NotificationManager.IMPORTANCE_LOW
                ).apply { setShowBadge(false) }
            )
        }

        val period   = data["period"] as? String ?: "Ezan Vakti"
        val dative   = data["dative"] as? String ?: ""
        val targetMs = (data["targetEpochMillis"] as? Number)?.toLong() ?: 0L

        val views = RemoteViews(packageName, R.layout.notification_persistent)
        views.setTextViewText(
            R.id.notif_period,
            if (dative.isNotEmpty()) "$period  ·  $dative" else period
        )

        val remainingMs = targetMs - System.currentTimeMillis()
        if (targetMs > 0 && remainingMs > 0) {
            val base = SystemClock.elapsedRealtime() + remainingMs
            views.setChronometer(R.id.notif_countdown, base, null, true)
            // API 24+: countDown yönü; önceki sürümlerde yukarı sayar (zararsız)
            try { views.setBoolean(R.id.notif_countdown, "setCountDown", true) } catch (_: Exception) {}
            views.setViewVisibility(R.id.notif_countdown, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.notif_countdown, View.GONE)
        }

        views.setTextViewText(R.id.notif_fajr,    data["fajr"]    as? String ?: "--:--")
        views.setTextViewText(R.id.notif_sunrise,  data["sunrise"] as? String ?: "--:--")
        views.setTextViewText(R.id.notif_dhuhr,    data["dhuhr"]   as? String ?: "--:--")
        views.setTextViewText(R.id.notif_asr,      data["asr"]     as? String ?: "--:--")
        views.setTextViewText(R.id.notif_maghrib,  data["maghrib"] as? String ?: "--:--")
        views.setTextViewText(R.id.notif_isha,     data["isha"]    as? String ?: "--:--")

        val notification = NotificationCompat.Builder(this, "persistent_channel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .setShowWhen(false)           // Header'daki "32:54" timestamp'i gizler
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            // contentIntent yok → bildirime tıklamak uygulamayı açmaz
            .build()

        // NotificationManagerCompat: Android 13+'da izin yoksa sessizce geçer, crash olmaz
        NotificationManagerCompat.from(this).notify(1, notification)
    }

}
