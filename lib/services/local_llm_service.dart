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
    // === RECOMMENDED: Best balance of quality and size ===
    // Qwen2.5-1.5B - Excellent instruction following, great for summarization
    const ModelConfig(
      key: 'qwen2.5-1.5b-q4',
      name: 'Qwen2.5-1.5B-Q4 (Recommended)',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      sizeBytes: 1100 * 1024 * 1024, // ~1.1GB
      format: 'GGUF',
      promptFormat: 'chatml',
      recommended: true,
    ),

    // === HIGH QUALITY: Larger but better results ===
    // Qwen2.5-3B - Best quality for complex tasks
    const ModelConfig(
      key: 'qwen2.5-3b-q4',
      name: 'Qwen2.5-3B-Q4 (Best Quality)',
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
      sizeBytes: 2100 * 1024 * 1024, // ~2.1GB
      format: 'GGUF',
      promptFormat: 'chatml',
      recommended: false,
    ),
    // Gemma 2 2B - Google's latest, excellent at following instructions
    const ModelConfig(
      key: 'gemma2-2b-q4',
      name: 'Gemma-2-2B-Q4 (High Quality)',
      downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      sizeBytes: 1700 * 1024 * 1024, // ~1.7GB
      format: 'GGUF',
      promptFormat: 'gemma',
      recommended: false,
    ),
    // Llama 3.2 1B - Meta's latest small model
    const ModelConfig(
      key: 'llama3.2-1b-q4',
      name: 'Llama-3.2-1B-Q4 (Fast)',
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      sizeBytes: 820 * 1024 * 1024, // ~820MB
      format: 'GGUF',
      promptFormat: 'llama3',
      recommended: false,
    ),
    // Llama 3.2 3B - Best Llama for mobile
    const ModelConfig(
      key: 'llama3.2-3b-q4',
      name: 'Llama-3.2-3B-Q4 (Powerful)',
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      sizeBytes: 2100 * 1024 * 1024, // ~2.1GB
      format: 'GGUF',
      promptFormat: 'llama3',
      recommended: false,
    ),

    // === LIGHTWEIGHT: For devices with limited storage ===
    // SmolLM-135M - Ultra small, basic quality
    // const ModelConfig(
    //   key: 'smollm-135m-q4',
    //   name: 'SmolLM-135M-Q4 (Tiny)',
    //   downloadUrl: 'https://huggingface.co/QuantFactory/SmolLM-135M-Instruct-GGUF/resolve/5af1cd23df57f5ec9e1495e05ada134502897076/SmolLM-135M-Instruct.Q4_K_M.gguf',
    //   sizeBytes: 105 * 1024 * 1024, // ~105MB
    //   format: 'GGUF',
    //   promptFormat: 'chatml',
    //   recommended: false,
    // ),
    // Phi-2 - Good balance, older model
    const ModelConfig(
      key: 'phi-2-q4',
      name: 'Phi-2-Q4 (Legacy)',
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
        String text = result['text'] as String;
        debugPrint('✅ [LocalLLMService] SUCCESS: Text generated');
        debugPrint('   - Generated length: ${text.length} chars');
        debugPrint('   - Raw output: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
        
        // Post-process keywords if that's the summary type
        if (summaryType == 'keywords') {
          text = _postProcessKeywords(text);
          debugPrint('   - After post-processing: $text');
        }
        
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
      case 'gemma':
        return _buildGemmaPrompt(transcript, summaryType);
      case 'llama3':
        return _buildLlama3Prompt(transcript, summaryType);
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
        instruction = 'Extract keywords. Output: comma-separated single words only. No sentences. No explanations';
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
        instruction = 'Extract keywords:';
        systemPrompt = '''You are a keyword extraction engine.

Task: Extract important keywords from the text.

Rules:
- Output ONLY keywords
- Single words only
- No sentences
- No explanations
- No numbering
- No symbols
- No punctuation except commas
- No stop words
- No names unless meaningful
- Use words exactly as they appear in the text

Output format: comma-separated list''';
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

  /// Build Gemma format prompt
  String _buildGemmaPrompt(String transcript, String summaryType) {
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
        instruction = 'Extract keywords. Output only single words separated by commas. No sentences. No explanations';
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

    return '''<start_of_turn>user
$instruction

$transcript<end_of_turn>
<start_of_turn>model
''';
  }

  /// Build Llama 3 format prompt
  String _buildLlama3Prompt(String transcript, String summaryType) {
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
        systemPrompt = 'You extract keywords as single words only. Output comma-separated single words. No sentences. No explanations.';
        break;
      case 'topics':
        instruction = 'Identify the main topics discussed in this transcript. For each topic, provide a one-sentence description:';
        systemPrompt = 'You are an expert at identifying and categorizing discussion topics.';
        break;
      case 'action_items':
        instruction = 'Extract any action items, tasks, decisions, or next steps mentioned in this transcript. List each as a bullet point:';
        systemPrompt = 'You are an expert at identifying actionable items and tasks from conversations.';
        break;
      default:
        instruction = 'Summarize this transcript:';
    }

    return '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>

$systemPrompt<|eot_id|><|start_header_id|>user<|end_header_id|>

$instruction

$transcript<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';
  }

  /// Post-process keywords from LLM output
  /// Cleans up the raw LLM output to ensure proper keyword format
  String _postProcessKeywords(String rawOutput) {
    debugPrint('🔧 [LocalLLMService] Post-processing keywords...');
    debugPrint('   - Raw input: $rawOutput');

    // Stop words to filter out (expanded list)
    const stopWords = {
      // Common stop words
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare',
      'ought', 'used', 'to', 'of', 'in', 'for', 'on', 'with', 'at', 'by',
      'from', 'as', 'into', 'through', 'during', 'before', 'after', 'above',
      'below', 'between', 'under', 'again', 'further', 'then', 'once',
      'here', 'there', 'when', 'where', 'why', 'how', 'all', 'each', 'few',
      'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only',
      'own', 'same', 'so', 'than', 'too', 'very', 'just', 'and', 'but',
      'if', 'or', 'because', 'until', 'while', 'although', 'though',
      'this', 'that', 'these', 'those', 'i', 'me', 'my', 'myself', 'we',
      'our', 'ours', 'ourselves', 'you', 'your', 'yours', 'yourself',
      'he', 'him', 'his', 'himself', 'she', 'her', 'hers', 'herself',
      'it', 'its', 'itself', 'they', 'them', 'their', 'theirs', 'themselves',
      'what', 'which', 'who', 'whom', 'whose', 'am', 'about', 'also',
      // LLM meta-words to filter
      'dont', 'however', 'given', 'shows', 'therefore', 'statement',
      'sentiment', 'primary', 'meaning', 'conveyed', 'text', 'input',
      'output', 'extract', 'keywords', 'context', 'access', 'following',
      'based', 'example', 'note', 'please', 'list', 'word',
      'words', 'keyword', 'sorry', 'cannot', 'provide', 'information',
      'assistant', 'user', 'system', 'ive', 'youre', 'theyre',
      'weve', 'hes', 'shes', 'lets', 'thats', 'whats', 'heres',
    };

    // Step 1: Clean up the raw output - remove LLM explanatory text
    String cleaned = rawOutput
        // Remove common LLM explanation patterns
        .replaceAll(RegExp(r"I don't have access.*?However,?\s*", caseSensitive: false), '')
        .replaceAll(RegExp(r'Therefore.*?\.', caseSensitive: false), '')
        .replaceAll(RegExp(r'The (?:given|input|following) text.*?(?:is|shows|contains)', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?:Here are|Keywords?:?|Output:?)\s*', caseSensitive: false), '')
        .replaceAll('\n', ', ')
        .replaceAll('\r', ', ')
        .replaceAll('`', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll(':', ' ')
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\d+\.\s*'), '')
        .replaceAll(RegExp(r'^-\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Step 2: Split into words and filter
    List<String> words = cleaned
        .split(RegExp(r'[,\s]+'))
        .map((w) => w.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), ''))
        .where((w) => w.isNotEmpty)
        .where((w) => w.length > 2)  // Skip very short words
        .where((w) => w.length < 20)  // Skip very long words (likely errors)
        .where((w) => !stopWords.contains(w))
        .where((w) => !RegExp(r'^[0-9]+$').hasMatch(w))
        .toList();

    // Step 3: Remove duplicates while preserving order
    final seen = <String>{};
    words = words.where((w) => seen.add(w)).toList();

    // Step 4: Limit to top 15 keywords max
    if (words.length > 15) {
      words = words.sublist(0, 15);
    }

    // Step 5: Format as comma-separated list
    final result = words.join(', ');

    debugPrint('   - Extracted ${words.length} keywords');
    debugPrint('   - Result: $result');

    return result.isEmpty ? 'No keywords extracted' : result;
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

