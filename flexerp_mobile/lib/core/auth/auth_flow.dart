import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppAuthStep {
  bootstrapping,
  serverDiscovery,
  login,
  authenticated,
}

/// Which top-level screen the app should render.
enum AuthScreen { splash, server, login, shell }

/// Pure screen resolution for the auth state machine.
///
/// * `authenticated` without a user (logout / session lost) falls back to
///   the login screen — never to the shell.
/// * `login` / `serverDiscovery` are shown regardless of whether a user
///   object exists, so the live server → login transition always works.
AuthScreen resolveAuthScreen(AppAuthStep step, {required bool hasUser}) {
  switch (step) {
    case AppAuthStep.bootstrapping:
      return AuthScreen.splash;
    case AppAuthStep.serverDiscovery:
      return AuthScreen.server;
    case AppAuthStep.login:
      return AuthScreen.login;
    case AppAuthStep.authenticated:
      return hasUser ? AuthScreen.shell : AuthScreen.login;
  }
}

/// server → login → shell state machine (plus demo shortcut and restore).
class AuthFlowNotifier extends Notifier<AppAuthStep> {
  @override
  AppAuthStep build() => AppAuthStep.bootstrapping;

  /// Result of secure session restore at startup.
  void restoreFinished({required bool restored}) {
    state = restored ? AppAuthStep.authenticated : AppAuthStep.serverDiscovery;
  }

  void proceedToLogin() => state = AppAuthStep.login;

  void backToServer() => state = AppAuthStep.serverDiscovery;

  void loginSucceeded() => state = AppAuthStep.authenticated;

  void demoReady() => state = AppAuthStep.authenticated;

  /// After logout live users return to the login screen (server is kept);
  /// demo users return to server discovery where the demo sandbox lives.
  void loggedOut({bool wasDemo = false}) {
    state = wasDemo ? AppAuthStep.serverDiscovery : AppAuthStep.login;
  }
}

final authFlowProvider =
    NotifierProvider<AuthFlowNotifier, AppAuthStep>(AuthFlowNotifier.new);
