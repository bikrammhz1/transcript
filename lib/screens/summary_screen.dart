import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_llm_service.dart';
import '../models/model_config.dart';

class TranscriptSummaryScreen extends StatefulWidget {
  const TranscriptSummaryScreen({super.key});

  @override
  State<TranscriptSummaryScreen> createState() =>
      _TranscriptSummaryScreenState();
}

class _TranscriptSummaryScreenState extends State<TranscriptSummaryScreen> {
  final LocalLLMService _llmService = LocalLLMService();
  final TextEditingController _transcriptController = TextEditingController();
  final ScrollController _summaryScrollController = ScrollController();

  String _summary = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  ModelConfig? _selectedModel;
  String _statusMessage = 'Initializing...';
  double _downloadProgress = 0.0;
  String _summaryType = 'concise';
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [SummaryScreen] initState');
    _checkAndInitialize();
  }

  Future<void> _checkAndInitialize() async {
    debugPrint('🔍 [SummaryScreen] _checkAndInitialize');

    // Get last selected model or use recommended
    final lastModelKey = await _llmService.getLastSelectedModel();
    final modelKey = lastModelKey ??
        _llmService.getAvailableModels().firstWhere((m) => m.recommended).key;

    debugPrint('   - Selected model key: $modelKey');

    final isDownloaded = await _llmService.isModelDownloaded(modelKey);
    debugPrint('   - Is downloaded: $isDownloaded');

    if (!isDownloaded) {
      debugPrint('⚠️ [SummaryScreen] Model not downloaded');
      setState(() {
        _statusMessage = 'Model not downloaded. Please download to continue.';
        _isInitialized = false;
      });
      return;
    }

    // Initialize model
    debugPrint('🚀 [SummaryScreen] Starting model initialization...');
    await _initializeModel(modelKey);
  }

  Future<void> _initializeModel(String modelKey) async {
    debugPrint('🚀 [SummaryScreen] _initializeModel: $modelKey');

    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing model...';
      _downloadProgress = 0.0;
    });

    try {
      debugPrint('⏳ [SummaryScreen] Calling _llmService.initialize()...');
      await _llmService.initialize(
        modelKey: modelKey,
        onProgress: (progress, status) {
          debugPrint(
              '📊 [SummaryScreen] Progress: ${(progress * 100).toStringAsFixed(1)}% - $status');
          setState(() {
            _downloadProgress = progress;
            _statusMessage = status;
            _isDownloading = progress < 1.0;
          });
        },
      );

      final model =
          _llmService.getAvailableModels().firstWhere((m) => m.key == modelKey);

      debugPrint('✅ [SummaryScreen] SUCCESS: Model initialized');
      debugPrint('   - Model: ${model.name}');

      setState(() {
        _selectedModel = model;
        _isInitialized = true;
        _isLoading = false;
        _statusMessage = 'Ready to summarize';
      });
    } catch (e) {
      debugPrint('❌ [SummaryScreen] FAILED: Model initialization error');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error: $e');

      setState(() {
        _isLoading = false;
        _isInitialized = false;
        _statusMessage = 'Initialization failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize model: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _checkAndInitialize(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showModelSelector() async {
    final modelKey = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildModelSelector(),
    );

    if (modelKey != null) {
      // Check if model is downloaded
      final isDownloaded = await _llmService.isModelDownloaded(modelKey);

      if (isDownloaded) {
        // Switch to existing model
        await _initializeModel(modelKey);
      } else {
        // Download and initialize new model
        await _downloadAndInitialize(modelKey);
      }
    }
  }

  Future<void> _showDownloadDialog() async {
    final modelKey = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildModelSelector(),
    );

    if (modelKey != null) {
      await _downloadAndInitialize(modelKey);
    }
  }

  Widget _buildModelSelector() {
    final models = _llmService.getAvailableModels();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Model',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...models.map((model) {
            return ListTile(
              title: Text(model.name),
              subtitle: Text(
                '${model.sizeFormatted} • ${model.format}',
                style: TextStyle(
                  color: model.recommended ? Colors.blue : Colors.grey,
                ),
              ),
              trailing: model.recommended
                  ? const Chip(
                      label: Text('Recommended'),
                      backgroundColor: Colors.blue,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : null,
              onTap: () => Navigator.pop(context, model.key),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _downloadAndInitialize(String modelKey) async {
    debugPrint('📥 [SummaryScreen] _downloadAndInitialize: $modelKey');

    setState(() {
      _isDownloading = true;
      _isLoading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Starting download...';
    });

    try {
      debugPrint(
          '⏳ [SummaryScreen] Calling _llmService.initialize() for download...');
      await _llmService.initialize(
        modelKey: modelKey,
        onProgress: (progress, status) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage = status;
            _isDownloading = progress < 1.0;
          });
        },
      );

      final model =
          _llmService.getAvailableModels().firstWhere((m) => m.key == modelKey);

      debugPrint('✅ [SummaryScreen] Download & Init SUCCESS');
      debugPrint('   - Model: ${model.name}');

      setState(() {
        _selectedModel = model;
        _isInitialized = true;
        _isLoading = false;
        _isDownloading = false;
        _statusMessage = 'Model ready';
      });
    } catch (e) {
      debugPrint('❌ [SummaryScreen] FAILED: Download/Init error');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error: $e');

      setState(() {
        _isLoading = false;
        _isDownloading = false;
        _statusMessage = 'Download failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _downloadAndInitialize(modelKey),
            ),
          ),
        );
      }
    }
  }

  Future<void> _summarize() async {
    debugPrint('🚀 [SummaryScreen] _summarize called');

    final transcript = _transcriptController.text.trim();
    debugPrint('   - Transcript length: ${transcript.length} chars');
    debugPrint('   - Summary type: $_summaryType');
    debugPrint('   - isInitialized: $_isInitialized');

    if (transcript.isEmpty) {
      debugPrint('⚠️ [SummaryScreen] Empty transcript');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a transcript')),
      );
      return;
    }

    if (!_isInitialized) {
      debugPrint('⚠️ [SummaryScreen] Model not initialized');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model not initialized')),
      );
      return;
    }

    debugPrint('⏳ [SummaryScreen] Starting summarization...');
    setState(() {
      _isLoading = true;
      _summary = '';
      _statusMessage = 'Generating summary...';
    });

    try {
      debugPrint(
          '⏳ [SummaryScreen] Calling _llmService.summarizeTranscript()...');
      final summary = await _llmService.summarizeTranscript(
        transcript,
        summaryType: _summaryType,
      );

      debugPrint('✅ [SummaryScreen] SUCCESS: Summary generated');
      debugPrint('   - Summary length: ${summary.length} chars');
      debugPrint(
          '   - Preview: ${summary.substring(0, summary.length > 100 ? 100 : summary.length)}...');

      setState(() {
        _summary = summary.trim();
        _isLoading = false;
        _statusMessage = 'Summary generated';
      });

      // Scroll to summary
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_summaryScrollController.hasClients) {
          _summaryScrollController.animateTo(
            _summaryScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ [SummaryScreen] FAILED: Summarization error');
      debugPrint('   - Error type: ${e.runtimeType}');
      debugPrint('   - Error: $e');

      setState(() {
        _isLoading = false;
        _statusMessage = 'Generation failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copySummary() {
    if (_summary.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _summary));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard')),
      );
    }
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _summaryScrollController.dispose();
    _llmService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript Summarizer'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showModelSelector,
            tooltip: 'Select Model',
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _summaryScrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            if (!_isInitialized || _isLoading)
              Card(
                color: _isInitialized
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isInitialized ? Icons.check_circle : Icons.info,
                            color:
                                _isInitialized ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (_isDownloading) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: _downloadProgress),
                        const SizedBox(height: 8),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (!_isInitialized && !_isDownloading) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showDownloadDialog,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Model'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (!_isInitialized) const SizedBox(height: 16),

            // Model Info
            if (_selectedModel != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.model_training),
                  title: Text(_selectedModel!.name),
                  subtitle: Text(
                      '${_selectedModel!.sizeFormatted} • ${_selectedModel!.format}'),
                ),
              ),

            const SizedBox(height: 16),

            // Transcript Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transcript',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transcriptController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: 'Enter or paste your transcript here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Summary Type Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'concise',
                          label: Text('Concise'),
                          icon: Icon(Icons.short_text),
                        ),
                        ButtonSegment(
                          value: 'detailed',
                          label: Text('Detailed'),
                          icon: Icon(Icons.article),
                        ),
                        ButtonSegment(
                          value: 'bullet_points',
                          label: Text('Bullet Points'),
                          icon: Icon(Icons.list),
                        ),
                      ],
                      selected: {_summaryType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _summaryType = newSelection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Summarize Button
            ElevatedButton.icon(
              onPressed: _isLoading || !_isInitialized ? null : _summarize,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.summarize),
              label: Text(_isLoading ? 'Generating...' : 'Summarize'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Summary Output
            if (_summary.isNotEmpty)
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copySummary,
                            tooltip: 'Copy to clipboard',
                          ),
                        ],
                      ),
                      const Divider(),
                      SelectableText(
                        _summary,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isLoading && _summary.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
