import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_settings.dart';
import '../models/summary_result.dart';

class SummaryServiceException implements Exception {
  const SummaryServiceException(this.message);

  final String message;
}

class SummaryService {
  SummaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SummaryResult> summarize({
    required String transcript,
    required String language,
    required String mode,
    required String sourceLabel,
    required AppSettings settings,
  }) async {
    if (settings.useMockService || settings.backendBaseUrl.trim().isEmpty) {
      return _buildMockSummary(
        transcript: transcript,
        language: language,
        mode: mode,
        sourceLabel: sourceLabel,
      );
    }

    final Uri uri = Uri.parse(
      settings.backendBaseUrl.trim(),
    ).resolve('/summarize');
    http.Response response;

    try {
      response = await _client.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          'text': transcript,
          'language': language,
          'mode': _serializeMode(mode),
        }),
      );
    } catch (_) {
      throw const SummaryServiceException(
        'Could not reach the backend. Check the API URL or switch mock mode back on.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SummaryServiceException(
        'Backend responded with ${response.statusCode}. Expected a working `/summarize` endpoint.',
      );
    }

    try {
      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;

      final String shortSummary =
          (payload['summary'] as String?) ??
          (payload['shortSummary'] as String?) ??
          '';
      if (shortSummary.isEmpty) {
        throw const FormatException('Missing summary');
      }

      final List<String> bulletPoints =
          ((payload['bulletPoints'] as List<dynamic>?) ?? <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList();

      final String detailedSummary =
          (payload['detailedSummary'] as String?) ??
          _buildDetailedSummary(shortSummary, bulletPoints);

      return SummaryResult(
        transcript: transcript,
        shortSummary: shortSummary,
        bulletPoints: bulletPoints,
        detailedSummary: detailedSummary,
        language: language,
        sourceLabel: sourceLabel,
        serviceLabel: 'Backend',
        createdAt: DateTime.now(),
      );
    } catch (_) {
      throw const SummaryServiceException(
        'The backend response shape is invalid. Expected `summary` and optional `bulletPoints`.',
      );
    }
  }

  SummaryResult _buildMockSummary({
    required String transcript,
    required String language,
    required String mode,
    required String sourceLabel,
  }) {
    final List<String> sentences = transcript
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();

    final List<String> clauses = transcript
        .split(RegExp(r'[.!?]'))
        .expand((String sentence) => sentence.split(','))
        .map((String item) => item.trim())
        .where((String item) => item.length > 8)
        .toList();

    final String firstSentence = sentences.isNotEmpty
        ? sentences.first
        : transcript;
    final String secondSentence = sentences.length > 1 ? sentences[1] : '';

    final String shortSummary = switch (language) {
      'Gujarati' =>
        'મૂળ મુદ્દો: ${_compress(firstSentence, 88)}${secondSentence.isNotEmpty ? ' ${_compress(secondSentence, 64)}' : ''}',
      'English' =>
        'Core update: ${_compress(firstSentence, 88)}${secondSentence.isNotEmpty ? ' ${_compress(secondSentence, 64)}' : ''}',
      _ =>
        'Core update: ${_compress(firstSentence, 88)}${secondSentence.isNotEmpty ? ' ${_compress(secondSentence, 64)}' : ''}',
    };

    final List<String> bulletPoints = clauses.take(3).map((String clause) {
      final String cleaned = clause[0].toUpperCase() + clause.substring(1);
      return _compress(cleaned, 70);
    }).toList();

    final String detailedSummary = mode == 'Short only'
        ? shortSummary
        : _buildDetailedSummary(shortSummary, bulletPoints);

    return SummaryResult(
      transcript: transcript,
      shortSummary: shortSummary,
      bulletPoints: bulletPoints,
      detailedSummary: detailedSummary,
      language: language,
      sourceLabel: sourceLabel,
      serviceLabel: 'Mock',
      createdAt: DateTime.now(),
    );
  }

  String _serializeMode(String mode) {
    return switch (mode) {
      'Short only' => 'short',
      'Detailed Pro mode' => 'detailed',
      _ => 'short_bullets',
    };
  }

  String _buildDetailedSummary(String shortSummary, List<String> bulletPoints) {
    if (bulletPoints.isEmpty) {
      return shortSummary;
    }
    return '$shortSummary\n\nAction points: ${bulletPoints.join(' • ')}';
  }

  String _compress(String input, int maxLength) {
    if (input.length <= maxLength) {
      return input;
    }
    return '${input.substring(0, maxLength - 1).trimRight()}…';
  }
}
