import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/customer_partner.dart';
import 'auth_repository.dart';

class PartnersNotifier extends Notifier<List<CustomerPartner>> {
  @override
  List<CustomerPartner> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return MockSriLankaDataService.mockPartners;
  }

  Future<void> syncFromOdoo({String partnerType = 'customer', String? search}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;

    final results = await api.partners(
      partnerType: partnerType,
      search: search,
    );
    state = results.map((item) {
      return CustomerPartner(
        id: (item['id'] as num?)?.toInt() ?? 0,
        name: item['name']?.toString() ?? 'Unnamed Partner',
        email: item['email']?.toString() ?? '',
        phone: item['phone']?.toString() ?? '',
        city: item['city']?.toString() ?? '',
        address: item['street']?.toString() ?? '',
        vatOrTin: item['vat']?.toString() ?? '',
        creditLimit: (item['credit_limit'] as num?)?.toDouble() ?? 0.0,
        totalReceivable: (item['credit'] as num?)?.toDouble() ?? 0.0,
        isCustomer: (item['customer_rank'] as num?)?.toInt() != null
            ? ((item['customer_rank'] as num).toInt() > 0)
            : partnerType == 'customer',
      );
    }).toList();
  }

  Future<void> addPartner(CustomerPartner partner) async {
    state = [partner, ...state];
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    final created = await api.partnerCreate({
      'name': partner.name,
      'email': partner.email,
      'phone': partner.phone,
      'city': partner.city,
      'street': partner.address,
      'vat': partner.vatOrTin,
      'customer_rank': 1,
    });
    final id = (created['id'] as num?)?.toInt() ?? 0;
    if (id > 0) {
      state = [
        for (final p in state)
          if (p.name == partner.name && p.id == partner.id)
            CustomerPartner(
              id: id,
              name: partner.name,
              email: partner.email,
              phone: partner.phone,
              city: partner.city,
              address: partner.address,
              vatOrTin: partner.vatOrTin,
              creditLimit: partner.creditLimit,
              totalReceivable: partner.totalReceivable,
              isCustomer: true,
            )
          else
            p
      ];
    }
  }
}

final partnersProvider = NotifierProvider<PartnersNotifier, List<CustomerPartner>>(
  PartnersNotifier.new,
);
