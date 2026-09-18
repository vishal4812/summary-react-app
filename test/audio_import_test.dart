import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:summaryapp/app/summary_app.dart';
import 'package:summaryapp/services/summary_service.dart';

void main() {
  for (final String scenario in <String>[
    'success',
    'transcription failure',
    'summary failure',
    'cancelled picker',
    'exhausted usage',
  ]) {
    final bool succeeds = scenario == 'success';
    final bool transcribed = succeeds || scenario == 'summary failure';
    testWidgets('audio import: $scenario', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      int summaries = 0;
      int increments = 0;
      int uploads = 0;
      int picks = 0;
      final SummaryService service = SummaryService(
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/health':
              return http.Response('{"status":"ok"}', 200);
            case '/usage/check':
              return http.Response(
                scenario == 'exhausted usage'
                    ? '{"remainingFreeUses":0,"used":2,"limit":2,"isPro":false}'
                    : '{"remainingFreeUses":2,"used":0,"limit":2,"isPro":false}',
                200,
              );
            case '/transcribe':
              uploads++;
              return transcribed
                  ? http.Response(
                      '{"success":true,"status":"completed","transcript":"Please send the design tomorrow.","filename":"note.wav"}',
                      200,
                    )
                  : http.Response(
                      '{"detail":"Gemini usage limit reached."}',
                      429,
                    );
            case '/summarize':
              summaries++;
              expect(
                jsonDecode(request.body)['text'],
                'Please send the design tomorrow.',
              );
              if (scenario == 'summary failure') {
                return http.Response('{"detail":"Summary unavailable"}', 503);
              }
              return http.Response(
                '{"summary":"Send the design tomorrow.","bulletPoints":["Send the design tomorrow."],"detailedSummary":"Send the design tomorrow."}',
                200,
              );
            case '/usage/increment':
              increments++;
              return http.Response(
                '{"remainingFreeUses":1,"used":1,"limit":2,"isPro":false}',
                200,
              );
            default:
              fail('Unexpected endpoint: ${request.url.path}');
          }
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SummaryAppScreen(
            summaryService: service,
            audioFilePicker: () async {
              picks++;
              if (scenario == 'cancelled picker') {
                return null;
              }
              return FilePickerResult(<PlatformFile>[
                PlatformFile(
                  name: 'note.wav',
                  size: 3,
                  bytes: Uint8List.fromList(<int>[1, 2, 3]),
                ),
              ]);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import audio file'));
      await tester.pumpAndSettle();
      expect(picks, scenario == 'exhausted usage' ? 0 : 1);
      expect(
        uploads,
        transcribed || scenario == 'transcription failure' ? 1 : 0,
      );
      expect(summaries, transcribed ? 1 : 0);
      expect(increments, succeeds ? 1 : 0);
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(
        preferences.getStringList('summary_app_history_v1')?.length ?? 0,
        succeeds ? 1 : 0,
      );
      if (transcribed) {
        final TextField transcript = tester.widget<TextField>(
          find.byType(TextField).first,
        );
        expect(transcript.controller!.text, 'Please send the design tomorrow.');
      } else if (scenario == 'transcription failure') {
        expect(find.text('Gemini usage limit reached.'), findsWidgets);
      } else if (scenario == 'cancelled picker') {
        expect(find.text('Import audio file'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('Generate summary'),
                  matching: find.byWidgetPredicate(
                    (widget) => widget is FilledButton,
                  ),
                ),
              )
              .onPressed,
          isNotNull,
        );
      }
    });
  }
}
