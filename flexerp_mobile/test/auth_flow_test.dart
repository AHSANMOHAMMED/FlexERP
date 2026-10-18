import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flexerp_mobile/core/auth/auth_flow.dart';

void main() {
  group('resolveAuthScreen', () {
    test('login step shows login even without a user (live login reachable)', () {
      expect(resolveAuthScreen(AppAuthStep.login, hasUser: false), AuthScreen.login);
    });

    test('authenticated without user falls back to login, never the shell', () {
      expect(resolveAuthScreen(AppAuthStep.authenticated, hasUser: false), AuthScreen.login);
      expect(resolveAuthScreen(AppAuthStep.authenticated, hasUser: true), AuthScreen.shell);
    });

    test('bootstrapping and server discovery', () {
      expect(resolveAuthScreen(AppAuthStep.bootstrapping, hasUser: false), AuthScreen.splash);
      expect(resolveAuthScreen(AppAuthStep.serverDiscovery, hasUser: true), AuthScreen.server);
    });
  });

  group('AuthFlowNotifier', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    AppAuthStep step() => container.read(authFlowProvider);
    AuthFlowNotifier flow() => container.read(authFlowProvider.notifier);

    test('server → login → shell → logout → login → back → server', () {
      expect(step(), AppAuthStep.bootstrapping);
      flow().restoreFinished(restored: false);
      expect(step(), AppAuthStep.serverDiscovery);

      flow().proceedToLogin();
      expect(step(), AppAuthStep.login);
      expect(resolveAuthScreen(step(), hasUser: false), AuthScreen.login);

      flow().loginSucceeded();
      expect(resolveAuthScreen(step(), hasUser: true), AuthScreen.shell);

      flow().loggedOut();
      expect(step(), AppAuthStep.login);
      expect(resolveAuthScreen(step(), hasUser: false), AuthScreen.login);

      flow().backToServer();
      expect(step(), AppAuthStep.serverDiscovery);
    });

    test('session restore goes straight to the shell', () {
      flow().restoreFinished(restored: true);
      expect(resolveAuthScreen(step(), hasUser: true), AuthScreen.shell);
    });

    test('demo logout returns to server discovery', () {
      flow().demoReady();
      expect(step(), AppAuthStep.authenticated);
      flow().loggedOut(wasDemo: true);
      expect(step(), AppAuthStep.serverDiscovery);
    });
  });
}
