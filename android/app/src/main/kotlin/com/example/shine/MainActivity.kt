package com.example.shine

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "flashlight"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        
        try {
            cameraId = cameraManager?.cameraIdList?.get(0)
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "toggleFlashlight" -> {
                    val turnOn = call.arguments as Boolean
                    toggleFlashlight(turnOn)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun toggleFlashlight(turnOn: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                cameraId?.let { id ->
                    cameraManager?.setTorchMode(id, turnOn)
                }
            }
        } catch (e: CameraAccessException) {
            e.printStackTrace()
        }
    }
}
