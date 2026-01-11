/// Model configuration class for LLM models
class ModelConfig {
  final String key;
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String format;
  final String promptFormat;
  final bool recommended;
  final int contextSize;
  final int defaultThreads;

  const ModelConfig({
    required this.key,
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.format,
    required this.promptFormat,
    required this.recommended,
    this.contextSize = 2048,
    this.defaultThreads = 2,
  });

  /// Get size in MB
  double get sizeMB => sizeBytes / (1024 * 1024);

  /// Get formatted size string
  String get sizeFormatted {
    if (sizeMB < 1024) {
      return '${sizeMB.toStringAsFixed(0)} MB';
    }
    return '${(sizeMB / 1024).toStringAsFixed(2)} GB';
  }

  /// Get filename from download URL
  String get filename {
    final uri = Uri.parse(downloadUrl);
    return uri.pathSegments.last;
  }

  @override
  String toString() => name;
}



