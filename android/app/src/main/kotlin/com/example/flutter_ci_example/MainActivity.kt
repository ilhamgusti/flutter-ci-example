package com.example.flutter_ci_example

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "music_sync/pip"
        private const val EVENT_CHANNEL = "music_sync/pip_events"
        private const val MIN_API = Build.VERSION_CODES.O // 26, Android 8.0
    }

    private var eventSink: EventChannel.EventSink? = null

    /** Whether the app currently wants to drop into PiP when the user leaves. */
    private var shouldAutoPip = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(isPipSupported())

                    "enter" -> {
                        if (!isPipSupported()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            enterPip()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "setAutoEnter" -> {
                        shouldAutoPip = call.argument<Boolean>("enabled") ?: false
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    emitPipState() // Report the current mode so Flutter bootstraps.
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun isPipSupported(): Boolean = Build.VERSION.SDK_INT >= MIN_API

    private fun buildParams(): PictureInPictureParams {
        // 16:9 matches the YouTube player surface; within the allowed ratio range.
        return PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
    }

    private fun enterPip() {
        enterPictureInPictureMode(buildParams())
    }

    private fun emitPipState() {
        val inPip = isPipSupported() && isInPictureInPictureMode
        eventSink?.success(mapOf("inPip" to inPip))
    }

    /**
     * Fires when the user presses Home while the activity is foregrounded.
     * Drop into PiP when the Flutter side has indicated playback is active.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (shouldAutoPip && isPipSupported()) {
            try {
                enterPip()
            } catch (_: Exception) {
                // Some OEMs reject PiP; fail silently.
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        eventSink?.success(mapOf("inPip" to isInPictureInPictureMode))
    }
}
