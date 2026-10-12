package br.com.rockservicos.moto_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var rideAlertPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal de notificação dos avisos de corrida, com o som do Moto (spec
        // push-notification-sounds). O Dart chama isto no início do app, antes de inicializar o
        // OneSignal; recriar o mesmo id é inofensivo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "ensureChannel" -> {
                            ensureChannel(
                                id = call.argument<String>("id") ?: error("id ausente"),
                                name = call.argument<String>("name") ?: error("name ausente"),
                                description = call.argument<String>("description") ?: "",
                                soundResource = call.argument<String>("sound") ?: "",
                            )
                            result.success(true)
                        }
                        "playRideAlertSound" -> {
                            playRideAlertSound(
                                call.argument<String>("sound") ?: "moto_notification"
                            )
                            result.success(true)
                        }
                        "stopRideAlertSound" -> {
                            stopRideAlertSound()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("channel_failed", e.javaClass.simpleName, null)
                }
            }
    }

    private fun playRideAlertSound(soundResource: String) {
        val soundId = resources.getIdentifier(soundResource, "raw", packageName)
        if (soundId == 0) return

        rideAlertPlayer?.run {
            if (isPlaying) stop()
            release()
        }
        rideAlertPlayer = MediaPlayer.create(this, soundId)?.apply {
            setOnCompletionListener { player ->
                player.release()
                if (rideAlertPlayer === player) rideAlertPlayer = null
            }
            start()
        }
    }

    private fun stopRideAlertSound() {
        rideAlertPlayer?.run {
            if (isPlaying) stop()
            release()
        }
        rideAlertPlayer = null
    }

    override fun onDestroy() {
        stopRideAlertSound()
        super.onDestroy()
    }

    private fun ensureChannel(id: String, name: String, description: String, soundResource: String) {
        // Antes do Android 8 não existem canais.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        // Canal já existente: não mexe, para preservar a escolha de som e importância do usuário
        // (o Android também trava essas configurações depois da primeira notificação).
        if (manager.getNotificationChannel(id) != null) return

        val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
            this.description = description
            enableVibration(true)

            val soundId = resources.getIdentifier(soundResource, "raw", packageName)
            if (soundId != 0) {
                val soundUri = Uri.parse(
                    "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/$soundId"
                )
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, attributes)
            }
            // Sem o arquivo, o canal usa o som padrão do sistema: a notificação não se perde.
        }

        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val NOTIFICATION_CHANNEL = "moto/notification_channel"
    }
}
