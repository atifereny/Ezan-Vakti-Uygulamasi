package com.example.application

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val id      = intent.getIntExtra("id", 0)
            val title   = intent.getStringExtra("title") ?: return
            val body    = intent.getStringExtra("body") ?: ""
            val channel = intent.getStringExtra("channelId") ?: "prayer_channel"
            val isKerahat = channel == "kerahat_channel"

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(
                    channel,
                    if (isKerahat) "Kerahat Vakitleri" else "Namaz Vakitleri",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { enableVibration(true) }
                nm.createNotificationChannel(ch)
            }

            val pendingFlags =
                PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

            val tapIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?: Intent()
            val tap = PendingIntent.getActivity(context, id, tapIntent, pendingFlags)

            val color = if (isKerahat) 0xFFB71C1C.toInt() else 0xFF7A5C2E.toInt()

            val notification = NotificationCompat.Builder(context, channel)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setColor(color)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(tap)
                .setAutoCancel(true)
                .build()

            nm.notify(id, notification)
        } catch (_: Exception) {
            // Hiçbir hata uygulamayı çökertmesin
        }
    }
}
