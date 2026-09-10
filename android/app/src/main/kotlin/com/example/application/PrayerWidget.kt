package com.example.application

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

class PrayerWidget : HomeWidgetProvider() {

    companion object {
        private const val PREFS_NAME   = "HomeWidgetPreferences"
        private val COLOR_ACTIVE       = Color.parseColor("#7A5C2E")
        private val COLOR_NORMAL       = Color.parseColor("#2C1A08")
        private const val LARGE_WIDTH  = 250
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val minWidth = appWidgetManager.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            updateWidget(context, appWidgetManager, widgetId, widgetData, minWidth)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        updateWidget(context, appWidgetManager, appWidgetId, prefs, minWidth)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
        minWidth: Int
    ) {
        val layout = if (minWidth >= LARGE_WIDTH) R.layout.prayer_widget_large else R.layout.prayer_widget
        val views  = RemoteViews(context.packageName, layout)

        views.setTextViewText(R.id.widget_city,    data.getString("city",    "—")     ?: "—")
        views.setTextViewText(R.id.widget_fajr,    data.getString("fajr",    "--:--") ?: "--:--")
        views.setTextViewText(R.id.widget_sunrise, data.getString("sunrise", "--:--") ?: "--:--")
        views.setTextViewText(R.id.widget_dhuhr,   data.getString("dhuhr",   "--:--") ?: "--:--")
        views.setTextViewText(R.id.widget_asr,     data.getString("asr",     "--:--") ?: "--:--")
        views.setTextViewText(R.id.widget_maghrib, data.getString("maghrib", "--:--") ?: "--:--")
        views.setTextViewText(R.id.widget_isha,    data.getString("isha",    "--:--") ?: "--:--")

        val next = data.getString("next_prayer", "")
        views.setTextViewText(R.id.widget_next, if (!next.isNullOrEmpty()) "Sonraki: $next" else "")

        // Aktif vakti hesapla ve vurgula
        val current = getCurrentPrayer(data)
        views.setTextColor(R.id.widget_fajr,    if (current == "fajr")    COLOR_ACTIVE else COLOR_NORMAL)
        views.setTextColor(R.id.widget_sunrise,  if (current == "sunrise") COLOR_ACTIVE else COLOR_NORMAL)
        views.setTextColor(R.id.widget_dhuhr,    if (current == "dhuhr")   COLOR_ACTIVE else COLOR_NORMAL)
        views.setTextColor(R.id.widget_asr,      if (current == "asr")     COLOR_ACTIVE else COLOR_NORMAL)
        views.setTextColor(R.id.widget_maghrib,  if (current == "maghrib") COLOR_ACTIVE else COLOR_NORMAL)
        views.setTextColor(R.id.widget_isha,     if (current == "isha")    COLOR_ACTIVE else COLOR_NORMAL)

        // Yenile butonu
        val refreshIntent = Intent(context, PrayerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
        }
        val pi = PendingIntent.getBroadcast(
            context, widgetId, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_refresh, pi)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun getCurrentPrayer(data: SharedPreferences): String {
        val cal    = Calendar.getInstance()
        val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        fun parse(key: String): Int {
            val t = data.getString(key, null) ?: return -1
            val p = t.split(":")
            if (p.size != 2) return -1
            return (p[0].toIntOrNull() ?: return -1) * 60 + (p[1].toIntOrNull() ?: return -1)
        }

        val fajr    = parse("fajr");    if (fajr    < 0) return ""
        val sunrise = parse("sunrise"); if (sunrise < 0) return ""
        val dhuhr   = parse("dhuhr");   if (dhuhr   < 0) return ""
        val asr     = parse("asr");     if (asr     < 0) return ""
        val maghrib = parse("maghrib"); if (maghrib < 0) return ""
        val isha    = parse("isha");    if (isha    < 0) return ""

        return when {
            nowMin < fajr    -> "isha"
            nowMin < sunrise -> "fajr"
            nowMin < dhuhr   -> "sunrise"
            nowMin < asr     -> "dhuhr"
            nowMin < maghrib -> "asr"
            nowMin < isha    -> "maghrib"
            else             -> "isha"
        }
    }
}
