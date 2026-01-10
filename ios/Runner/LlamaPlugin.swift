import Flutter
import UIKit

// Import C functions from bridging header
@_silgen_name("initLlama")
func initLlama(_ modelPath: UnsafePointer<CChar>, _ threads: Int32, _ contextSize: Int32) -> OpaquePointer?

@_silgen_name("generate")
func generate(_ ctx: OpaquePointer, _ prompt: UnsafePointer<CChar>, _ maxTokens: Int32, _ temperature: Float) -> UnsafeMutablePointer<CChar>?

@_silgen_name("releaseLlama")
func releaseLlama(_ ctx: OpaquePointer)

/// Flutter plugin for llama.cpp integration on iOS
public class LlamaPlugin: NSObject, FlutterPlugin {
    
    // Store context pointers
    private var contexts: [String: OpaquePointer] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        print("🔌 [LlamaPlugin] Registering plugin with channel: com.flutterLlmSummarizer/llama")
        let channel = FlutterMethodChannel(
            name: "com.flutterLlmSummarizer/llama",
            binaryMessenger: registrar.messenger()
        )
        let instance = LlamaPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("✅ [LlamaPlugin] Plugin registered successfully")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("📥 [LlamaPlugin] Received method call: \(call.method)")
        switch call.method {
        case "initModel":
            handleInitModel(call: call, result: result)
        case "generate":
            handleGenerate(call: call, result: result)
        case "releaseModel":
            handleReleaseModel(call: call, result: result)
        default:
            print("❌ [LlamaPlugin] Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleInitModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🚀 [LlamaPlugin] handleInitModel called")
        
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            print("❌ [LlamaPlugin] FAILED: Invalid arguments - modelPath is missing")
            print("   Arguments received: \(String(describing: call.arguments))")
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Model path is required",
                details: nil
            ))
            return
        }
        
        let threads = args["threads"] as? Int ?? 2
        let contextSize = args["contextSize"] as? Int ?? 2048
        
        print("📋 [LlamaPlugin] Init parameters:")
        print("   - Model path: \(modelPath)")
        print("   - Threads: \(threads)")
        print("   - Context size: \(contextSize)")
        
        // Call C++ function
        print("⏳ [LlamaPlugin] Calling native initLlama()...")
        let ctx = modelPath.withCString { cString in
            return initLlama(cString, Int32(threads), Int32(contextSize))
        }
        
        if let ctx = ctx {
            let contextKey = UUID().uuidString
            contexts[contextKey] = ctx
            
            print("✅ [LlamaPlugin] SUCCESS: Model initialized")
            print("   - Context key: \(contextKey)")
            print("   - Total active contexts: \(contexts.count)")
            
            result([
                "success": true,
                "contextPointer": contextKey
            ])
        } else {
            print("❌ [LlamaPlugin] FAILED: initLlama() returned null")
            print("   - This means llama.cpp integration is not complete")
            print("   - llama_ios.cpp contains placeholder code")
            
            result(FlutterError(
                code: "INIT_FAILED",
                message: "Failed to initialize model. The native llama.cpp integration is not yet complete. The current implementation is a placeholder that returns null. To enable LLM features:\n\n1. Build llama.cpp for iOS (see SETUP.md)\n2. Add llama.cpp to Xcode project\n3. Replace placeholder code in llama_ios.cpp with actual llama.cpp API calls\n4. Link against the compiled llama library\n\nSee ios/NATIVE_INTEGRATION_STATUS.md for detailed instructions.",
                details: "Placeholder implementation - llama.cpp not integrated yet"
            ))
        }
    }
    
    private func handleGenerate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🚀 [LlamaPlugin] handleGenerate called")
        
        guard let args = call.arguments as? [String: Any],
              let contextKey = args["contextPointer"] as? String,
              let prompt = args["prompt"] as? String else {
            print("❌ [LlamaPlugin] FAILED: Invalid arguments for generate")
            print("   Arguments received: \(String(describing: call.arguments))")
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Context pointer and prompt are required",
                details: nil
            ))
            return
        }
        
        guard let ctx = contexts[contextKey] else {
            print("❌ [LlamaPlugin] FAILED: Invalid context pointer")
            print("   - Requested key: \(contextKey)")
            print("   - Available keys: \(Array(contexts.keys))")
            result(FlutterError(
                code: "INVALID_CONTEXT",
                message: "Invalid context pointer",
                details: nil
            ))
            return
        }
        
        let maxTokens = args["maxTokens"] as? Int ?? 200
        let temperature = args["temperature"] as? Double ?? 0.7
        
        print("📋 [LlamaPlugin] Generate parameters:")
        print("   - Context key: \(contextKey)")
        print("   - Prompt length: \(prompt.count) chars")
        print("   - Max tokens: \(maxTokens)")
        print("   - Temperature: \(temperature)")
        
        // Call C++ function
        print("⏳ [LlamaPlugin] Calling native generate()...")
        let generatedText = prompt.withCString { cString in
            return generate(ctx, cString, Int32(maxTokens), Float(temperature))
        }
        
        if let generatedText = generatedText {
            let text = String(cString: generatedText)
            // Free C string (allocated with new[] in C++)
            generatedText.deallocate()
            
            print("✅ [LlamaPlugin] SUCCESS: Text generated")
            print("   - Generated length: \(text.count) chars")
            print("   - Preview: \(String(text.prefix(100)))...")
            
            result([
                "success": true,
                "text": text
            ])
        } else {
            print("❌ [LlamaPlugin] FAILED: generate() returned null")
            result(FlutterError(
                code: "GENERATION_FAILED",
                message: "Failed to generate text",
                details: nil
            ))
        }
    }
    
    private func handleReleaseModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🚀 [LlamaPlugin] handleReleaseModel called")
        
        guard let args = call.arguments as? [String: Any],
              let contextKey = args["contextPointer"] as? String,
              let ctx = contexts[contextKey] else {
            print("⚠️ [LlamaPlugin] Release: Context already released or invalid")
            result([
                "success": true  // Already released or invalid
            ])
            return
        }
        
        print("📋 [LlamaPlugin] Releasing context: \(contextKey)")
        
        // Call C++ function
        releaseLlama(ctx)
        contexts.removeValue(forKey: contextKey)
        
        print("✅ [LlamaPlugin] SUCCESS: Model released")
        print("   - Remaining contexts: \(contexts.count)")
        
        result([
            "success": true
        ])
    }
}

