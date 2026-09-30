package ru.korovatech.kfx_time_tracking

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

// 6.10: напоминание о табеле (решения владельца 2026-09-30). Когда
// напоминать, решает программа (Dart: оператору 19:00, админу 19:20, каждый
// день) — сюда приходит готовый список моментов; он же восстанавливается
// после перезагрузки телефона. В момент напоминания — проверка на сервере
// (ReminderCheck): внёс другой — «табель внесён», всё внёс сам — ничего.
object Reminder {
    const val EXTRA = "kfh_reminder"
    private const val PREFS = "kfh_reminder"
    private const val KEY_TIMES = "times"
    private const val CHANNEL = "timesheet_reminder"
    private const val NOTIFICATION_ID = 6010
    private const val ENTERED_ID = 6012
    private const val ENTERED_CHANNEL = "timesheet_entered"
    private const val FIRST_CODE = 7000
    private const val SNOOZE_CODE = 7999
    private const val MAX_ALARMS = 40

    /** Заменить все напоминания моментами [times] (мс с 1970 г., UTC). */
    fun schedule(context: Context, times: List<Long>) {
        val list = times.sorted().take(MAX_ALARMS)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_TIMES, list.joinToString(","))
            .apply()
        register(context, list)
    }

    /** После перезагрузки: будильники Android сбрасываются. */
    fun restore(context: Context) {
        val text = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TIMES, "") ?: ""
        val now = System.currentTimeMillis()
        register(
            context,
            text.split(",").mapNotNull { it.toLongOrNull() }.filter { it > now },
        )
    }

    fun snooze(context: Context, minutes: Int) {
        cancelNotification(context)
        set(context, SNOOZE_CODE, System.currentTimeMillis() + minutes * 60_000L)
    }

    fun cancelNotification(context: Context) {
        manager(context).cancel(NOTIFICATION_ID)
    }

    private fun register(context: Context, times: List<Long>) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        for (code in FIRST_CODE until FIRST_CODE + MAX_ALARMS) {
            alarms.cancel(alarmIntent(context, code))
        }
        alarms.cancel(alarmIntent(context, SNOOZE_CODE))
        times.forEachIndexed { i, t -> set(context, FIRST_CODE + i, t) }
    }

    private fun set(context: Context, code: Int, time: Long) {
        // Неточный будильник («около 19 часов»): особое разрешение на точные
        // не нужно, в режиме сна телефона тоже срабатывает.
        context.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, alarmIntent(context, code))
    }

    private fun alarmIntent(context: Context, code: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            code,
            Intent(context, ReminderReceiver::class.java).setAction(ACTION_FIRE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    const val ACTION_FIRE = "ru.korovatech.kfh.REMINDER"

    private fun manager(context: Context) =
        context.getSystemService(NotificationManager::class.java)

    /** Можно ли открывать напоминание на весь экран (Android 14+ — разрешение). */
    fun canFullScreen(context: Context): Boolean =
        Build.VERSION.SDK_INT < 34 || manager(context).canUseFullScreenIntent()

    fun canNotify(context: Context): Boolean =
        manager(context).areNotificationsEnabled()

    /** Показать напоминание: на весь экран (экран заблокирован или выключен),
     *  иначе — всплывающим уведомлением; касание открывает то же окно. */
    fun show(context: Context) {
        val nm = manager(context)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Напоминание о табеле",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = "Вечернее напоминание заполнить табель за день" },
            )
        }
        val open = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java)
                .putExtra(EXTRA, true)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("Табель за сегодня")
            .setContentText("Пора отметить, кто сегодня работал")
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .build()
        nm.notify(NOTIFICATION_ID, notification)
    }

    /** «Табель за сегодня внесён тем-то»: обычное уведомление с итогом. */
    fun showEntered(context: Context, title: String, text: String) {
        val nm = manager(context)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    ENTERED_CHANNEL,
                    "Табель внесён",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = "Кто и что внёс в табель за сегодня" },
            )
        }
        val open = PendingIntent.getActivity(
            context,
            ENTERED_ID,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, ENTERED_CHANNEL)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        nm.notify(
            ENTERED_ID,
            builder
                .setSmallIcon(android.R.drawable.ic_menu_agenda)
                .setContentTitle(title)
                .setContentText(text.lineSequence().first())
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setCategory(Notification.CATEGORY_STATUS)
                .setAutoCancel(true)
                .setContentIntent(open)
                .build(),
        )
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Reminder.ACTION_FIRE -> {
                val pending = goAsync()
                val app = context.applicationContext
                ReminderCheck.run(app) { kind, title, text ->
                    when (kind) {
                        "entered" -> Reminder.showEntered(app, title, text)
                        "none" -> {}
                        else -> Reminder.show(app)
                    }
                    pending.finish()
                }
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> Reminder.restore(context)
        }
    }
}
