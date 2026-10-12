import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/auth_user.dart';

class ServerConnectionScreen extends ConsumerStatefulWidget {
  final VoidCallback onProceedToLogin;

  const ServerConnectionScreen({super.key, required this.onProceedToLogin});

  @override
  ConsumerState<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends ConsumerState<ServerConnectionScreen> {
  late final TextEditingController _serverUrlController;
  bool _isPinging = false;
  bool _pingSuccess = false;
  int? _latencyMs;
  String? _serverVersion;
  String? _errorMessage;
  List<String> _databases = ['flexerp_production_lk', 'flexcorp_demo_db'];
  String _selectedDatabase = 'flexerp_production_lk';
  bool _enforceHttps = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(serverConfigProvider);
    _serverUrlController = TextEditingController(text: config.serverUrl);
    _selectedDatabase = config.database;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _pingServer() async {
    final rawUrl = _serverUrlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isPinging = true;
      _errorMessage = null;
    });

    final client = OdooClient(baseUrl: rawUrl);

    try {
      final pingResult = await client.ping();
      final dbList = await client.listDatabases();

      if (mounted) {
        setState(() {
          _isPinging = false;
          _pingSuccess = true;
          _latencyMs = pingResult['latencyMs'] as int?;
          _serverVersion = pingResult['serverVersion'] as String?;
          if (dbList.isNotEmpty) {
            _databases = dbList;
            if (!_databases.contains(_selectedDatabase)) {
              _selectedDatabase = _databases.first;
            }
          }
        });

        ref.read(serverConfigProvider.notifier).updateConfig(
          serverUrl: rawUrl,
          database: _selectedDatabase,
          isConnected: true,
          latencyMs: _latencyMs,
          serverVersion: _serverVersion,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPinging = false;
          _pingSuccess = false;
          _errorMessage = e is OdooException ? e.message : e.toString();
        });

        ref.read(serverConfigProvider.notifier).setConnected(false, error: _errorMessage);
      }
    }
  }

  void _proceed() {
    final rawUrl = _serverUrlController.text.trim();
    ref.read(serverConfigProvider.notifier).updateConfig(
      serverUrl: rawUrl.isNotEmpty ? rawUrl : 'http://localhost:8069',
      database: _selectedDatabase,
      isConnected: _pingSuccess,
      latencyMs: _latencyMs,
      serverVersion: _serverVersion,
    );
    widget.onProceedToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // FlexERP Geometric Logo & Header
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: FlexColors.surfaceRaisedDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: FlexColors.primary.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: FlexColors.primary.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.hub, size: 36, color: FlexColors.primaryLight),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('FlexERP Mobile Suite', style: FlexTypography.headlineXl),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Odoo JSON-RPC 2.0 Enterprise Endpoint',
                  style: FlexTypography.bodyMd.copyWith(color: FlexColors.textSecondaryDark),
                ),
              ),
              const SizedBox(height: 24),

              // Server URL Card
              FlexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SERVER INSTANCE URL', style: FlexTypography.labelSm),
                        if (_pingSuccess && _latencyMs != null)
                          FlexBadge(
                            text: 'Online: ${_latencyMs}ms',
                            variant: FlexBadgeVariant.success,
                            icon: Icons.check_circle_outline,
                          )
                        else if (_errorMessage != null)
                          const FlexBadge(
                            text: 'UNREACHABLE',
                            variant: FlexBadgeVariant.danger,
                            icon: Icons.error_outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverUrlController,
                      style: FlexTypography.bodyMd,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.link, color: FlexColors.primaryLight, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _serverUrlController.clear(),
                        ),
                        hintText: 'e.g. http://localhost:8069 or https://erp.domain.lk',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ActionChip(
                          label: const Text('Local (8069)', style: TextStyle(fontSize: 11)),
                          backgroundColor: FlexColors.surfaceRaisedDark,
                          onPressed: () {
                            setState(() => _serverUrlController.text = 'http://localhost:8069');
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('127.0.0.1:8069', style: TextStyle(fontSize: 11)),
                          backgroundColor: FlexColors.surfaceRaisedDark,
                          onPressed: () {
                            setState(() => _serverUrlController.text = 'http://127.0.0.1:8069');
                          },
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          label: const Text('Cloud Demo', style: TextStyle(fontSize: 11)),
                          backgroundColor: FlexColors.surfaceRaisedDark,
                          onPressed: () {
                            setState(() => _serverUrlController.text = 'https://erp.flexcorp.lk');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FlexButton(
                      label: _isPinging ? 'Pinging Server...' : 'Test Server Connection',
                      icon: Icons.network_ping,
                      variant: FlexButtonVariant.secondary,
                      isLoading: _isPinging,
                      onPressed: _pingServer,
                    ),

                    if (_serverVersion != null) ...[
                      const SizedBox(height: 10),
                      Text('Instance Version: $_serverVersion', style: FlexTypography.bodySm.copyWith(color: FlexColors.success)),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FlexColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: FlexColors.danger.withOpacity(0.4)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: FlexTypography.bodySm.copyWith(color: FlexColors.dangerLight),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Database Selector Card
              FlexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TARGET DATABASE', style: FlexTypography.labelSm),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: FlexColors.surfaceRaisedDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FlexColors.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _databases.contains(_selectedDatabase) ? _selectedDatabase : _databases.first,
                          isExpanded: true,
                          dropdownColor: FlexColors.surfaceRaisedDark,
                          style: FlexTypography.bodyMd,
                          icon: const Icon(Icons.keyboard_arrow_down, color: FlexColors.textSecondaryDark),
                          items: _databases.map((db) {
                            return DropdownMenuItem<String>(
                              value: db,
                              child: Row(
                                children: [
                                  const Icon(Icons.storage_outlined, size: 18, color: FlexColors.primaryLight),
                                  const SizedBox(width: 10),
                                  Text(db, style: FlexTypography.bodyMd),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDatabase = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // SSL Enforcement
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, size: 18, color: FlexColors.success),
                            const SizedBox(width: 8),
                            Text('Enforce HTTPS Only', style: FlexTypography.bodySm),
                          ],
                        ),
                        Switch(
                          value: _enforceHttps,
                          activeColor: FlexColors.primary,
                          onChanged: (val) => setState(() => _enforceHttps = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action
              FlexButton(
                label: 'Proceed to Authentication',
                icon: Icons.arrow_forward,
                variant: FlexButtonVariant.primary,
                height: 50,
                onPressed: _proceed,
              ),
              const SizedBox(height: 16),

              // Sandbox Demo Shortcut
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.play_circle_outline, color: FlexColors.info, size: 18),
                  label: Text(
                    'Instant Sri Lanka Offline Sandbox',
                    style: FlexTypography.labelMd.copyWith(color: FlexColors.info),
                  ),
                  onPressed: () {
                    ref.read(currentUserProvider.notifier).switchRole(UserRole.superAdmin);
                    _proceed();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
