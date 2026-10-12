import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vendor_model.dart';

final vendorsProvider = NotifierProvider<VendorsNotifier, List<VendorTenant>>(
  VendorsNotifier.new,
);

final currentVendorProvider = NotifierProvider<CurrentVendorNotifier, VendorTenant>(
  CurrentVendorNotifier.new,
);

final currentVendorFeaturesProvider = Provider<VendorFeatures>((ref) {
  return ref.watch(currentVendorProvider).features;
});

class VendorsNotifier extends Notifier<List<VendorTenant>> {
  @override
  List<VendorTenant> build() {
    return [
      VendorTenant(
        id: 1,
        vendorId: 'VND-001',
        name: 'Ceylon General Traders (Pvt) Ltd',
        email: 'info@ceylontraders.lk',
        phone: '+94 11 234 5678',
        city: 'Colombo 03',
        address: 'No. 45, Galle Road, Colombo 03',
        taxTin: 'TIN-984210452-V',
        features: const VendorFeatures(
          enablePos: true,
          enableInventory: true,
          enableSales: true,
          enableInvoicing: true,
          enableHr: true,
        ),
        createdAt: DateTime(2025, 1, 15),
        assignedAdminName: 'Ruwan Perera (Admin)',
        cashierCount: 3,
      ),
      VendorTenant(
        id: 2,
        vendorId: 'VND-002',
        name: 'Kelaniya Express Retail Mart',
        email: 'kelaniya@retailmart.lk',
        phone: '+94 11 987 6543',
        city: 'Kelaniya',
        address: 'No. 112, Kandy Road, Peliyagoda',
        taxTin: 'TIN-482910492-V',
        features: const VendorFeatures(
          enablePos: true,
          enableInventory: true,
          enableSales: false, // Sales/CRM disabled for this retail vendor
          enableInvoicing: false, // Simple cash-drawer; advanced accounting disabled
          enableHr: false, // Standalone kiosk
        ),
        createdAt: DateTime(2025, 3, 10),
        assignedAdminName: 'Nimal Silva (Store Mgr)',
        cashierCount: 2,
      ),
      VendorTenant(
        id: 3,
        vendorId: 'VND-003',
        name: 'Kandy Industrial & Hardware Depot',
        email: 'sales@kandyhardware.lk',
        phone: '+94 81 223 3445',
        city: 'Kandy',
        address: 'No. 88, Dalada Veediya, Kandy',
        taxTin: 'TIN-662391032-V',
        features: const VendorFeatures(
          enablePos: true,
          enableInventory: true,
          enableSales: true,
          enableInvoicing: true,
          enableHr: false, // No HR self-service
        ),
        createdAt: DateTime(2025, 5, 20),
        assignedAdminName: 'Chandana Fernando (Admin)',
        cashierCount: 2,
      ),
      VendorTenant(
        id: 4,
        vendorId: 'VND-004',
        name: 'Galle Coastal Spices & Tea Boutique',
        email: 'contact@gallespices.lk',
        phone: '+94 91 224 8890',
        city: 'Galle Fort',
        address: 'No. 14, Church Street, Galle Fort',
        taxTin: 'TIN-119283746-V',
        features: const VendorFeatures(
          enablePos: true,
          enableInventory: true,
          enableSales: false,
          enableInvoicing: true,
          enableHr: false,
        ),
        createdAt: DateTime(2025, 8, 1),
        assignedAdminName: 'Farhan Mohideen (Partner)',
        cashierCount: 1,
      ),
    ];
  }

  void addVendor(VendorTenant newVendor) {
    state = [...state, newVendor];
  }

  void updateVendorFeatures(String vendorId, VendorFeatures features) {
    state = [
      for (final v in state)
        if (v.vendorId == vendorId)
          v.copyWith(features: features)
        else
          v,
    ];

    // If current vendor features were updated, propagate to currentVendorNotifier
    final current = ref.read(currentVendorProvider);
    if (current.vendorId == vendorId) {
      ref.read(currentVendorProvider.notifier).setFeatures(features);
    }
  }

  void toggleVendorStatus(String vendorId) {
    state = [
      for (final v in state)
        if (v.vendorId == vendorId)
          v.copyWith(isActive: !v.isActive)
        else
          v,
    ];
  }
}

class CurrentVendorNotifier extends Notifier<VendorTenant> {
  @override
  VendorTenant build() {
    final all = ref.watch(vendorsProvider);
    return all.isNotEmpty
        ? all.first
        : VendorTenant(
            id: 1,
            vendorId: 'VND-001',
            name: 'Ceylon General Traders (Pvt) Ltd',
            email: 'info@ceylontraders.lk',
            phone: '+94 11 234 5678',
            city: 'Colombo 03',
            address: 'No. 45, Galle Road, Colombo 03',
            taxTin: 'TIN-984210452-V',
            createdAt: DateTime.now(),
          );
  }

  void selectVendor(String vendorId) {
    final all = ref.read(vendorsProvider);
    final match = all.firstWhere(
      (v) => v.vendorId == vendorId,
      orElse: () => state,
    );
    state = match;
  }

  void setFeatures(VendorFeatures features) {
    state = state.copyWith(features: features);
  }
}
