package com.miwodo.miwodo

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.miwodo.miwodo/audio_recorder"
    private var mediaRecorder: MediaRecorder? = null
    private var currentFilePath: String? = null
    private var startTimeMs: Long = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        try {
                            stopRecorderSilently()
                            val fileName = "voice_${System.currentTimeMillis()}.m4a"
                            val file = File(cacheDir, fileName)
                            currentFilePath = file.absolutePath

                            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                MediaRecorder(this)
                            } else {
                                @Suppress("DEPRECATION")
                                MediaRecorder()
                            }

                            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
                            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            recorder.setAudioEncodingBitRate(128000)
                            recorder.setAudioSamplingRate(44100)
                            recorder.setOutputFile(currentFilePath)
                            recorder.prepare()
                            recorder.start()

                            mediaRecorder = recorder
                            startTimeMs = System.currentTimeMillis()
                            result.success(currentFilePath)
                        } catch (e: Exception) {
                            stopRecorderSilently()
                            result.error("RECORD_START_ERROR", e.message, null)
                        }
                    }
                    "stopRecording" -> {
                        try {
                            val path = currentFilePath
                            val durationSec = if (startTimeMs > 0) {
                                ((System.currentTimeMillis() - startTimeMs) / 1000L).toInt().coerceAtLeast(1)
                            } else {
                                1
                            }
                            mediaRecorder?.apply {
                                try {
                                    stop()
                                } catch (_: Exception) {}
                                reset()
                                release()
                            }
                            mediaRecorder = null
                            currentFilePath = null
                            startTimeMs = 0L

                            if (path != null && File(path).exists() && File(path).length() > 0) {
                                result.success(mapOf("path" to path, "duration" to durationSec))
                            } else {
                                result.error("RECORD_EMPTY", "Fichier audio vide ou introuvable", null)
                            }
                        } catch (e: Exception) {
                            stopRecorderSilently()
                            result.error("RECORD_STOP_ERROR", e.message, null)
                        }
                    }
                    "cancelRecording" -> {
                        val path = currentFilePath
                        stopRecorderSilently()
                        if (path != null) {
                            try {
                                File(path).delete()
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun stopRecorderSilently() {
        try {
            mediaRecorder?.apply {
                try {
                    stop()
                } catch (_: Exception) {}
                reset()
                release()
            }
        } catch (_: Exception) {}
        mediaRecorder = null
        currentFilePath = null
        startTimeMs = 0L
    }

    override fun onDestroy() {
        stopRecorderSilently()
        super.onDestroy()
    }
}
