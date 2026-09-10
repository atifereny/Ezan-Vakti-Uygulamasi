package com.example.application

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import java.util.Calendar

/**
 * Cihaz yeniden başladığında veya uygulama güncellendiğinde
 * SharedPreferences cache'inden namaz alarmlarını yeniden kurar.
 * Flutter engine bağımlılığı yoktur; saf Kotlin.
 */
class PrayerBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )
            val cal = Calendar.getInstance()
            val currentMonthKey = monthKey(cal)

            // Önce ana cache'i dene, sonra ön-cache'i (ay sonu önceden çekilmiş olabilir)
            val jsonData: JSONArray = run {
                val month = prefs.getString("flutter.prayer_cache_month", null)
                val data  = prefs.getString("flutter.prayer_cache_data",  null)
                if (month == currentMonthKey && data != null) {
                    return@run JSONArray(data)
                }
                val nextMonth = prefs.getString("flutter.prayer_cache_month_next", null)
                val nextData  = prefs.getString("flutter.prayer_cache_data_next",  null)
                if (nextMonth == currentMonthKey && nextData != null) {
                    return@run JSONArray(nextData)
                }
                return // Cache yok veya bayat; uygulama açılınca kurar
            }

            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val showPi = PendingIntent.getActivity(
                context, 0,
                context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(),
                pendingFlags()
            )

            val today = cal.get(Calendar.DAY_OF_MONTH)
            val year  = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH) + 1 // Calendar.MONTH is 0-based

            for (i in 0 until jsonData.length()) {
                val entry     = jsonData.getJSONObject(i)
                val day       = entry.getInt("day")
                val dayOffset = day - today
                if (dayOffset < 0 || dayOffset > 30) continue

                val idBase      = 10 + dayOffset * 30
                val kerahatBase = 20 + dayOffset * 30

                val fajr    = entry.getString("fajr")
                val sunrise = entry.getString("sunrise")
                val dhuhr   = entry.getString("dhuhr")
                val asr     = entry.getString("asr")
                val maghrib = entry.getString("maghrib")
                val isha    = entry.getString("isha")

                // Namaz vakitleri
                listOf(
                    Triple(idBase,     "İmsak Vakti",  fajr),
                    Triple(idBase + 1, "Güneş Vakti",  sunrise),
                    Triple(idBase + 2, "Öğle Vakti",   dhuhr),
                    Triple(idBase + 3, "İkindi Vakti", asr),
                    Triple(idBase + 4, "Akşam Vakti",  maghrib),
                    Triple(idBase + 5, "Yatsı Vakti",  isha),
                ).forEach { (id, title, timeStr) ->
                    val ms = toEpochMillis(year, month, day, timeStr)
                    if (ms > System.currentTimeMillis()) {
                        schedule(context, am, showPi, id, title,
                            "$timeStr — Vakit girdi.", ms, "prayer_channel")
                    }
                }

                // Kerahat vakitleri
                listOf(
                    Triple(kerahatBase,     "Güneş doğuşu — Kerahat",
                        toEpochMillis(year, month, day, sunrise)),
                    Triple(kerahatBase + 1, "Öğle öncesi — Kerahat",
                        toEpochMillis(year, month, day, dhuhr) - 5 * 60_000L),
                    Triple(kerahatBase + 2, "Akşam öncesi — Kerahat",
                        toEpochMillis(year, month, day, maghrib) - 45 * 60_000L),
                ).forEach { (id, title, ms) ->
                    if (ms > System.currentTimeMillis()) {
                        schedule(context, am, showPi, id, title,
                            "Nafile namaz kılınmaz.", ms, "kerahat_channel")
                    }
                }
            }
        } catch (_: Exception) {
            // Boot receiver asla crash etmemeli
        }
    }

    private fun schedule(
        context: Context, am: AlarmManager, showPi: PendingIntent,
        id: Int, title: String, body: String,
        epochMillis: Long, channelId: String,
    ) {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            putExtra("id",        id)
            putExtra("title",     title)
            putExtra("body",      body)
            putExtra("channelId", channelId)
        }
        val pi = PendingIntent.getBroadcast(context, id, intent, pendingFlags())
        am.setAlarmClock(AlarmManager.AlarmClockInfo(epochMillis, showPi), pi)
    }

    private fun toEpochMillis(year: Int, month: Int, day: Int, timeStr: String): Long {
        val (h, m) = timeStr.split(":").map { it.toInt() }
        return Calendar.getInstance().apply {
            set(year, month - 1, day, h, m, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun monthKey(cal: Calendar): String {
        val y = cal.get(Calendar.YEAR)
        val m = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        return "$y-$m"
    }

    private fun pendingFlags() =
        PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
}
