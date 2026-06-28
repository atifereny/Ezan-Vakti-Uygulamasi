package com.example.application

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val data = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)

            // Şehir
            views.setTextViewText(
                R.id.widget_city,
                data.getString("city", "—") ?: "—"
            )

            // Namaz vakitleri
            views.setTextViewText(R.id.widget_fajr,    data.getString("fajr",    "--:--") ?: "--:--")
            views.setTextViewText(R.id.widget_sunrise,  data.getString("sunrise",  "--:--") ?: "--:--")
            views.setTextViewText(R.id.widget_dhuhr,   data.getString("dhuhr",   "--:--") ?: "--:--")
            views.setTextViewText(R.id.widget_asr,     data.getString("asr",     "--:--") ?: "--:--")
            views.setTextViewText(R.id.widget_maghrib, data.getString("maghrib", "--:--") ?: "--:--")
            views.setTextViewText(R.id.widget_isha,    data.getString("isha",    "--:--") ?: "--:--")

            // Sonraki vakit
            val next = data.getString("next_prayer", "")
            views.setTextViewText(
                R.id.widget_next,
                if (!next.isNullOrEmpty()) "Sonraki: $next" else ""
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
