package com.ourspace.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

class OurSpaceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    companion object {
        private const val CACHE_NAME = "widget-latest-photo"

        fun save(context: Context, bytes: ByteArray) {
            File(context.filesDir, CACHE_NAME).writeBytes(bytes)
            refresh(context)
        }

        fun clear(context: Context) {
            File(context.filesDir, CACHE_NAME).delete()
            refresh(context)
        }

        private fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, OurSpaceWidgetProvider::class.java))
            ids.forEach { update(context, manager, it) }
        }

        private fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.ourspace_widget)
            val file = File(context.filesDir, CACHE_NAME)
            if (file.exists()) {
                val options = BitmapFactory.Options().apply { inSampleSize = 4 }
                val bitmap = BitmapFactory.decodeFile(file.absolutePath, options)
                views.setImageViewBitmap(R.id.widget_photo, bitmap)
                views.setTextViewText(R.id.widget_caption, "Ảnh mới nhất")
            } else {
                views.setImageViewBitmap(R.id.widget_photo, null)
                views.setTextViewText(R.id.widget_caption, "Mở OurSpace để xem ảnh")
            }
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_photo, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
