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
  final FocusNode _transcriptFocusNode = FocusNode();

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
    _transcriptController.text = "Hello daddy my favorite thing today is eating an icecream with you. i'm happy that I got to play soccer with you and I'm glad that I score 4 goal";
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

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Model',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${models.length} models available',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              // Scrollable model list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    final isSelected = _selectedModel?.key == model.key;
                    
                    return FutureBuilder<bool>(
                      future: _llmService.isModelDownloaded(model.key),
                      builder: (context, snapshot) {
                        final isDownloaded = snapshot.data ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected 
                              ? Colors.blue.shade50 
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? const BorderSide(color: Colors.blue, width: 2)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            leading: _buildModelLeadingIcon(isDownloaded, isSelected),
                            title: Text(
                              model.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.blue.shade700 : null,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  '${model.sizeFormatted} • ${model.format}',
                                  style: TextStyle(
                                    color: model.recommended ? Colors.blue : Colors.grey,
                                  ),
                                ),
                                if (isDownloaded) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Downloaded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: _buildModelTrailing(model, isSelected),
                            onTap: () => Navigator.pop(context, model.key),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build leading icon for model list item
  Widget _buildModelLeadingIcon(bool isDownloaded, bool isSelected) {
    if (isSelected) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 24,
        ),
      );
    } else if (isDownloaded) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.download_done,
          color: Colors.green.shade700,
          size: 24,
        ),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.cloud_download_outlined,
          color: Colors.grey.shade600,
          size: 24,
        ),
      );
    }
  }

  /// Build trailing widget for model list item
  Widget? _buildModelTrailing(ModelConfig model, bool isSelected) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Active',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (model.recommended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Recommended',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return null;
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

  /// Build a chip for selecting analysis type
  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _summaryType == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _summaryType = value;
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Get action button label based on selected type
  String _getActionLabel() {
    switch (_summaryType) {
      case 'keywords':
        return 'Extract Keywords';
      case 'topics':
        return 'Extract Topics';
      case 'action_items':
        return 'Extract Actions';
      default:
        return 'Summarize';
    }
  }

  /// Get action button icon based on selected type
  IconData _getActionIcon() {
    switch (_summaryType) {
      case 'keywords':
        return Icons.label_important;
      case 'topics':
        return Icons.topic;
      case 'action_items':
        return Icons.task_alt;
      default:
        return Icons.summarize;
    }
  }

  /// Get output section title based on selected type
  String _getOutputTitle() {
    switch (_summaryType) {
      case 'keywords':
        return 'Keywords';
      case 'topics':
        return 'Topics';
      case 'action_items':
        return 'Action Items';
      case 'bullet_points':
        return 'Key Points';
      case 'detailed':
        return 'Detailed Summary';
      default:
        return 'Summary';
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
    _transcriptFocusNode.dispose();
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
                      focusNode: _transcriptFocusNode,
                      maxLines: 10,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () {
                        _transcriptFocusNode.unfocus();
                      },
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
                      'Analysis Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Summarization',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeChip('concise', 'Concise', Icons.short_text),
                        _buildTypeChip('detailed', 'Detailed', Icons.article),
                        _buildTypeChip('bullet_points', 'Bullets', Icons.list),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Extraction',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTypeChip('keywords', 'Keywords', Icons.label_important),
                        _buildTypeChip('topics', 'Topics', Icons.topic),
                        _buildTypeChip('action_items', 'Actions', Icons.task_alt),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Button (Summarize/Extract)
            ElevatedButton.icon(
              onPressed: _isLoading || !_isInitialized ? null : _summarize,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_getActionIcon()),
              label: Text(_isLoading ? 'Processing...' : _getActionLabel()),
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
                          Text(
                            _getOutputTitle(),
                            style: const TextStyle(
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
