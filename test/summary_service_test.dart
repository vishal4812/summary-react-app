import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:summaryapp/models/app_settings.dart';
import 'package:summaryapp/models/summary_result.dart';
import 'package:summaryapp/services/summary_service.dart';

void main() {
  const Map<String, dynamic> content = <String, dynamic>{
    'success': true,
    'summary': 'કાલે મીટિંગ છે.',
    'bulletPoints': <String>['મીટિંગ સવારે 10 વાગ્યે છે.'],
    'detailedSummary': 'કાલે સવારે 10 વાગ્યે મીટિંગ યોજાશે.',
    'serviceMode': 'gemini',
  };

  Future<SummaryResult> summarize(
    SummaryService service, {
    String mode = 'Short bullets',
    AppSettings? settings,
  }) => service.summarize(
    transcript: 'કાલે સવારે 10 વાગ્યે મીટિંગ છે.',
    language: 'Gujarati',
    mode: mode,
    sourceLabel: 'Pasted text',
    settings: settings ?? AppSettings.defaults(deviceId: 'test-device'),
  );

  for (final MapEntry<String, String> mode in <String, String>{
    'Short only': 'short',
    'Detailed Pro mode': 'detailed',
    'Short bullets': 'short_bullets',
  }.entries) {
    test(
      'sends ${mode.value} and reads a native Gujarati Gemini summary',
      () async {
        late http.Request sentRequest;
        final SummaryService service = SummaryService(
          client: MockClient((request) async {
            sentRequest = request;
            return http.Response(
              jsonEncode(content),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        );
        final SummaryResult result = await summarize(service, mode: mode.key);
        expect(sentRequest.url.path, '/summarize');
        expect(sentRequest.headers.containsKey('x-goog-api-key'), isFalse);
        expect(jsonDecode(sentRequest.body)['mode'], mode.value);
        expect(jsonDecode(sentRequest.body)['language'], 'Gujarati');
        expect(result.shortSummary, content['summary']);
        expect(result.bulletPoints, content['bulletPoints']);
        expect(result.serviceLabel, 'Gemini');
      },
    );
  }

  test('shows actionable backend quota errors', () async {
    const String message =
        "Gemini's usage limit was reached. Wait and try again.";
    final SummaryService service = SummaryService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode(<String, String>{'detail': message}), 429),
      ),
    );
    await expectLater(
      summarize(service),
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
      client: MockClient(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
      ),
    );
    await expectLater(
      summarize(service),
      throwsA(
        isA<SummaryServiceException>().having(
          (error) => error.message,
          'message',
          contains('502'),
        ),
      ),
    );
  });

  for (final Map<String, dynamic> invalid in <Map<String, dynamic>>[
    <String, dynamic>{...content, 'success': false},
    <String, dynamic>{...content, 'summary': '  '},
    <String, dynamic>{...content, 'bulletPoints': <String>[]},
    <String, dynamic>{
      ...content,
      'bulletPoints': <int>[123],
    },
    <String, dynamic>{...content, 'detailedSummary': ''},
  ]) {
    test('rejects invalid summary content $invalid', () async {
      final SummaryService service = SummaryService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(invalid),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        summarize(service),
        throwsA(isA<SummaryServiceException>()),
      );
    });
  }

  testWidgets('summary requests time out with an actionable message', (
    tester,
  ) async {
    final Completer<http.Response> pending = Completer<http.Response>();
    final SummaryService service = SummaryService(
      client: MockClient((_) => pending.future),
    );
    final Future<void> expectation = expectLater(
      summarize(service),
      throwsA(
        isA<SummaryServiceException>().having(
          (error) => error.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 2));
    await expectation;
    pending.complete(http.Response('{}', 200));
    await tester.pump();
  });

  test('a network failure does not return a mock result', () async {
    final SummaryService service = SummaryService(
      client: MockClient((_) async => throw http.ClientException('Offline')),
    );
    await expectLater(
      summarize(service),
      throwsA(isA<SummaryServiceException>()),
    );
  });

  test('a missing URL never silently returns a mock summary', () async {
    final SummaryService service = SummaryService(
      client: MockClient((_) async => throw StateError('Must not send')),
    );
    final AppSettings settings = AppSettings.defaults(
      deviceId: 'test-device',
    ).copyWith(backendBaseUrl: '');
    await expectLater(
      summarize(service, settings: settings),
      throwsA(isA<SummaryServiceException>()),
    );
  });

  test('keeps mock mode available when explicitly selected', () async {
    final SummaryService service = SummaryService(
      client: MockClient((_) async => throw StateError('Must not send')),
    );
    final AppSettings settings = AppSettings.defaults(
      deviceId: 'test-device',
    ).copyWith(useMockService: true);
    final SummaryResult result = await summarize(service, settings: settings);
    expect(result.serviceLabel, 'Mock');
  });
}
