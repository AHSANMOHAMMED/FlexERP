import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_flow.dart';
import 'core/theme/flex_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/server_connection_screen.dart';
import 'features/auth/login_screen.dart';
import 'routing/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlexERP UI Error: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF081425),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 16),
              const Text(
                'FlexERP View Error',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const ProviderScope(child: FlexErpApp()));
}

class FlexErpApp extends ConsumerStatefulWidget {
  const FlexErpApp({super.key});

  @override
  ConsumerState<FlexErpApp> createState() => _FlexErpAppState();
}

class _FlexErpAppState extends ConsumerState<FlexErpApp> {
  bool _lastUserWasDemo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    var restored = false;
    try {
      restored = await ref.read(currentUserProvider.notifier).tryRestoreSession();
    } catch (e) {
      debugPrint('FlexERP: session restore crashed: $e');
    }
    if (!mounted) return;
    ref.read(authFlowProvider.notifier).restoreFinished(restored: restored);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final step = ref.watch(authFlowProvider);
    if (user != null) _lastUserWasDemo = user.isDemo;

    return MaterialApp(
      title: 'FlexERP Mobile Suite',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'LK'),
      supportedLocales: const [
        Locale('en', 'LK'),
        Locale('en', 'US'),
      ],
      theme: FlexTheme.darkTheme,
      home: _buildCurrentScreen(resolveAuthScreen(step, hasUser: user != null)),
    );
  }

  Widget _buildCurrentScreen(AuthScreen screen) {
    final flow = ref.read(authFlowProvider.notifier);
    switch (screen) {
      case AuthScreen.splash:
        return const Scaffold(
          backgroundColor: Color(0xFF081425),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF6366F1)),
                SizedBox(height: 16),
                Text('Restoring secure session…', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        );
      case AuthScreen.server:
        return ServerConnectionScreen(
          onProceedToLogin: flow.proceedToLogin,
          onDemoReady: flow.demoReady,
        );
      case AuthScreen.login:
        return LoginScreen(
          onBackToServer: flow.backToServer,
          onLoginSuccess: flow.loginSucceeded,
        );
      case AuthScreen.shell:
        return AppShell(
          onLogout: () => flow.loggedOut(wasDemo: _lastUserWasDemo),
        );
    }
  }
}
