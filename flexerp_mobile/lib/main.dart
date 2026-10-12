import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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


enum AppAuthStep {
  serverDiscovery,
  login,
  authenticated,
}

class FlexErpApp extends ConsumerStatefulWidget {
  const FlexErpApp({super.key});

  @override
  ConsumerState<FlexErpApp> createState() => _FlexErpAppState();
}

class _FlexErpAppState extends ConsumerState<FlexErpApp> {
  AppAuthStep _authStep = AppAuthStep.authenticated; // Start authenticated in Sri Lanka sandbox by default

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return MaterialApp(
      title: 'FlexERP Mobile Suite',
      debugShowCheckedModeBanner: false,
      theme: FlexTheme.darkTheme,
      home: _buildCurrentScreen(user != null),
    );
  }

  Widget _buildCurrentScreen(bool hasUser) {
    if (!hasUser || _authStep == AppAuthStep.serverDiscovery) {
      return ServerConnectionScreen(
        onProceedToLogin: () {
          setState(() => _authStep = AppAuthStep.login);
        },
      );
    }

    if (_authStep == AppAuthStep.login) {
      return LoginScreen(
        onBackToServer: () {
          setState(() => _authStep = AppAuthStep.serverDiscovery);
        },
        onLoginSuccess: () {
          setState(() => _authStep = AppAuthStep.authenticated);
        },
      );
    }

    return AppShell(
      onLogout: () {
        setState(() => _authStep = AppAuthStep.login);
      },
    );
  }
}
