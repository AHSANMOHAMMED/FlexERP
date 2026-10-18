import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/models/pos_order.dart';
import '../../data/models/vendor_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/pos_repository.dart';
import '../../data/repositories/partner_repository.dart';
import '../../data/repositories/vendor_repository.dart';
import '../../data/repositories/vendor_inventory_repository.dart';
import '../../core/api/odoo_client.dart';
import '../../core/widgets/barcode_camera_view.dart';
import 'pos_tender_screen.dart';

class PosRegisterScreen extends ConsumerStatefulWidget {
  const PosRegisterScreen({super.key});

  @override
  ConsumerState<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends ConsumerState<PosRegisterScreen> {
  String _selectedCategory = 'All';
  List<String> _categories = const ['All'];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _desktopBarcodeCtrl = TextEditingController();
  String _searchQuery = '';
  String? _lastLiveSyncNotice;
  int? _selectedPartnerId;
  String _selectedPartnerName = 'Walk-in';
  bool _createInvoice = false;
  bool _sessionLoading = false;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureLiveSession);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _desktopBarcodeCtrl.dispose();
    super.dispose();
  }

  bool get _isDesktop {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.macOS || p == TargetPlatform.windows || p == TargetPlatform.linux;
  }

  Future<void> _onBarcodeScan(String barcode) async {
    final invNotifier = ref.read(vendorInventoryProvider.notifier);
    VendorProduct? product;
    try {
      // Local O(1) index first, then the server barcode lookup (live).
      product = await invNotifier.lookupBarcodeLive(barcode.trim());
    } catch (e) {
      debugPrint('FlexERP: POS barcode lookup failed for $barcode: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode lookup failed: ${describeError(e)}'),
          backgroundColor: FlexColors.danger,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (product != null) {
      if (product.stockOnHand <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} is OUT OF STOCK (${product.stockOnHand})!'),
            backgroundColor: FlexColors.danger,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      final posProd = PosProduct(
        id: product.id,
        name: product.name,
        price: product.sellingPrice,
        category: product.category,
        stockOnHand: product.stockOnHand,
        barcode: product.barcode,
        sku: product.sku,
      );
      ref.read(posCartProvider.notifier).addProduct(posProd);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: FlexColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Scanned & Added: ${product.name}')),
            ],
          ),
          backgroundColor: FlexColors.surfaceRaisedDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product matched barcode "$barcode"'),
          backgroundColor: FlexColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openBarcodeScannerModal() {
    final inventory = ref.read(vendorInventoryProvider);
    final isLive = _isLive;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlexColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final manualCodeCtrl = TextEditingController();
        return SingleChildScrollView(
          child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FlexColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_scanner, color: FlexColors.primaryLight, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('High-Speed Barcode Scanner', style: FlexTypography.headlineSm),
                          const Text('Instant O(1) Catalog Match', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: FlexColors.textSecondaryDark),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Live camera viewfinder (mobile_scanner)
              BarcodeCameraView(
                height: 200,
                onDetected: (code) {
                  Navigator.pop(ctx);
                  _onBarcodeScan(code);
                },
              ),
              if (!isLive) ...[
              const SizedBox(height: 16),
              const Text('Quick Test Barcodes (demo):', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: inventory.take(4).map((p) {
                  return ActionChip(
                    avatar: const Icon(Icons.barcode_reader, size: 16, color: FlexColors.primaryLight),
                    label: Text('${p.barcode} (${p.name.split(' ').first})'),
                    backgroundColor: FlexColors.surfaceRaisedDark,
                    labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _onBarcodeScan(p.barcode);
                    },
                  );
                }).toList(),
              ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: manualCodeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Or enter barcode manually...',
                        prefixIcon: Icon(Icons.keyboard, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          Navigator.pop(ctx);
                          _onBarcodeScan(val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlexColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      if (manualCodeCtrl.text.trim().isNotEmpty) {
                        Navigator.pop(ctx);
                        _onBarcodeScan(manualCodeCtrl.text.trim());
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  bool get _isLive {
    final user = ref.read(currentUserProvider);
    return user != null && !user.isDemo;
  }

  /// Opens (or re-attaches to) the real Odoo POS session for live users.
  Future<void> _ensureLiveSession({bool force = false}) async {
    if (!_isLive) return;
    final session = ref.read(posSessionProvider);
    if (session.isLiveOpen && !force) return;
    setState(() {
      _sessionLoading = true;
      _sessionError = null;
    });
    try {
      await ref.read(posSessionProvider.notifier).openLiveSession(configId: session.configId);
    } catch (e) {
      debugPrint('FlexERP: POS session open failed: $e');
      if (mounted) setState(() => _sessionError = describeError(e));
    } finally {
      if (mounted) setState(() => _sessionLoading = false);
    }
  }

  /// Returns a reason checkout is blocked, or null when selling is allowed.
  String? _checkoutBlockReason() {
    if (!_isLive) return null;
    final session = ref.read(posSessionProvider);
    if (session.isLiveOpen) return null;
    if (_sessionLoading) return 'POS session is still opening — please wait.';
    return 'No open POS session. ${_sessionError ?? 'Tap "Open session" to start selling.'}';
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final currentVendor = ref.watch(currentVendorProvider);
    final products = ref.watch(posProductsProvider);
    final cart = ref.watch(posCartProvider);
    final cartTotal = ref.watch(posCartProvider.notifier).totalAmount;
    final cartItemCount = ref.watch(posCartProvider.notifier).totalItemCount;

    // Company / user switch resets the live session → re-attach automatically.
    ref.listen(posSessionProvider, (prev, next) {
      if (_isLive && next.state == PosShiftSession.stateNone && prev?.state != PosShiftSession.stateNone) {
        Future.microtask(_ensureLiveSession);
      }
    });

    // Listen to real-time vendor inventory events
    ref.listen(vendorStockEventStreamProvider, (prev, next) {
      next.whenData((event) {
        setState(() {
          _lastLiveSyncNotice = '⚡ Real-Time Sync: ${event.productName} stock is now ${event.newStock} (${event.reason})';
        });
        // Clear notice after 4 seconds
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _lastLiveSyncNotice != null) {
            setState(() => _lastLiveSyncNotice = null);
          }
        });
      });
    });

    _categories = [
      'All',
      ...{for (final p in products) if (p.category.isNotEmpty) p.category},
    ];
    if (!_categories.contains(_selectedCategory)) _selectedCategory = 'All';
    final session = ref.watch(posSessionProvider);
    final isLive = _isLive;

    final filteredProducts = products.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'POS Touch Register',
        subtitle: '${currentVendor.name} • ${currentVendor.vendorId}',
        currentBranch: currentBranch,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isLive && !session.isLiveOpen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: (_sessionError != null ? FlexColors.danger : FlexColors.warning).withOpacity(0.15),
                  child: Row(
                    children: [
                      if (_sessionLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.point_of_sale,
                          size: 18,
                          color: _sessionError != null ? FlexColors.danger : FlexColors.warning,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sessionLoading
                              ? 'Opening POS session in Odoo…'
                              : 'No open POS session — checkout disabled.'
                                  '${_sessionError != null ? '\n$_sessionError' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                      if (!_sessionLoading)
                        TextButton(
                          onPressed: () => _ensureLiveSession(force: true),
                          child: const Text('Open session'),
                        ),
                    ],
                  ),
                ),
              // Live Stock Sync Notification Bar
              if (_lastLiveSyncNotice != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: FlexColors.success.withOpacity(0.18),
                    border: Border(
                      bottom: BorderSide(color: FlexColors.success.withOpacity(0.5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: FlexColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastLiveSyncNotice!,
                          style: const TextStyle(color: FlexColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _lastLiveSyncNotice = null),
                        child: const Icon(Icons.close, color: FlexColors.textSecondaryDark, size: 14),
                      ),
                    ],
                  ),
                ),

              // Desktop / wedge scanner: keyboard barcode entry (no camera crash)
              if (_isDesktop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _desktopBarcodeCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Scan barcode (keyboard / USB scanner)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                    onSubmitted: (code) {
                      if (code.trim().isEmpty) return;
                      _onBarcodeScan(code.trim());
                      _desktopBarcodeCtrl.clear();
                    },
                  ),
                ),

              // Search & Barcode Quick Action Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: FlexColors.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FlexColors.borderDark),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search SKU, name, or barcode...',
                            hintStyle: const TextStyle(color: FlexColors.textSecondaryDark, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18, color: FlexColors.textSecondaryDark),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: FlexColors.textSecondaryDark),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _openBarcodeScannerModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [FlexColors.primary, FlexColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: FlexColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'SCAN',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories Carousel
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: FlexColors.primary,
                        backgroundColor: FlexColors.surfaceRaisedDark,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : FlexColors.textSecondaryDark,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? FlexColors.primary : FlexColors.borderDark,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // 2-Column Product Grid
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: FlexColors.textSecondaryDark),
                            const SizedBox(height: 12),
                            Text('No products matched "$_searchQuery"', style: FlexTypography.bodyMd),
                            const SizedBox(height: 4),
                            Text('Vendor: ${currentVendor.name} (${currentVendor.vendorId})', style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _ProductGridTile(
                            product: product,
                            onTap: () {
                              if (product.stockOnHand <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${product.name} is out of stock!'),
                                    backgroundColor: FlexColors.danger,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                                return;
                              }
                              ref.read(posCartProvider.notifier).addProduct(product);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),

          // Floating Cart Bottom Strip
          if (cart.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: InkWell(
                onTap: () => _showCartDrawer(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: FlexColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: FlexColors.primary.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$cartItemCount Items',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              LkFormatters.formatLkr(cartTotal),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Tap to review cart & checkout',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCartDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final cart = ref.watch(posCartProvider);
            final cartTotal = ref.watch(posCartProvider.notifier).totalAmount;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: FlexColors.borderDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('POS Cart Items', style: FlexTypography.headlineMd),
                        TextButton(
                          onPressed: () {
                            ref.read(posCartProvider.notifier).clear();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear Cart', style: TextStyle(color: FlexColors.danger)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Customer: $_selectedPartnerName', style: FlexTypography.labelMd),
                      subtitle: const Text('Tap to pick customer (optional)'),
                      trailing: const Icon(Icons.person_search),
                      onTap: () async {
                        await ref.read(partnersProvider.notifier).syncFromOdoo();
                        final partners = ref.read(partnersProvider);
                        if (!context.mounted) return;
                        final picked = await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          backgroundColor: FlexColors.surfaceDark,
                          builder: (ctx) => SafeArea(
                            child: ListView(
                              children: [
                                ListTile(
                                  title: const Text('Walk-in'),
                                  onTap: () => Navigator.pop(ctx, {'id': null, 'name': 'Walk-in'}),
                                ),
                                ...partners.map((p) => ListTile(
                                      title: Text(p.name),
                                      subtitle: Text(p.phone),
                                      onTap: () => Navigator.pop(ctx, {'id': p.id, 'name': p.name}),
                                    )),
                              ],
                            ),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedPartnerId = picked['id'] as int?;
                            _selectedPartnerName = picked['name']?.toString() ?? 'Walk-in';
                          });
                        }
                      },
                    ),
                    if (ref.watch(currentVendorFeaturesProvider).enableInvoicing)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Create tax invoice after sale'),
                        value: _createInvoice,
                        onChanged: (v) => setState(() => _createInvoice = v),
                      ),
                    ...cart.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: FlexTypography.labelMd, maxLines: 1),
                                  Text(LkFormatters.formatLkr(item.product.price), style: FlexTypography.bodySm),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    ref.read(posCartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1);
                                  },
                                ),
                                Text('${item.quantity}', style: FlexTypography.labelLg),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20, color: FlexColors.primaryLight),
                                  onPressed: () {
                                    ref.read(posCartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: FlexColors.danger),
                                  onPressed: () {
                                    ref.read(posCartProvider.notifier).updateQuantity(item.product.id, 0);
                                  },
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                LkFormatters.formatLkr(item.subtotal),
                                style: FlexTypography.codeNum,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill Amount (LKR)', style: FlexTypography.headlineSm),
                        Text(
                          LkFormatters.formatLkr(cartTotal),
                          style: FlexTypography.headlineMd.copyWith(color: FlexColors.primaryLight),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FlexButton(
                      label: 'Proceed to Payment Tender',
                      icon: Icons.payments,
                      height: 48,
                      onPressed: cart.isEmpty
                          ? null
                          : () {
                              final blocked = _checkoutBlockReason();
                              if (blocked != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(blocked), backgroundColor: FlexColors.danger),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PosTenderScreen(
                                    totalAmount: cartTotal,
                                    partnerId: _selectedPartnerId,
                                    createInvoice: _createInvoice,
                                    onOrderComplete: () {},
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductGridTile extends StatelessWidget {
  final PosProduct product;
  final VoidCallback onTap;

  const _ProductGridTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stockOnHand <= 0;
    final isLowStock = product.stockOnHand > 0 && product.stockOnHand <= 5;

    final stockColor = isOutOfStock
        ? FlexColors.danger
        : isLowStock
            ? FlexColors.warning
            : FlexColors.success;

    final stockLabel = isOutOfStock
        ? 'OUT OF STOCK'
        : isLowStock
            ? '${product.stockOnHand} LOW'
            : '${product.stockOnHand} in stock';

    return FlexCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FlexBadge(text: product.category, variant: FlexBadgeVariant.neutral),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stockColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: stockColor.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  stockLabel,
                  style: TextStyle(
                    color: stockColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: Opacity(
              opacity: isOutOfStock ? 0.35 : 1.0,
              child: Icon(
                product.category == 'Safety & PPE'
                    ? Icons.shield
                    : product.category == 'Power Tools'
                        ? Icons.build
                        : Icons.hardware,
                size: 36,
                color: FlexColors.primaryLight,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: FlexTypography.labelMd.copyWith(
                  color: isOutOfStock ? FlexColors.textSecondaryDark : Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.qr_code, size: 10, color: FlexColors.textSecondaryDark),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '${product.sku} • ${product.barcode}',
                      style: const TextStyle(fontSize: 9, color: FlexColors.textSecondaryDark, fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LkFormatters.formatLkr(product.price),
                    style: FlexTypography.codeNum.copyWith(
                      color: isOutOfStock ? FlexColors.textSecondaryDark : FlexColors.primaryLight,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    isOutOfStock ? Icons.block : Icons.add_circle,
                    color: isOutOfStock ? FlexColors.danger.withOpacity(0.5) : FlexColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
