import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/barcode_camera_view.dart';
import '../../core/api/odoo_client.dart';
import '../../data/models/vendor_model.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/vendor_inventory_repository.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  String _activeBarcode = '—';
  bool _lookupBusy = false;
  final _manualBarcodeCtrl = TextEditingController();
  Map<String, dynamic> _scannedProduct = {
    'name': 'Scan a barcode to look up stock',
    'sku': '—',
    'barcode': '—',
    'stockOnHand': 0,
    'forecastedStock': 0,
    'costPrice': 0.0,
    'salesPrice': 0.0,
    'locations': <Map<String, dynamic>>[],
  };

  bool get _isDesktop {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.macOS || p == TargetPlatform.windows || p == TargetPlatform.linux;
  }

  @override
  void dispose() {
    _manualBarcodeCtrl.dispose();
    super.dispose();
  }

  bool get _isLive {
    final user = ref.read(currentUserProvider);
    return user != null && !user.isDemo;
  }

  Future<void> _simulateScan(String code) async {
    setState(() {
      _activeBarcode = code;
      _lookupBusy = true;
    });
    final VendorProduct? lookedUp;
    try {
      lookedUp = await ref.read(vendorInventoryProvider.notifier).lookupBarcodeLive(code);
    } catch (e) {
      debugPrint('FlexERP: barcode lookup failed for $code: $e');
      if (!mounted) return;
      setState(() => _lookupBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlexColors.danger,
          content: Text('Lookup failed: ${describeError(e)}'),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _lookupBusy = false);
    final product = lookedUp;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FlexColors.warning,
          content: Text('No product for barcode $code'),
        ),
      );
      return;
    }
    setState(() {
      _scannedProduct = {
        'name': product.name,
        'sku': product.sku,
        'barcode': product.barcode,
        'stockOnHand': product.stockOnHand,
        'forecastedStock': product.stockOnHand,
        'costPrice': product.costPrice,
        'salesPrice': product.sellingPrice,
        'locations': [
          {'name': 'On Hand', 'qty': product.stockOnHand},
        ],
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FlexColors.success,
        duration: const Duration(seconds: 1),
        content: Text('Found: ${product.name}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Barcode Inquiry',
        subtitle: 'Logistics Scanner',
        currentBranch: currentBranch,
      ),
      body: Column(
        children: [
          if (_isDesktop || !cameraScanSupported)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: FlexCard(
                child: Text(
                  'Camera scanner not available here. Use a USB barcode wedge or type the SKU/barcode below.',
                  style: FlexTypography.bodySm,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: BarcodeCameraView(
                height: 220,
                onDetected: (code) {
                  if (_lookupBusy) return;
                  _simulateScan(code);
                },
              ),
            ),

          // Manual / USB keyboard-wedge entry (always available)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _manualBarcodeCtrl,
              autofocus: _isDesktop,
              decoration: const InputDecoration(
                labelText: 'Barcode / SKU (keyboard / USB scanner)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.keyboard),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _simulateScan(v.trim());
                _manualBarcodeCtrl.clear();
              },
            ),
          ),

          // Demo-only quick barcodes
          if (!_isLive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code, size: 16),
                    label: const Text('Demo: Pallet'),
                    onPressed: () => _simulateScan('4792001928312'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code, size: 16),
                    label: const Text('Demo: Forklift Part'),
                    onPressed: () => _simulateScan('4792001928428'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Bottom Half: Product Detail Sheet
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FlexCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SCANNED PRODUCT RECORD', style: FlexTypography.labelSm),
                        FlexBadge(text: _scannedProduct['sku'], variant: FlexBadgeVariant.info),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_scannedProduct['name'], style: FlexTypography.headlineSm),
                    const SizedBox(height: 4),
                    Text('Barcode: $_activeBarcode', style: FlexTypography.bodySm),
                    const SizedBox(height: 16),

                    // Stock Comparison Grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FlexColors.surfaceRaisedDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ON HAND STOCK', style: FlexTypography.labelSm),
                                const SizedBox(height: 4),
                                Text(
                                  '${_scannedProduct['stockOnHand']} Units',
                                  style: FlexTypography.headlineSm.copyWith(color: FlexColors.success),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FlexColors.surfaceRaisedDark,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SALES PRICE', style: FlexTypography.labelSm),
                                const SizedBox(height: 4),
                                Text(
                                  LkFormatters.formatLkr(_scannedProduct['salesPrice']),
                                  style: FlexTypography.codeNum.copyWith(color: FlexColors.primaryLight, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Warehouse Bins Breakdown
                    Text('Bin & Aisle Distribution', style: FlexTypography.labelLg),
                    const SizedBox(height: 8),
                    ...(_scannedProduct['locations'] as List).map((loc) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: FlexColors.textSecondaryDark),
                                const SizedBox(width: 6),
                                Text(loc['name'], style: FlexTypography.bodySm),
                              ],
                            ),
                            Text('${loc['qty']} Units', style: FlexTypography.labelMd),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: FlexButton(
                            label: 'Internal Transfer',
                            icon: Icons.swap_horiz,
                            variant: FlexButtonVariant.secondary,
                            height: 40,
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FlexButton(
                            label: 'Print Label',
                            icon: Icons.print,
                            variant: FlexButtonVariant.primary,
                            height: 40,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sending barcode to Bluetooth ESC/POS printer...')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
