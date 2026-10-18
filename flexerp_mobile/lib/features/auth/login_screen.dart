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

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onBackToServer;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onBackToServer,
    required this.onLoginSuccess,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn({bool isDemo = false}) async {
    final serverConfig = ref.read(serverConfigProvider);
    if (!isDemo &&
        (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty)) {
      setState(() => _errorMessage = 'Enter your username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(currentUserProvider.notifier).login(
        serverUrl: serverConfig.serverUrl,
        database: serverConfig.database,
        email: _emailController.text.trim(),
        // Passwords are sent verbatim (leading/trailing spaces are valid).
        password: _passwordController.text,
        isDemo: isDemo,
        enforceHttps: serverConfig.enforceHttps,
      );
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is OdooException ? e.message : e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _quickSelectRole(UserRole role, String email) async {
    setState(() {
      _emailController.text = email;
      _passwordController.text = 'admin123';
      _isLoading = true;
    });
    try {
      final serverConfig = ref.read(serverConfigProvider);
      await ref.read(currentUserProvider.notifier).login(
        serverUrl: serverConfig.serverUrl,
        database: serverConfig.database,
        email: email,
        password: 'admin123',
        isDemo: true,
      );
      ref.read(currentUserProvider.notifier).switchRole(role);
      if (mounted) widget.onLoginSuccess();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverConfig = ref.watch(serverConfigProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToServer,
        ),
        title: Row(
          children: [
            FlexBadge(
              text: Uri.tryParse(serverConfig.serverUrl)?.host ?? serverConfig.serverUrl,
              variant: serverConfig.isConnected ? FlexBadgeVariant.success : FlexBadgeVariant.info,
              icon: serverConfig.isConnected ? Icons.cloud_done : Icons.cloud_outlined,
            ),
            const SizedBox(width: 8),
            Text(
              serverConfig.database,
              style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Screen Title
              Text('Sign In to FlexERP', style: FlexTypography.headlineLg),
              const SizedBox(height: 4),
              Text(
                'Connecting to ${serverConfig.serverUrl} [${serverConfig.database}]',
                style: FlexTypography.bodySm,
              ),
              const SizedBox(height: 20),

              // Credential Input Card
              FlexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('USERNAME / EMAIL', style: FlexTypography.labelSm),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      style: FlexTypography.bodyMd,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: FlexColors.primaryLight, size: 20),
                        hintText: 'admin or user@domain.lk',
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('PASSWORD', style: FlexTypography.labelSm),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: FlexTypography.bodyMd,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: FlexColors.primaryLight, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: FlexColors.textSecondaryDark,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        hintText: '••••••••',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remember Me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: FlexColors.primary,
                              onChanged: (val) => setState(() => _rememberMe = val ?? true),
                            ),
                            Text('Remember Credential', style: FlexTypography.bodySm),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'Reset Token',
                            style: FlexTypography.bodySm.copyWith(color: FlexColors.primaryLight),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Primary Live API Sign In Button
                    FlexButton(
                      label: _isLoading ? 'Authenticating JSON-RPC...' : 'Sign In (Live Odoo API)',
                      icon: Icons.login,
                      variant: FlexButtonVariant.primary,
                      isLoading: _isLoading,
                      height: 50,
                      onPressed: () => _handleSignIn(isDemo: false),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlexColors.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FlexColors.danger.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline, color: FlexColors.dangerLight, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Authentication Notice',
                                  style: FlexTypography.labelMd.copyWith(color: FlexColors.dangerLight),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              style: FlexTypography.bodySm.copyWith(color: FlexColors.dangerLight),
                            ),
                            const SizedBox(height: 10),
                            FlexButton(
                              label: 'Continue in Sri Lanka Offline Sandbox',
                              icon: Icons.offline_bolt_outlined,
                              variant: FlexButtonVariant.secondary,
                              height: 36,
                              onPressed: () => _handleSignIn(isDemo: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sri Lanka Enterprise Quick Demo Profiles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Or Instant Demo Profiles (1-Tap)', style: FlexTypography.headlineMd),
                  ),
                  const SizedBox(width: 8),
                  const FlexBadge(text: 'OFFLINE SANDBOX', variant: FlexBadgeVariant.info),
                ],
              ),
              const SizedBox(height: 12),

              _RoleSelectTile(
                title: 'Kasun Jayawardena',
                roleLabel: 'Super Admin / C-Level',
                email: 'admin@flexcorp.lk',
                icon: Icons.admin_panel_settings,
                onTap: () => _quickSelectRole(UserRole.superAdmin, 'admin@flexcorp.lk'),
              ),
              _RoleSelectTile(
                title: 'Ruwan Perera',
                roleLabel: 'Vendor Admin (slot only)',
                email: 'vendor@flexcorp.lk',
                icon: Icons.store,
                onTap: () => _quickSelectRole(UserRole.vendorAdmin, 'vendor@flexcorp.lk'),
              ),
              _RoleSelectTile(
                title: 'Nimal Perera',
                roleLabel: 'Field Sales Representative',
                email: 'sales@flexcorp.lk',
                icon: Icons.point_of_sale,
                onTap: () => _quickSelectRole(UserRole.salesRep, 'sales@flexcorp.lk'),
              ),
              _RoleSelectTile(
                title: 'Tharindu Silva',
                roleLabel: 'Warehouse Logistics Lead',
                email: 'warehouse@flexcorp.lk',
                icon: Icons.inventory_2,
                onTap: () => _quickSelectRole(UserRole.warehouseOp, 'warehouse@flexcorp.lk'),
              ),
              _RoleSelectTile(
                title: 'Dilini Fernando',
                roleLabel: 'Senior Accountant / Cashier',
                email: 'accounts@flexcorp.lk',
                icon: Icons.account_balance_wallet,
                onTap: () => _quickSelectRole(UserRole.accountant, 'accounts@flexcorp.lk'),
              ),
              _RoleSelectTile(
                title: 'Kamal Gunaratne',
                roleLabel: 'POS Register Operator',
                email: 'pos@flexcorp.lk',
                icon: Icons.receipt_long,
                onTap: () => _quickSelectRole(UserRole.posCashier, 'pos@flexcorp.lk'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelectTile extends StatelessWidget {
  final String title;
  final String roleLabel;
  final String email;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleSelectTile({
    required this.title,
    required this.roleLabel,
    required this.email,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: FlexCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FlexColors.surfaceRaisedDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: FlexColors.primaryLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlexTypography.labelLg),
                  Text('$roleLabel • $email', style: FlexTypography.bodySm),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: FlexColors.textDisabledDark),
          ],
        ),
      ),
    );
  }
}
