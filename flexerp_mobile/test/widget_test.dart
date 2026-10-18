import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flexerp_mobile/features/auth/login_screen.dart';
import 'package:flexerp_mobile/features/auth/server_connection_screen.dart';
import 'package:flexerp_mobile/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('boots to server discovery when no session is stored', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FlexErpApp()));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FlexErpApp), findsOneWidget);
    expect(find.byType(ServerConnectionScreen), findsOneWidget);
  });

  testWidgets('live flow: server screen proceeds to the login screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: FlexErpApp()));
    await tester.pump();
    await tester.pumpAndSettle();

    final proceed = find.text('Proceed to Authentication');
    await tester.ensureVisible(proceed);
    await tester.tap(proceed);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ServerConnectionScreen), findsNothing);

    // Credentials are not prefilled.
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.take(2).every((f) => (f.controller?.text ?? '').isEmpty), isTrue);

    // Back returns to server discovery.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ServerConnectionScreen), findsOneWidget);
  });
}
