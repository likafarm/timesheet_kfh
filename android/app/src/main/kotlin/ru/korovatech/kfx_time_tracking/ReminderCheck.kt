package ru.korovatech.kfx_time_tracking

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

// 6.10: в час напоминания спросить сервер, что внесено за сегодня
// (lib/services/reminder.dart решает, что показать). Программа открыта —
// спрашивает она (тот же вход); закрыта — отдельный движок Flutter без окна
// запускает reminderCheck. Нет ответа за 25 с — обычное напоминание.
object ReminderCheck {
    /** Канал напоминаний открытой программы (MainActivity). */
    @Volatile
    var liveChannel: MethodChannel? = null

    private const val CHECK_CHANNEL = "ru.korovatech.kfh/reminder_check"
    private const val TIMEOUT_MS = 25_000L

    /** [done] (вид, заголовок, текст) вызывается ровно один раз, в главном потоке. */
    fun run(context: Context, done: (String, String, String) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        var engine: FlutterEngine? = null
        var finished = false
        fun finish(result: Any?) {
            if (finished) return
            finished = true
            val m = result as? Map<*, *>
            done(
                m?.get("kind") as? String ?: "remind",
                m?.get("title") as? String ?: "",
                m?.get("text") as? String ?: "",
            )
            engine?.let { e -> main.post { e.destroy() } }
            engine = null
        }
        main.postDelayed({ finish(null) }, TIMEOUT_MS)

        val live = liveChannel
        if (live != null) {
            live.invokeMethod("check", null, object : MethodChannel.Result {
                override fun success(result: Any?) = finish(result)
                override fun error(code: String, message: String?, details: Any?) = finish(null)
                override fun notImplemented() = finish(null)
            })
            return
        }

        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val e = FlutterEngine(context)
            engine = e
            MethodChannel(e.dartExecutor.binaryMessenger, CHECK_CHANNEL)
                .setMethodCallHandler { call, result ->
                    if (call.method == "result") {
                        result.success(null)
                        finish(call.arguments)
                    } else {
                        result.notImplemented()
                    }
                }
            e.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "package:kfx_time_tracking/services/reminder.dart",
                    "reminderCheck",
                ),
            )
        } catch (e: Exception) {
            finish(null)
        }
    }
}
