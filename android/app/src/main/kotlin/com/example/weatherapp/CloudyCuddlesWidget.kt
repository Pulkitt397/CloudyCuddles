package com.example.weatherapp

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CloudyCuddlesWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.cloudy_cuddles_widget).apply {
                setTextViewText(R.id.widget_location, widgetData.getString("location", "Alwar"))
                setTextViewText(R.id.widget_temp, widgetData.getString("temp", "24°"))
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
