import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_user.dart';
import '../models/vendor_model.dart';
import 'auth_repository.dart';

List<VendorTenant> _demoVendors() => [
      VendorTenant(
        id: 1,
        vendorId: 'VND-001',
        name: 'Ceylon General Traders (Pvt) Ltd',
        email: 'info@ceylontraders.lk',
        phone: '+94 11 234 5678',
        city: 'Colombo 03',
        address: 'No. 45, Galle Road, Colombo 03',
        taxTin: 'TIN-984210452-V',
        features: VendorFeatures.mall,
        createdAt: DateTime(2025, 1, 15),
        assignedAdminName: 'Ruwan Perera (Admin)',
        cashierCount: 3,
        preset: 'mall',
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
        features: VendorFeatures.smallShop,
        createdAt: DateTime(2025, 3, 10),
        assignedAdminName: 'Nimal Silva (Store Mgr)',
        cashierCount: 2,
        preset: 'small_shop',
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
        features: VendorFeatures.mall.copyWith(enableHr: false, enableWebsite: false),
        createdAt: DateTime(2025, 5, 20),
        assignedAdminName: 'Chandana Fernando (Admin)',
        cashierCount: 2,
        preset: 'mall',
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
        features: VendorFeatures.smallShop,
        createdAt: DateTime(2025, 8, 1),
        assignedAdminName: 'Farhan Mohideen (Partner)',
        cashierCount: 1,
        preset: 'small_shop',
      ),
    ];

final vendorsProvider = NotifierProvider<VendorsNotifier, List<VendorTenant>>(
  VendorsNotifier.new,
);

final currentVendorProvider = NotifierProvider<CurrentVendorNotifier, VendorTenant>(
  CurrentVendorNotifier.new,
);

/// Feature flags for the active working context.
///
/// - Slot roles (Vendor Admin / Cashier / …): always the logged-in company's
///   bootstrap flags — never another vendor's matrix.
/// - Platform Super Admin: flags of the **selected** vendor from the tenant
///   list (per-company). Editing Vendor B does not change Vendor A or the
///   Super Admin session unless they are switched into that company.
final currentVendorFeaturesProvider = Provider<VendorFeatures>((ref) {
  final user = ref.watch(currentUserProvider);
  final selected = ref.watch(currentVendorProvider);
  final vendors = ref.watch(vendorsProvider);

  if (user == null) return selected.features;

  if (user.role == UserRole.superAdmin) {
    final match = vendors.where(
      (v) => v.vendorId == selected.vendorId || v.id == selected.id,
    );
    if (match.isNotEmpty) return match.first.features;
    if (user.companyId == selected.id) return user.features;
    return selected.features;
  }

  // Non–super-admin: session bootstrap for their slot only.
  return user.features;
});

class VendorsNotifier extends Notifier<List<VendorTenant>> {
  @override
  List<VendorTenant> build() => _demoVendors();

  Future<void> syncFromServer() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) {
      state = _demoVendors();
      return;
    }
    try {
      final rows = await api.listTenants();
      if (rows.isEmpty) return;
      state = rows.map(VendorTenant.fromApi).toList();
      final current = ref.read(currentVendorProvider);
      final match = state.where((v) => v.id == current.id || v.vendorId == user.vendorId);
      if (match.isNotEmpty) {
        ref.read(currentVendorProvider.notifier).replace(match.first);
      }
    } catch (e) {
      // Keep existing list; surface via debug
      assert(() {
        // ignore: avoid_print
        print('Tenant sync failed: $e');
        return true;
      }());
    }
  }

  void addVendor(VendorTenant newVendor) {
    state = [...state, newVendor];
  }

  Future<void> updateVendorFeatures(String vendorId, VendorFeatures features) async {
    state = [
      for (final v in state)
        if (v.vendorId == vendorId) v.copyWith(features: features, preset: 'custom') else v,
    ];

    final current = ref.read(currentVendorProvider);
    if (current.vendorId == vendorId) {
      ref.read(currentVendorProvider.notifier).setFeatures(features);
    }

    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final vendor = state.firstWhere((v) => v.vendorId == vendorId, orElse: () => current);
    if (user != null && !user.isDemo && api != null) {
      final updated = await api.updateTenantFeatures(
        companyId: vendor.id,
        features: features.toApiMap(),
      );
      final mapped = VendorTenant.fromApi(updated);
      state = [
        for (final v in state)
          if (v.vendorId == vendorId) mapped else v,
      ];
      // Only refresh session features when Super Admin (or user) is *in* that company.
      // Never broadcast one vendor's matrix onto every role / every vendor.
      if (user.companyId == vendor.id) {
        await ref.read(currentUserProvider.notifier).applyBootstrapFeatures(mapped.features);
      }
      if (current.vendorId == vendorId || current.id == vendor.id) {
        ref.read(currentVendorProvider.notifier).replace(mapped);
      }
    } else if (user != null &&
        user.isDemo &&
        (user.vendorId == vendorId || user.companyId == vendor.id)) {
      await ref.read(currentUserProvider.notifier).applyBootstrapFeatures(features);
    }
  }

  Future<void> applyPreset(String vendorId, String preset) async {
    final features = preset == 'mall'
        ? VendorFeatures.mall
        : preset == 'small_shop'
            ? VendorFeatures.smallShop
            : null;
    final vendor = state.firstWhere((v) => v.vendorId == vendorId);
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      final updated = await api.updateTenantFeatures(
        companyId: vendor.id,
        preset: preset,
      );
      final mapped = VendorTenant.fromApi(updated);
      state = [
        for (final v in state)
          if (v.vendorId == vendorId) mapped else v,
      ];
      if (user.companyId == vendor.id) {
        await ref.read(currentUserProvider.notifier).applyBootstrapFeatures(mapped.features);
      }
      final current = ref.read(currentVendorProvider);
      if (current.vendorId == vendorId || current.id == vendor.id) {
        ref.read(currentVendorProvider.notifier).replace(mapped);
      }
      return;
    }
    if (features != null) {
      await updateVendorFeatures(vendorId, features);
      state = [
        for (final v in state)
          if (v.vendorId == vendorId) v.copyWith(preset: preset) else v,
      ];
    }
  }

  void toggleVendorStatus(String vendorId) {
    state = [
      for (final v in state)
        if (v.vendorId == vendorId) v.copyWith(isActive: !v.isActive) else v,
    ];
  }
}

class CurrentVendorNotifier extends Notifier<VendorTenant> {
  @override
  VendorTenant build() {
    final all = ref.watch(vendorsProvider);
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      final match = all.where((v) => v.vendorId == user.vendorId || v.id == user.companyId);
      if (match.isNotEmpty) {
        // Super Admin: keep each tenant's own feature matrix from the list.
        // Overwriting with user.features made every vendor look like HQ.
        if (user.role == UserRole.superAdmin) {
          return match.first;
        }
        // Slot user: session bootstrap is authoritative for their company.
        return match.first.copyWith(features: user.features);
      }
    }
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
    final match = all.firstWhere((v) => v.vendorId == vendorId, orElse: () => state);
    state = match;
  }

  void setFeatures(VendorFeatures features) {
    state = state.copyWith(features: features);
  }

  void replace(VendorTenant vendor) {
    state = vendor;
  }
}
