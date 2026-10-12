import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/models/vendor_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/vendor_repository.dart';

class VendorManagementScreen extends ConsumerStatefulWidget {
  const VendorManagementScreen({super.key});

  @override
  ConsumerState<VendorManagementScreen> createState() =>
      _VendorManagementScreenState();
}

class _VendorManagementScreenState extends ConsumerState<VendorManagementScreen> {
  void _showCreateVendorModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final vendors = ref.read(vendorsProvider);
    final nextId = 'VND-00${vendors.length + 1}';
    final idCtrl = TextEditingController(text: nextId);
    String businessType = 'Retail Hardware';

    bool enablePos = true;
    bool enableInventory = true;
    bool enableSales = false;
    bool enableInvoicing = true;
    bool enableHr = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Provision New Vendor Tenant', style: FlexTypography.headlineSm),
                        IconButton(
                          icon: const Icon(Icons.close, color: FlexColors.textSecondaryDark),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Initializes an isolated vendor database partition and scopes user roles.',
                      style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vendor Business Name',
                        hintText: 'e.g. Galle Fort Emporium',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: idCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vendor ID',
                              hintText: 'VND-005',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: businessType,
                            decoration: const InputDecoration(labelText: 'Business Category'),
                            dropdownColor: FlexColors.surfaceRaisedDark,
                            items: [
                              'Retail Hardware',
                              'Electronics & Tools',
                              'Food & Grocery',
                              'Fashion & Textiles',
                              'Pharmacy & Healthcare',
                            ].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => businessType = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Admin Contact Email',
                        hintText: 'admin@galleemporium.lk',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Subscribed Modular Features', style: FlexTypography.labelLg),
                    const Text(
                      'Disabled modules are completely excluded from the vendor UI to prevent screen overlap.',
                      style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: FlexColors.surfaceRaisedDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FlexColors.borderDark),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('POS Touch Register & Cashier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('High-speed walk-in retail sales', style: TextStyle(fontSize: 11, color: FlexColors.textSecondaryDark)),
                            value: enablePos,
                            activeColor: FlexColors.primaryLight,
                            onChanged: (v) => setModalState(() => enablePos = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Inventory & Barcode Suite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Catalog management and live stock sync', style: TextStyle(fontSize: 11, color: FlexColors.textSecondaryDark)),
                            value: enableInventory,
                            activeColor: FlexColors.primaryLight,
                            onChanged: (v) => setModalState(() => enableInventory = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Sales CRM & B2B Quotations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Pipeline, wholesale leads, and quotations', style: TextStyle(fontSize: 11, color: FlexColors.textSecondaryDark)),
                            value: enableSales,
                            activeColor: FlexColors.primaryLight,
                            onChanged: (v) => setModalState(() => enableSales = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Finance & Invoicing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Tax invoices, receipts, and ledger', style: TextStyle(fontSize: 11, color: FlexColors.textSecondaryDark)),
                            value: enableInvoicing,
                            activeColor: FlexColors.primaryLight,
                            onChanged: (v) => setModalState(() => enableInvoicing = v),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('HR, Staff Attendance & Leaves', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Cashier shifts and employee rosters', style: TextStyle(fontSize: 11, color: FlexColors.textSecondaryDark)),
                            value: enableHr,
                            activeColor: FlexColors.primaryLight,
                            onChanged: (v) => setModalState(() => enableHr = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FlexButton(
                      label: 'Create & Provision Tenant DB',
                      icon: Icons.domain_add,
                      height: 48,
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty || idCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter Vendor Name and ID'),
                              backgroundColor: FlexColors.danger,
                            ),
                          );
                          return;
                        }

                        final newVendor = VendorTenant(
                          id: DateTime.now().millisecondsSinceEpoch,
                          vendorId: idCtrl.text.trim(),
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim().isNotEmpty
                              ? emailCtrl.text.trim()
                              : 'admin@${idCtrl.text.trim().toLowerCase()}.lk',
                          phone: '+94 11 765 4321',
                          city: 'Colombo',
                          address: 'Retail Complex, Sri Lanka',
                          taxTin: 'TIN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-V',
                          createdAt: DateTime.now(),
                          assignedAdminName: 'Store Admin',
                          cashierCount: 2,
                          features: VendorFeatures(
                            enablePos: enablePos,
                            enableInventory: enableInventory,
                            enableSales: enableSales,
                            enableInvoicing: enableInvoicing,
                            enableHr: enableHr,
                          ),
                        );

                        ref.read(vendorsProvider.notifier).addVendor(newVendor);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vendor ${newVendor.name} (${newVendor.vendorId}) created!'),
                            backgroundColor: FlexColors.success,
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

  void _showEditFeaturesModal(BuildContext context, VendorTenant vendor) {
    bool enablePos = vendor.features.enablePos;
    bool enableInventory = vendor.features.enableInventory;
    bool enableSales = vendor.features.enableSales;
    bool enableInvoicing = vendor.features.enableInvoicing;
    bool enableHr = vendor.features.enableHr;

    showModalBottomSheet(
      context: context,
      backgroundColor: FlexColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Modular Features: ${vendor.name}', style: FlexTypography.headlineSm),
                      IconButton(
                        icon: const Icon(Icons.close, color: FlexColors.textSecondaryDark),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('POS Register'),
                    value: enablePos,
                    activeColor: FlexColors.primaryLight,
                    onChanged: (v) => setModalState(() => enablePos = v),
                  ),
                  SwitchListTile(
                    title: const Text('Inventory & Stock'),
                    value: enableInventory,
                    activeColor: FlexColors.primaryLight,
                    onChanged: (v) => setModalState(() => enableInventory = v),
                  ),
                  SwitchListTile(
                    title: const Text('Sales CRM & Quotes'),
                    value: enableSales,
                    activeColor: FlexColors.primaryLight,
                    onChanged: (v) => setModalState(() => enableSales = v),
                  ),
                  SwitchListTile(
                    title: const Text('Invoicing & Ledger'),
                    value: enableInvoicing,
                    activeColor: FlexColors.primaryLight,
                    onChanged: (v) => setModalState(() => enableInvoicing = v),
                  ),
                  SwitchListTile(
                    title: const Text('HR & Attendance'),
                    value: enableHr,
                    activeColor: FlexColors.primaryLight,
                    onChanged: (v) => setModalState(() => enableHr = v),
                  ),
                  const SizedBox(height: 16),
                  FlexButton(
                    label: 'Save Feature Toggles',
                    icon: Icons.check,
                    height: 46,
                    onPressed: () {
                      final updated = vendor.features.copyWith(
                        enablePos: enablePos,
                        enableInventory: enableInventory,
                        enableSales: enableSales,
                        enableInvoicing: enableInvoicing,
                        enableHr: enableHr,
                      );
                      ref.read(vendorsProvider.notifier).updateVendorFeatures(vendor.vendorId, updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Updated features for ${vendor.name}!'),
                          backgroundColor: FlexColors.success,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final vendors = ref.watch(vendorsProvider);
    final activeVendor = ref.watch(currentVendorProvider);
    final activeVendorId = activeVendor.vendorId;

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Multi-Vendor Architecture',
        subtitle: 'Tenant Partitioning & Feature Toggles',
        currentBranch: currentBranch,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FlexColors.primary,
        onPressed: () => _showCreateVendorModal(context),
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Provision Tenant', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // Architecture Notice Card
          FlexCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FlexColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hub, color: FlexColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Isolated Vendor Tenant DBs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                        'Each vendor operates on an isolated database partition. Real-time stock updates, barcodes, and orders do not mix between vendors.',
                        style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text('Active Tenants (${vendors.length})', style: FlexTypography.headlineSm),
          const SizedBox(height: 8),

          ...vendors.map((vendor) {
            final isCurrent = vendor.vendorId == activeVendorId;
            final f = vendor.features;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FlexCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCurrent ? FlexColors.primary : FlexColors.surfaceRaisedDark,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCurrent ? FlexColors.primaryLight : FlexColors.borderDark,
                                ),
                              ),
                              child: Text(
                                vendor.vendorId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              vendor.name,
                              style: FlexTypography.labelLg.copyWith(
                                color: isCurrent ? FlexColors.primaryLight : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (isCurrent)
                          const FlexBadge(text: 'ACTIVE CONTEXT', variant: FlexBadgeVariant.success)
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: const BorderSide(color: FlexColors.primaryLight),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              ref.read(currentVendorProvider.notifier).selectVendor(vendor.vendorId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Switched active vendor to ${vendor.name} (${vendor.vendorId})'),
                                  backgroundColor: FlexColors.surfaceRaisedDark,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Switch Here', style: TextStyle(fontSize: 11, color: FlexColors.primaryLight)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${vendor.city} • Admin: ${vendor.assignedAdminName ?? vendor.email}',
                      style: const TextStyle(color: FlexColors.textSecondaryDark, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    const Text('Active Modules:', style: TextStyle(color: FlexColors.textSecondaryDark, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _FeatureBadge(label: 'POS', enabled: f.enablePos),
                        _FeatureBadge(label: 'Inventory', enabled: f.enableInventory),
                        _FeatureBadge(label: 'Sales/CRM', enabled: f.enableSales),
                        _FeatureBadge(label: 'Invoicing', enabled: f.enableInvoicing),
                        _FeatureBadge(label: 'HR', enabled: f.enableHr),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _showEditFeaturesModal(context, vendor),
                          icon: const Icon(Icons.toggle_on, size: 18, color: FlexColors.primaryLight),
                          label: const Text('Configure Features', style: TextStyle(fontSize: 12, color: FlexColors.primaryLight)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  final bool enabled;

  const _FeatureBadge({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled ? FlexColors.success.withOpacity(0.15) : FlexColors.surfaceRaisedDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: enabled ? FlexColors.success.withOpacity(0.4) : FlexColors.borderDark,
          width: 0.8,
        ),
      ),
      child: Text(
        '$label ${enabled ? "✓" : "✗"}',
        style: TextStyle(
          color: enabled ? FlexColors.success : FlexColors.textSecondaryDark,
          fontSize: 10,
          fontWeight: enabled ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
