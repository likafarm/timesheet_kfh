package ru.korovatech.kfx_time_tracking

import android.Manifest
import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

// 6.10:
// - «Сохранить на телефон» — системное окно выбора папки
//   (ACTION_CREATE_DOCUMENT). В отличие от «Поделиться» после него всегда
//   возвращаемся в программу.
// - Напоминание о табеле (Reminder.kt): окно поверх экрана блокировки,
//   ввод — после разблокировки.
class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<ByteArray, MethodChannel.Result>? = null
    private var reminderChannel: MethodChannel? = null

    /** Программу открыло напоминание, пока она была не на экране. */
    private var openedByReminder = false
    private var reminderPending = false
    private var resumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        takeReminder(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        takeReminder(intent)
    }

    override fun onDestroy() {
        if (ReminderCheck.liveChannel === reminderChannel) ReminderCheck.liveChannel = null
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        resumed = true
    }

    override fun onPause() {
        super.onPause()
        resumed = false
    }

    private fun takeReminder(intent: Intent?) {
        if (intent?.getBooleanExtra(Reminder.EXTRA, false) != true) return
        intent.removeExtra(Reminder.EXTRA)
        openedByReminder = !resumed
        showOverLock(true)
        Reminder.cancelNotification(this)
        reminderPending = true
        reminderChannel?.invokeMethod("reminder", null)
    }

    private fun showOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureFiles(flutterEngine)
        configureReminder(flutterEngine)
    }

    private fun configureFiles(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAs" -> {
                        if (pendingSave != null) {
                            result.error("busy", "Файл уже сохраняется", null)
                            return@setMethodCallHandler
                        }
                        val name = call.argument<String>("name")!!
                        val mime = call.argument<String>("mime")!!
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mime
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        pendingSave = bytes to result
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, SAVE_REQUEST)
                        } catch (e: ActivityNotFoundException) {
                            pendingSave = null
                            result.error("no_picker", "Нет окна выбора папки", null)
                        }
                    }
                    "open" -> {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                Uri.parse(call.argument<String>("uri")!!),
                                call.argument<String>("mime")!!,
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureReminder(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
        reminderChannel = channel
        ReminderCheck.liveChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    val times = call.argument<List<Number>>("times")!!.map { it.toLong() }
                    Reminder.schedule(this, times)
                    result.success(null)
                }
                "snooze" -> {
                    Reminder.snooze(this, call.argument<Int>("minutes")!!)
                    result.success(null)
                }
                // Окно напоминания ждёт программа (запуск или уже работала).
                "takePending" -> {
                    result.success(reminderPending)
                    reminderPending = false
                }
                "status" -> result.success(
                    mapOf(
                        "notifications" to Reminder.canNotify(this),
                        "fullScreen" to Reminder.canFullScreen(this),
                    ),
                )
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33 && !Reminder.canNotify(this)) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 6011)
                    }
                    result.success(null)
                }
                "openFullScreenSettings" -> {
                    val uri = Uri.parse("package:" + packageName)
                    val intent = if (Build.VERSION.SDK_INT >= 34) {
                        Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, uri)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
                    }
                    try {
                        startActivity(intent)
                    } catch (e: ActivityNotFoundException) {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri))
                    }
                    result.success(null)
                }
                "isLocked" -> result.success(
                    getSystemService(KeyguardManager::class.java).isKeyguardLocked,
                )
                // Ввести данные — только после разблокировки телефона.
                "unlock" -> {
                    val keyguard = getSystemService(KeyguardManager::class.java)
                    if (!keyguard.isKeyguardLocked || Build.VERSION.SDK_INT < 26) {
                        result.success(!keyguard.isKeyguardLocked)
                    } else {
                        keyguard.requestDismissKeyguard(
                            this,
                            object : KeyguardManager.KeyguardDismissCallback() {
                                override fun onDismissSucceeded() = result.success(true)
                                override fun onDismissCancelled() = result.success(false)
                                override fun onDismissError() = result.success(false)
                            },
                        )
                    }
                }
                // Окно напоминания закрыто: программу, открытую напоминанием,
                // убрать назад — человек возвращается к тому, что делал.
                "done" -> {
                    showOverLock(false)
                    if (openedByReminder && call.argument<Boolean>("leave") == true) {
                        moveTaskToBack(true)
                    }
                    openedByReminder = false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_REQUEST) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val (bytes, result) = pendingSave ?: return
        pendingSave = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(uri, "wt")
                ?: throw IOException("Нет доступа к файлу")
            stream.use { it.write(bytes) }
            result.success(uri.toString())
        } catch (e: Exception) {
            result.error("write", e.message, null)
        }
    }

    companion object {
        private const val FILES_CHANNEL = "ru.korovatech.kfh/files"
        private const val REMINDER_CHANNEL = "ru.korovatech.kfh/reminder"
        private const val SAVE_REQUEST = 6010
    }
}
