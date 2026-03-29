import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:summaryapp/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the summary app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Voice notes into fast, clean summaries.'),
      findsOneWidget,
    );
    expect(find.text('Generate summary'), findsOneWidget);
    expect(find.text('Client status'), findsOneWidget);
  });
}
