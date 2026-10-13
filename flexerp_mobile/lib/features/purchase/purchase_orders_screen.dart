import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/purchase_repository.dart';

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_sync);
  }

  Future<void> _sync() async {
    setState(() => _error = null);
    try {
      await ref.read(purchaseOrdersProvider.notifier).syncFromServer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: FlexColors.danger,
        ),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('not installed')) {
      return 'Purchase module is not installed on this Odoo database.';
    }
    if (msg.contains('disabled') || msg.contains('Feature')) {
      return 'Purchase is disabled for this vendor.';
    }
    return 'Could not load purchase orders.';
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Purchase Orders',
        subtitle: 'Independent purchase module',
        showCompanySwitcher: false,
        onSync: _sync,
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: _sync,
        child: orders.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: FlexColors.textSecondaryDark.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error != null ? 'Sync failed' : 'No purchase orders yet',
                    textAlign: TextAlign.center,
                    style: FlexTypography.bodyMd.copyWith(color: FlexColors.textSecondaryDark),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _friendlyError(_error!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FlexColors.danger, fontSize: 12),
                      ),
                    ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final o = orders[index];
                  return FlexCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.name, style: FlexTypography.labelLg),
                              const SizedBox(height: 4),
                              Text(o.partnerName, style: FlexTypography.bodySm),
                              Text(
                                o.state.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: FlexColors.textSecondaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          LkFormatters.formatLkr(o.amountTotal),
                          style: FlexTypography.labelLg.copyWith(color: FlexColors.primaryLight),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
