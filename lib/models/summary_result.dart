class SummaryResult {
  const SummaryResult({
    required this.transcript,
    required this.shortSummary,
    required this.bulletPoints,
    required this.detailedSummary,
    required this.requestedMode,
    required this.language,
    required this.sourceLabel,
    required this.serviceLabel,
    required this.createdAt,
  });

  final String transcript;
  final String shortSummary;
  final List<String> bulletPoints;
  final String detailedSummary;
  final String requestedMode;
  final String language;
  final String sourceLabel;
  final String serviceLabel;
  final DateTime createdAt;
}
