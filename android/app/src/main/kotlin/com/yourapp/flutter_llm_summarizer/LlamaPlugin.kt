package com.yourapp.flutter_llm_summarizer

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin for llama.cpp integration
 * Handles method calls from Flutter to native C++ code
 */
class LlamaPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  
  companion object {
    private const val TAG = "LlamaPlugin"
    
    init {
      Log.d(TAG, "🔌 Loading native library 'llama'...")
      try {
        // Load native library
        System.loadLibrary("llama")
        Log.d(TAG, "✅ Native library loaded successfully")
      } catch (e: UnsatisfiedLinkError) {
        Log.e(TAG, "❌ FAILED to load native library: ${e.message}")
      }
    }
  }

  // Native methods
  private external fun initLlama(modelPath: String, threads: Int, contextSize: Int): Long
  private external fun generate(ctx: Long, prompt: String, maxTokens: Int, temperature: Float): String
  private external fun releaseLlama(ctx: Long)

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(TAG, "🔌 onAttachedToEngine - Registering channel: com.flutterLlmSummarizer/llama")
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.flutterLlmSummarizer/llama")
    channel.setMethodCallHandler(this)
    Log.d(TAG, "✅ Plugin attached successfully")
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d(TAG, "📥 Received method call: ${call.method}")
    
    when (call.method) {
      "initModel" -> {
        Log.d(TAG, "🚀 handleInitModel")
        try {
          val modelPath = call.argument<String>("modelPath") ?: ""
          val threads = call.argument<Int>("threads") ?: 2
          val contextSize = call.argument<Int>("contextSize") ?: 2048

          Log.d(TAG, "📋 Init parameters:")
          Log.d(TAG, "   - Model path: $modelPath")
          Log.d(TAG, "   - Threads: $threads")
          Log.d(TAG, "   - Context size: $contextSize")

          if (modelPath.isEmpty()) {
            Log.e(TAG, "❌ FAILED: Model path is empty")
            result.error("INVALID_ARGUMENT", "Model path cannot be empty", null)
            return
          }

          Log.d(TAG, "⏳ Calling native initLlama()...")
          val ctx = initLlama(modelPath, threads, contextSize)
          
          if (ctx != 0L) {
            Log.d(TAG, "✅ SUCCESS: Model initialized")
            Log.d(TAG, "   - Context pointer: $ctx")
            result.success(mapOf(
              "success" to true,
              "contextPointer" to ctx.toString()
            ))
          } else {
            Log.e(TAG, "❌ FAILED: initLlama returned 0")
            result.error("INIT_FAILED", "Failed to initialize model", null)
          }
        } catch (e: Exception) {
          Log.e(TAG, "❌ EXCEPTION: ${e.message}")
          Log.e(TAG, "   - Stack trace: ${e.stackTraceToString()}")
          result.error("EXCEPTION", e.message, null)
        }
      }
      "generate" -> {
        Log.d(TAG, "🚀 handleGenerate")
        try {
          val ctxStr = call.argument<String>("contextPointer") ?: ""
          val prompt = call.argument<String>("prompt") ?: ""
          val maxTokens = call.argument<Int>("maxTokens") ?: 200
          val temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.7f

          Log.d(TAG, "📋 Generate parameters:")
          Log.d(TAG, "   - Context pointer: $ctxStr")
          Log.d(TAG, "   - Prompt length: ${prompt.length} chars")
          Log.d(TAG, "   - Max tokens: $maxTokens")
          Log.d(TAG, "   - Temperature: $temperature")

          if (ctxStr.isEmpty()) {
            Log.e(TAG, "❌ FAILED: Context pointer is empty")
            result.error("INVALID_CONTEXT", "Context pointer is null", null)
            return
          }

          val ctx = ctxStr.toLong()
          Log.d(TAG, "⏳ Calling native generate()...")
          val generatedText = generate(ctx, prompt, maxTokens, temperature)

          Log.d(TAG, "✅ SUCCESS: Text generated")
          Log.d(TAG, "   - Generated length: ${generatedText.length} chars")
          Log.d(TAG, "   - Preview: ${generatedText.take(100)}...")
          
          result.success(mapOf(
            "success" to true,
            "text" to generatedText
          ))
        } catch (e: Exception) {
          Log.e(TAG, "❌ EXCEPTION in generate: ${e.message}")
          Log.e(TAG, "   - Stack trace: ${e.stackTraceToString()}")
          result.error("GENERATION_FAILED", e.message, null)
        }
      }
      "releaseModel" -> {
        Log.d(TAG, "🚀 handleReleaseModel")
        try {
          val ctxStr = call.argument<String>("contextPointer") ?: ""
          Log.d(TAG, "   - Context pointer: $ctxStr")
          
          if (ctxStr.isNotEmpty()) {
            val ctx = ctxStr.toLong()
            Log.d(TAG, "⏳ Calling native releaseLlama()...")
            releaseLlama(ctx)
            Log.d(TAG, "✅ SUCCESS: Model released")
          } else {
            Log.d(TAG, "⚠️ Nothing to release (empty context)")
          }
          result.success(mapOf("success" to true))
        } catch (e: Exception) {
          Log.e(TAG, "❌ EXCEPTION in release: ${e.message}")
          result.error("RELEASE_FAILED", e.message, null)
        }
      }
      else -> {
        Log.w(TAG, "⚠️ Method not implemented: ${call.method}")
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(TAG, "🔌 onDetachedFromEngine - Cleaning up")
    channel.setMethodCallHandler(null)
    Log.d(TAG, "✅ Plugin detached")
  }
}

