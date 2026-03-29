class HistoryItem {
  const HistoryItem({
    required this.source,
    required this.language,
    required this.summary,
    required this.bulletPoints,
    required this.transcriptPreview,
    required this.createdAt,
    required this.serviceLabel,
  });

  final String source;
  final String language;
  final String summary;
  final List<String> bulletPoints;
  final String transcriptPreview;
  final DateTime createdAt;
  final String serviceLabel;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      source: (json['source'] as String?) ?? 'Unknown source',
      language: (json['language'] as String?) ?? 'Hindi',
      summary: (json['summary'] as String?) ?? '',
      bulletPoints: ((json['bulletPoints'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      transcriptPreview: (json['transcriptPreview'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      serviceLabel: (json['serviceLabel'] as String?) ?? 'Mock',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source': source,
      'language': language,
      'summary': summary,
      'bulletPoints': bulletPoints,
      'transcriptPreview': transcriptPreview,
      'createdAt': createdAt.toIso8601String(),
      'serviceLabel': serviceLabel,
    };
  }
}
