import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:summaryapp/models/app_settings.dart';
import 'package:summaryapp/services/summary_service.dart';

void main() {
  Future<TranscriptionResult> transcribe(SummaryService service) {
    return service.transcribeAudio(
      filename: 'note.wav',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      language: 'Gujarati',
      settings: AppSettings.defaults(deviceId: 'test-device'),
    );
  }

  test(
    'uploads audio through the client and accepts completed transcription',
    () async {
      late http.Request sentRequest;
      final SummaryService service = SummaryService(
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'status': 'completed',
              'filename': 'note.wav',
              'transcript': 'કાલે મીટિંગ છે.',
              'language': 'Gujarati',
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
      );
      final TranscriptionResult result = await transcribe(service);
      expect(sentRequest.url.path, '/transcribe');
      expect(
        sentRequest.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(sentRequest.headers.containsKey('x-goog-api-key'), isFalse);
      expect(sentRequest.body, contains('note.wav'));
      expect(sentRequest.body, contains('Gujarati'));
      expect(result.transcript, 'કાલે મીટિંગ છે.');
      expect(result.status, 'completed');
    },
  );

  for (final String status in <String>[
    'placeholder_transcript',
    'processing',
    'failed',
  ]) {
    test('rejects a $status response', () async {
      final SummaryService service = SummaryService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'status': status,
              'transcript': 'Placeholder or incomplete text',
            }),
            200,
          );
        }),
      );
      await expectLater(
        transcribe(service),
        throwsA(isA<SummaryServiceException>()),
      );
    });
  }

  test('shows the backend quota error', () async {
    const String message =
        "Gemini's usage limit was reached. Wait and try again.";
    final SummaryService service = SummaryService(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'detail': message}),
          429,
        );
      }),
    );
    await expectLater(
      transcribe(service),
      throwsA(
        isA<SummaryServiceException>().having(
          (error) => error.message,
          'message',
          message,
        ),
      ),
    );
  });

  test('handles a non-JSON proxy error', () async {
    final SummaryService service = SummaryService(
      client: MockClient((_) async {
        return http.Response('<html>Bad gateway</html>', 502);
      }),
    );
    await expectLater(
      transcribe(service),
      throwsA(
        isA<SummaryServiceException>().having(
          (error) => error.message,
          'message',
          contains('502'),
        ),
      ),
    );
  });

  test('rejects an empty completed transcript', () async {
    final SummaryService service = SummaryService(
      client: MockClient((_) async {
        return http.Response('{"status":"completed","transcript":"  "}', 200);
      }),
    );
    await expectLater(
      transcribe(service),
      throwsA(isA<SummaryServiceException>()),
    );
  });
}
