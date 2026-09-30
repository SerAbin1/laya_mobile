package com.example.laya_mobile

import android.util.Log
import com.example.laya_mobile.laya.LayaCalibration
import com.example.laya_mobile.laya.LayaPromptBuilder
import com.example.laya_mobile.laya.LayaTokenizer
import com.example.laya_mobile.laya.buildChoiceInputs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example/laya_engine"
    private val executor = Executors.newSingleThreadExecutor()

    @Volatile private var tokenizer: LayaTokenizer? = null
    @Volatile private var promptBuilder: LayaPromptBuilder? = null
    @Volatile private var calibration: LayaCalibration? = null
    @Volatile private var calibrationMap: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Queued first on the single-thread executor: tokenize calls are
        // serialized behind it and are guaranteed a ready tokenizer.
        executor.execute { initializeEngine() }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> {
                        Log.d(TAG, "Received: ${call.arguments}")
                        result.success("pong")
                    }
                    "tokenize" -> {
                        val text = call.arguments as? String
                        if (text == null) {
                            result.error("bad_args", "tokenize expects a String argument", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                val ids = checkNotNull(tokenizer) { "Tokenizer not initialized" }
                                    .encode(text)
                                Log.d(TAG, "ids=${ids.toList()}")
                                runOnUiThread { result.success(ids.toList()) }
                            } catch (e: Exception) {
                                Log.e(TAG, "tokenize failed", e)
                                runOnUiThread { result.error("tokenize_error", e.message, null) }
                            }
                        }
                    }
                    "buildSequence" -> {
                        val question = call.argument<String>("question")
                        val options = call.argument<List<String>>("options")
                        val state = call.argument<String>("state")
                        if (question == null || options == null || state == null) {
                            result.error("bad_args",
                                "buildSequence expects {question, options, state}", null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            try {
                                val inputs = checkNotNull(promptBuilder) { "Builder not initialized" }
                                    .buildChoiceInputs(question, options, state)
                                val realLength = inputs.attentionMask.count { it == 1f }
                                Log.d(TAG, "input_ids=${inputs.inputIds.toList()}")
                                Log.d(TAG, "attention_mask=${inputs.attentionMask.toList()}")
                                Log.d(TAG, "qtype_onehot=${inputs.qtypeOnehot.toList()}")
                                Log.d(TAG, "markers=${inputs.markers.toList()} " +
                                    "ids@markers=${inputs.markers.map { inputs.inputIds[it] }} " +
                                    "(MASK=${LayaPromptBuilder.MASK}) realLength=$realLength")
                                val payload = mapOf(
                                    "input_ids" to inputs.inputIds.toList(),
                                    "attention_mask" to inputs.attentionMask.map { it.toDouble() },
                                    "qtype_onehot" to inputs.qtypeOnehot.map { it.toDouble() },
                                    "markers" to inputs.markers.toList(),
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                Log.e(TAG, "buildSequence failed", e)
                                runOnUiThread { result.error("build_error", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeEngine() {
        try {
            val start = System.currentTimeMillis()
            val loaded = LayaTokenizer(ensureAssetInstalled("tokenizer.json"))
            tokenizer = loaded
            promptBuilder = LayaPromptBuilder(loaded)
            Log.d(TAG, "Tokenizer ready in ${System.currentTimeMillis() - start} ms")

            val calibrationFile = ensureAssetInstalled("calibration.json")
            val map = LayaCalibration.loadMap(calibrationFile)
            calibrationMap = map
            calibration = LayaCalibration.fromMap(map)
            Log.d(TAG, "Calibration map keys=${map.keys} " +
                "temperatures=${(map["temperature"] as? List<*>)?.size} " +
                "buckets=${((map["temperature_by_options"] as? Map<*, *>)?.size)}")
        } catch (e: Exception) {
            Log.e(TAG, "Engine initialization failed", e)
        }
    }

    /**
     * Copies a bundled Flutter asset into filesDir so file-based reference code
     * gets a real File. Skips the copy when an installed file already matches
     * the asset size; falls back to existence when the asset size is unavailable
     * (compressed assets have no AssetFileDescriptor).
     */
    private fun ensureAssetInstalled(name: String): File {
        val target = File(filesDir, name)
        val assetSize = try {
            assets.openFd("flutter_assets/assets/$name").length
        } catch (_: IOException) {
            -1L
        }
        if (target.isFile && (assetSize < 0 || target.length() == assetSize)) return target

        Log.d(TAG, "Installing asset $name" +
            (if (assetSize >= 0) " ($assetSize bytes)" else " (size unknown)"))
        val temp = File(filesDir, "$name.tmp")
        assets.open("flutter_assets/assets/$name").use { input ->
            temp.outputStream().use { output -> input.copyTo(output) }
        }
        if (!temp.renameTo(target)) {
            target.delete()
            check(temp.renameTo(target)) { "Failed to install $name" }
        }
        return target
    }

    companion object {
        private const val TAG = "LayaEngine"
    }
}
