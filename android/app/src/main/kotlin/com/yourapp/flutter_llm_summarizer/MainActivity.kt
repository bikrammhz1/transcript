package com.yourapp.flutter_llm_summarizer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register the LlamaPlugin
        flutterEngine.plugins.add(LlamaPlugin())
    }
}
