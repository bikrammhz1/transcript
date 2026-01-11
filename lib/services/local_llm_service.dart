import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model_config.dart';

/// Service class for managing local LLM models and inference
class LocalLLMService {
  static const MethodChannel _channel = MethodChannel('com.flutterLlmSummarizer/llama');
  
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal() {
    debugPrint('🔌 [LocalLLMService] Service instance created');
    debugPrint('   Channel: com.flutterLlmSummarizer/llama');
  }

  bool _isInitialized = false;
  ModelConfig? _currentModel;
  String? _currentContextPointer; // Store context pointer as string

  /// Available model configurations
  /// NOTE: These URLs are publicly accessible without authentication
  static final List<ModelConfig> availableModels = [
    // SmolLM-135M from QuantFactory - publicly accessible, no auth required
    ModelConfig(
      key: 'tinyllama-1.1b-q4', // Keep key for backwards compatibility
      name: 'SmolLM-135M-Q4 (Recommended)',
      downloadUrl: 'https://huggingface.co/QuantFactory/SmolLM-135M-Instruct-GGUF/resolve/5af1cd23df57f5ec9e1495e05ada134502897076/SmolLM-135M-Instruct.Q4_K_M.gguf',
      sizeBytes: 105 * 1024 * 1024, // ~105MB (actual file size)
      format: 'GGUF',
      promptFormat: 'chatml',
      recommended: true,
    ),
    // Smaller Q2 version for devices with less memory
    ModelConfig(
      key: 'tinyllama-1.1b-q2',
      name: 'TinyLlama-1.1B-Q2 (Smaller)',
      downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
      sizeBytes: 482 * 1024 * 1024, // ~482MB
      format: 'GGUF',
      promptFormat: 'chatml',
      recommended: false,
    ),
    // Phi-2 from TheBloke - good quality, publicly accessible
    ModelConfig(
      key: 'phi-2-q4',
      name: 'Phi-2-Q4 (Best Quality)',
      downloadUrl: 'https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf',
      sizeBytes: 1600 * 1024 * 1024, // ~1.6GB
      format: 'GGUF',
      promptFormat: 'phi',
      recommended: false,
    ),
  ];

  /// Get available models list
  List<ModelConfig> getAvailableModels() => availableModels;

  /// Check if model is downloaded (and has valid size)
  Future<bool> isModelDownloaded(String modelKey) async {
    debugPrint('🔍 [LocalLLMService] isModelDownloaded checking: $modelKey');
    try {
      final model = availableModels.firstWhere((m) => m.key == modelKey);
      final file = await _getModelFile(model.filename);
      final exists = await file.exists();
      debugPrint('   - File: ${file.path}');
      debugPrint('   - Exists: $exists');
      
      if (exists) {
        final size = await file.length();
        debugPrint('   - Size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
        debugPrint('   - Expected: ${model.sizeFormatted}');
        
        // Check if file is corrupted (too small - less than 1MB for any model)
        if (size < 1024 * 1024) {
          debugPrint('⚠️ [LocalLLMService] File is too small (corrupted/incomplete)');
          debugPrint('   - Deleting corrupted file...');
          await file.delete();
          return false;
        }
        
        // Also check if reasonably close to expected size (within 10%)
        final expectedSize = model.sizeBytes;
        final sizeDiff = (size - expectedSize).abs();
        final tolerance = expectedSize * 0.1; // 10% tolerance
        
        if (sizeDiff > tolerance && size < expectedSize * 0.5) {
          debugPrint('⚠️ [LocalLLMService] File size mismatch (incomplete download)');
          debugPrint('   - Deleting incomplete file...');
          await file.delete();
          return false;
        }
        
        debugPrint('✅ [LocalLLMService] Model file is valid');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error checking model: $e');
      return false;
    }
  }

  /// Get model file path
  Future<File> _getModelFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return File('${modelsDir.path}/$filename');
  }

  /// Download model with progress callback
  Future<void> downloadModel(
    String modelKey, {
    required Function(double progress, String status) onProgress,
  }) async {
    debugPrint('📥 [LocalLLMService] downloadModel called');
    debugPrint('   - Model key: $modelKey');
    
    final model = availableModels.firstWhere((m) => m.key == modelKey);
    final file = await _getModelFile(model.filename);

    debugPrint('   - Model: ${model.name}');
    debugPrint('   - URL: ${model.downloadUrl}');
    debugPrint('   - Expected size: ${model.sizeFormatted}');
    debugPrint('   - Target file: ${file.path}');

    // Check if already downloaded
    if (await file.exists()) {
      final existingSize = await file.length();
      debugPrint('   - Existing file size: ${(existingSize / 1024 / 1024).toStringAsFixed(2)} MB');
      if (existingSize == model.sizeBytes) {
        debugPrint('✅ [LocalLLMService] Model already downloaded');
        onProgress(1.0, 'Model already downloaded');
        return;
      }
      // Partial download, delete and retry
      debugPrint('⚠️ [LocalLLMService] Partial download detected, deleting...');
      await file.delete();
    }

    debugPrint('⏳ [LocalLLMService] Starting download...');
    onProgress(0.0, 'Starting download...');

    try {
      final request = http.Request('GET', Uri.parse(model.downloadUrl));
      final streamedResponse = await http.Client().send(request);
      
      final contentLength = streamedResponse.contentLength ?? model.sizeBytes;
      int downloadedBytes = 0;
      
      final sink = file.openWrite();
      
      await streamedResponse.stream.listen(
        (chunk) {
          downloadedBytes += chunk.length;
          sink.add(chunk);
          final progress = contentLength > 0 
              ? (downloadedBytes / contentLength).clamp(0.0, 1.0)
              : 0.0;
          onProgress(
            progress,
            'Downloading: ${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB',
          );
        },
        onDone: () async {
          await sink.close();
          // Verify file size
          final fileSize = await file.length();
          if (fileSize < model.sizeBytes * 0.9) {
            // File seems corrupted or incomplete
            await file.delete();
            throw Exception('Download incomplete. File size mismatch.');
          }
          onProgress(1.0, 'Download complete');
        },
        onError: (error) async {
          await sink.close();
          if (await file.exists()) {
            await file.delete();
          }
          throw Exception('Download failed: $error');
        },
      ).asFuture();
    } catch (e) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  /// Initialize model (download if needed, then load)
  Future<void> initialize({
    required String modelKey,
    required Function(double progress, String status) onProgress,
  }) async {
    if (_isInitialized && _currentModel?.key == modelKey) {
      return; // Already initialized with this model
    }

    final model = availableModels.firstWhere((m) => m.key == modelKey);
    
    // Download if not exists
    if (!await isModelDownloaded(modelKey)) {
      onProgress(0.0, 'Downloading model...');
      await downloadModel(
        modelKey,
        onProgress: (progress, status) {
          onProgress(progress * 0.8, status); // Reserve 20% for initialization
        },
      );
    }

    // Load model
    onProgress(0.8, 'Initializing model...');
    try {
      final file = await _getModelFile(model.filename);
      final modelPath = file.path;

      debugPrint('🚀 [LocalLLMService] Initializing model...');
      debugPrint('   - Model: ${model.name}');
      debugPrint('   - Path: $modelPath');
      debugPrint('   - Threads: ${model.defaultThreads}');
      debugPrint('   - Context size: ${model.contextSize}');

      // Store selected model in preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', modelKey);

      // Call native method to initialize
      debugPrint('⏳ [LocalLLMService] Calling native initModel()...');
      final result = await _channel.invokeMethod('initModel', {
        'modelPath': modelPath,
        'threads': model.defaultThreads,
        'contextSize': model.contextSize,
      });

      debugPrint('📥 [LocalLLMService] Native response: $result');

      if (result is Map && result['success'] == true) {
        _currentContextPointer = result['contextPointer']?.toString();
        _currentModel = model;
        _isInitialized = true;
        debugPrint('✅ [LocalLLMService] SUCCESS: Model initialized');
        debugPrint('   - Context pointer: $_currentContextPointer');
        debugPrint('   - isInitialized: $_isInitialized');
        onProgress(1.0, 'Model initialized successfully');
      } else {
        // Extract error message
        String errorMsg = result['error'] ?? 'Failed to initialize model';
        String details = result['details'] ?? '';
        
        debugPrint('❌ [LocalLLMService] FAILED: Init returned error');
        debugPrint('   - Error: $errorMsg');
        debugPrint('   - Details: $details');
        
        throw Exception(
          errorMsg + (details.isNotEmpty ? '\n\nDetails: $details' : '')
        );
      }
    } on MissingPluginException catch (e) {
      _isInitialized = false;
      _currentModel = null;
      debugPrint('❌ [LocalLLMService] FAILED: MissingPluginException');
      debugPrint('   - Error: $e');
      debugPrint('   - This means the native plugin is not registered');
      debugPrint('   - Channel: com.flutterLlmSummarizer/llama');
      onProgress(0.0, 'Native plugin not registered');
      throw Exception(
        'Native LLM plugin is not available. This is expected if you haven\'t completed the native integration yet.\n\n'
        'To enable the native plugin:\n'
        '1. Open ios/Runner.xcworkspace in Xcode\n'
        '2. Add LlamaPlugin.swift to the Runner target (see ios/ADD_LLAMA_PLUGIN.md)\n'
        '3. Complete the llama.cpp native integration\n\n'
        'For now, the app UI will work but LLM features require native integration.'
      );
    } on PlatformException catch (e) {
      _isInitialized = false;
      _currentModel = null;
      debugPrint('❌ [LocalLLMService] FAILED: PlatformException');
      debugPrint('   - Code: ${e.code}');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - Details: ${e.details}');
      onProgress(0.0, 'Initialization failed: ${e.message}');
      rethrow;
    } catch (e) {
      _isInitialized = false;
      _currentModel = null;
      debugPrint('❌ [LocalLLMService] FAILED: Unknown error');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error: $e');
      onProgress(0.0, 'Initialization failed: $e');
      rethrow;
    }
  }

  /// Generate summary from transcript
  Future<String> summarizeTranscript(
    String transcript, {
    int maxTokens = 200,
    double temperature = 0.7,
    String summaryType = 'concise',
  }) async {
    debugPrint('🚀 [LocalLLMService] summarizeTranscript called');
    debugPrint('   - Transcript length: ${transcript.length} chars');
    debugPrint('   - Summary type: $summaryType');
    debugPrint('   - Max tokens: $maxTokens');
    debugPrint('   - Temperature: $temperature');
    debugPrint('   - isInitialized: $_isInitialized');
    
    if (!_isInitialized) {
      debugPrint('❌ [LocalLLMService] FAILED: Model not initialized');
      throw Exception('Model not initialized. Call initialize() first.');
    }

    // Truncate transcript if too long (1500 chars)
    if (transcript.length > 1500) {
      debugPrint('⚠️ [LocalLLMService] Truncating transcript from ${transcript.length} to 1500 chars');
      transcript = '${transcript.substring(0, 1500)}... [truncated]';
    }

    final prompt = _buildPrompt(_currentModel!, transcript, summaryType);
    debugPrint('📝 [LocalLLMService] Prompt built, length: ${prompt.length} chars');

    try {
      debugPrint('⏳ [LocalLLMService] Calling native generate()...');
      final result = await _channel.invokeMethod('generate', {
        'contextPointer': _currentContextPointer,
        'prompt': prompt,
        'maxTokens': maxTokens,
        'temperature': temperature,
      });

      debugPrint('📥 [LocalLLMService] Native response received');

      if (result is Map && result['success'] == true) {
        final text = result['text'] as String;
        debugPrint('✅ [LocalLLMService] SUCCESS: Text generated');
        debugPrint('   - Generated length: ${text.length} chars');
        debugPrint('   - Preview: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
        return text;
      } else {
        debugPrint('❌ [LocalLLMService] FAILED: Generate returned error');
        debugPrint('   - Result: $result');
        throw Exception(result['error'] ?? 'Generation failed');
      }
    } on MissingPluginException catch (e) {
      debugPrint('❌ [LocalLLMService] FAILED: MissingPluginException');
      debugPrint('   - Error: $e');
      throw Exception(
        'Native LLM plugin is not available. Please complete the native integration.\n'
        'See ios/ADD_LLAMA_PLUGIN.md for instructions.'
      );
    } on PlatformException catch (e) {
      debugPrint('❌ [LocalLLMService] FAILED: PlatformException');
      debugPrint('   - Code: ${e.code}');
      debugPrint('   - Message: ${e.message}');
      debugPrint('   - Details: ${e.details}');
      throw Exception('Failed to generate summary: ${e.message}');
    } catch (e) {
      debugPrint('❌ [LocalLLMService] FAILED: Unknown error');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error: $e');
      throw Exception('Failed to generate summary: $e');
    }
  }

  /// Build prompt based on model format and summary type
  String _buildPrompt(ModelConfig model, String transcript, String summaryType) {
    debugPrint('📝 [LocalLLMService] Building prompt with format: ${model.promptFormat}');
    
    switch (model.promptFormat) {
      case 'chatml':
        return _buildChatMLPrompt(transcript, summaryType);
      case 'phi':
        return _buildPhiPrompt(transcript, summaryType);
      default:
        return _buildChatMLPrompt(transcript, summaryType);
    }
  }

  /// Build Phi-2 format prompt
  String _buildPhiPrompt(String transcript, String summaryType) {
    String instruction;
    switch (summaryType) {
      case 'concise':
        instruction = 'Summarize this transcript briefly in 2-3 sentences';
        break;
      case 'detailed':
        instruction = 'Write a detailed summary of this transcript, including all key points and context';
        break;
      case 'bullet_points':
        instruction = 'List the main points from this transcript as bullet points';
        break;
      case 'keywords':
        instruction = 'Extract keywords. Output format: `word1`, `word2`, `word3`. Single words in backticks, comma-separated. No grammar words';
        break;
      case 'topics':
        instruction = 'Identify the main topics discussed in this transcript. List each topic with a one-sentence description';
        break;
      case 'action_items':
        instruction = 'Extract any action items, tasks, or next steps mentioned in this transcript. List each as a bullet point';
        break;
      default:
        instruction = 'Summarize this transcript';
    }

    return '''Instruct: $instruction

$transcript

Output:''';
  }

  /// Build ChatML format prompt
  String _buildChatMLPrompt(String transcript, String summaryType) {
    String instruction;
    String systemPrompt = 'You are a helpful assistant that analyzes transcripts.';
    
    switch (summaryType) {
      case 'concise':
        instruction = 'Summarize this transcript briefly in 2-3 sentences:';
        systemPrompt = 'You are a helpful assistant that summarizes transcripts concisely.';
        break;
      case 'detailed':
        instruction = 'Write a detailed summary of this transcript, including all key points and context:';
        systemPrompt = 'You are a helpful assistant that provides detailed summaries.';
        break;
      case 'bullet_points':
        instruction = 'List the main points from this transcript as bullet points:';
        systemPrompt = 'You are a helpful assistant that extracts key points.';
        break;
      case 'keywords':
        instruction = 'Extract keywords from this text:';
        systemPrompt = '''You are a keyword extraction system.

Extract only keywords, not sentences or phrases.

Rules:
- Return single words only
- No full sentences
- No explanations
- Ignore grammar words (is, the, a, to, with, etc.)
- Focus on objects, emotions, actions, and imagery
- Keywords must come directly from the text

Output format example:
`keyword1`, `keyword2`, `keyword3`, `keyword4`, `keyword5`

Output ONLY in this format with backticks around each word.''';
        break;
      case 'topics':
        instruction = 'Identify the main topics discussed in this transcript. For each topic, provide a one-sentence description:\n\nTranscript:';
        systemPrompt = 'You are an expert at identifying and categorizing discussion topics.';
        break;
      case 'action_items':
        instruction = 'Extract any action items, tasks, decisions, or next steps mentioned in this transcript. List each as a bullet point:\n\nTranscript:';
        systemPrompt = 'You are an expert at identifying actionable items and tasks from conversations.';
        break;
      default:
        instruction = 'Summarize this transcript:';
    }

    return '''<|im_start|>system
$systemPrompt<|im_end|>
<|im_start|>user
$instruction

$transcript<|im_end|>
<|im_start|>assistant
''';
  }

  /// Get currently initialized model
  ModelConfig? get currentModel => _currentModel;

  /// Check if model is initialized
  bool get isInitialized => _isInitialized;

  /// Get last selected model key from preferences
  Future<String?> getLastSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_model');
  }

  /// Delete model file
  Future<void> deleteModel(String modelKey) async {
    debugPrint('🗑️ [LocalLLMService] deleteModel called');
    debugPrint('   - Model key: $modelKey');
    
    if (_currentModel?.key == modelKey && _isInitialized) {
      debugPrint('   - Model is currently loaded, disposing first...');
      await dispose();
    }
    
    final model = availableModels.firstWhere((m) => m.key == modelKey);
    final file = await _getModelFile(model.filename);
    
    if (await file.exists()) {
      await file.delete();
      debugPrint('✅ [LocalLLMService] SUCCESS: Model file deleted');
    } else {
      debugPrint('⚠️ [LocalLLMService] Model file not found, nothing to delete');
    }
  }

  /// Dispose model and free memory
  Future<void> dispose() async {
    debugPrint('🚀 [LocalLLMService] dispose called');
    debugPrint('   - isInitialized: $_isInitialized');
    debugPrint('   - contextPointer: $_currentContextPointer');
    
    if (_isInitialized && _currentContextPointer != null) {
      try {
        debugPrint('⏳ [LocalLLMService] Calling native releaseModel()...');
        await _channel.invokeMethod('releaseModel', {
          'contextPointer': _currentContextPointer,
        });
        debugPrint('✅ [LocalLLMService] SUCCESS: Model released');
      } catch (e) {
        debugPrint('❌ [LocalLLMService] FAILED: Error releasing model');
        debugPrint('   - Error: $e');
      }
    } else {
      debugPrint('⚠️ [LocalLLMService] Nothing to dispose');
    }
    
    _isInitialized = false;
    _currentModel = null;
    _currentContextPointer = null;
    debugPrint('   - State reset: isInitialized=$_isInitialized');
  }
}

