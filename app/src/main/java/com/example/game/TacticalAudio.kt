package com.example.game

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.math.sin
import kotlin.random.Random

/**
 * Offline real-time tactical audio synthesizer using Android AudioTrack.
 * Generates cannon blasts, artillery explosions, machinegun fire, and radio beeps
 * without requiring any external assets or network access.
 */
object TacticalAudio {
    private val scope = CoroutineScope(Dispatchers.Default)
    private const val SAMPLE_RATE = 22050

    fun playCannonFire() {
        scope.launch {
            val durationMs = 280
            val numSamples = (SAMPLE_RATE * durationMs) / 1000
            val buffer = ShortArray(numSamples)
            for (i in 0 until numSamples) {
                val t = i.toDouble() / SAMPLE_RATE
                val envelope = (1.0 - (i.toDouble() / numSamples)).coerceIn(0.0, 1.0)
                val freq = 120.0 * (1.0 - (i.toDouble() / numSamples) * 0.7)
                val sine = sin(2.0 * Math.PI * freq * t)
                val noise = (Random.nextDouble() * 2.0 - 1.0) * 0.7
                val sample = ((sine * 0.6 + noise * 0.4) * envelope * Short.MAX_VALUE * 0.85).toInt()
                buffer[i] = sample.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
            playPcm(buffer)
        }
    }

    fun playArtilleryBoom() {
        scope.launch {
            val durationMs = 450
            val numSamples = (SAMPLE_RATE * durationMs) / 1000
            val buffer = ShortArray(numSamples)
            for (i in 0 until numSamples) {
                val t = i.toDouble() / SAMPLE_RATE
                val envelope = (1.0 - (i.toDouble() / numSamples)).coerceIn(0.0, 1.0)
                val freq = 75.0 * (1.0 - (i.toDouble() / numSamples) * 0.5)
                val sub = sin(2.0 * Math.PI * freq * t)
                val rumble = (Random.nextDouble() * 2.0 - 1.0)
                val sample = ((sub * 0.5 + rumble * 0.5) * envelope * Short.MAX_VALUE * 0.9).toInt()
                buffer[i] = sample.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
            playPcm(buffer)
        }
    }

    fun playRifleShot() {
        scope.launch {
            val durationMs = 110
            val numSamples = (SAMPLE_RATE * durationMs) / 1000
            val buffer = ShortArray(numSamples)
            for (i in 0 until numSamples) {
                val envelope = (1.0 - (i.toDouble() / numSamples)).coerceIn(0.0, 1.0)
                val noise = (Random.nextDouble() * 2.0 - 1.0)
                val sample = (noise * envelope * Short.MAX_VALUE * 0.5).toInt()
                buffer[i] = sample.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
            playPcm(buffer)
        }
    }

    fun playOrderBeep() {
        scope.launch {
            val durationMs = 80
            val numSamples = (SAMPLE_RATE * durationMs) / 1000
            val buffer = ShortArray(numSamples)
            for (i in 0 until numSamples) {
                val t = i.toDouble() / SAMPLE_RATE
                val freq = 880.0
                val sine = sin(2.0 * Math.PI * freq * t)
                val sample = (sine * 0.4 * Short.MAX_VALUE).toInt()
                buffer[i] = sample.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
            playPcm(buffer)
        }
    }

    private fun playPcm(buffer: ShortArray) {
        try {
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(buffer.size * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            track.write(buffer, 0, buffer.size)
            track.play()
            track.setNotificationMarkerPosition(buffer.size)
            track.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
                override fun onMarkerReached(t: AudioTrack?) {
                    try {
                        t?.stop()
                        t?.release()
                    } catch (_: Exception) {}
                }
                override fun onPeriodicNotification(t: AudioTrack?) {}
            })
        } catch (_: Exception) {
            // AudioTrack unavailable or muted
        }
    }
}
