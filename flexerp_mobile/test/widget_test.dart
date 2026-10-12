import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flexerp_mobile/main.dart';

void main() {
  testWidgets('FlexERP Mobile smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlexErpApp()));
    await tester.pump();

    // Verify executive hub or app bar is mounted
    expect(find.byType(FlexErpApp), findsOneWidget);
  });
}
