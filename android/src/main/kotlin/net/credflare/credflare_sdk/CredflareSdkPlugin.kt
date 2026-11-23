package net.credflare.credflare_sdk

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CredflareSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val detectors = mutableMapOf<String, FaceDetector>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "credflare_sdk/faces")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        detectors.values.forEach { it.close() }
        detectors.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "mlkit#process" -> process(call, result)
            "mlkit#close" -> {
                call.argument<String>("id")?.let { detectors.remove(it)?.close() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun process(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val bytes = call.argument<ByteArray>("bytes")
        val width = call.argument<Int>("width")
        val height = call.argument<Int>("height")
        val rotation = call.argument<Int>("rotation")
        if (id == null || bytes == null || width == null || height == null || rotation == null) {
            result.error("invalid_frame", "A frame needs id, bytes, width, height and rotation.", null)
            return
        }
        val image = try {
            InputImage.fromByteArray(bytes, width, height, rotation, InputImage.IMAGE_FORMAT_NV21)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_frame", error.message, null)
            return
        }
        val detector = detectors.getOrPut(id) {
            FaceDetection.getClient(
                FaceDetectorOptions.Builder()
                    .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                    .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
                    .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
                    .setMinFaceSize(0.15f)
                    .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                    .build(),
            )
        }
        detector.process(image)
            .addOnSuccessListener { faces ->
                result.success(
                    faces.map { face ->
                        val rect = face.boundingBox
                        mapOf(
                            "left" to rect.left,
                            "top" to rect.top,
                            "right" to rect.right,
                            "bottom" to rect.bottom,
                            "pitch" to face.headEulerAngleX.toDouble(),
                            "yaw" to face.headEulerAngleY.toDouble(),
                            "smile" to face.smilingProbability?.toDouble(),
                            "left_eye_open" to face.leftEyeOpenProbability?.toDouble(),
                            "right_eye_open" to face.rightEyeOpenProbability?.toDouble(),
                        )
                    },
                )
            }
            .addOnFailureListener { error -> result.error("detection_failed", error.toString(), null) }
    }
}
