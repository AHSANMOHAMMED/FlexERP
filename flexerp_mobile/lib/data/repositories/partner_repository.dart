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

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final client = ref.read(odooClientProvider);
    if (user == null || user.isDemo) return;
    if (client == null || !client.isAuthenticated) {
      throw Exception('Not authenticated');
    }

    final results = await client.searchRead(
      model: 'res.partner',
      domain: [
        ['customer_rank', '>', 0]
      ],
      fields: [
        'id',
        'name',
        'email',
        'phone',
        'city',
        'street',
        'vat',
        'credit_limit',
        'credit',
      ],
      limit: 50,
    );

    state = results.map((item) {
      return CustomerPartner(
        id: (item['id'] as num?)?.toInt() ?? 0,
        name: item['name']?.toString() ?? 'Unnamed Partner',
        email: item['email']?.toString() ?? 'No email',
        phone: item['phone']?.toString() ?? 'No phone',
        city: item['city']?.toString() ?? 'Sri Lanka',
        address: item['street']?.toString() ?? 'Colombo, Sri Lanka',
        vatOrTin: item['vat']?.toString() ?? 'N/A',
        creditLimit: (item['credit_limit'] as num?)?.toDouble() ?? 1000000.0,
        totalReceivable: (item['credit'] as num?)?.toDouble() ?? 0.0,
        isCustomer: true,
      );
    }).toList();
  }

  Future<void> addPartner(CustomerPartner partner) async {
    state = [partner, ...state];
    final user = ref.read(currentUserProvider);
    final client = ref.read(odooClientProvider);
    if (user == null || user.isDemo || client == null) return;
    final id = await client.create(
      model: 'res.partner',
      values: {
        'name': partner.name,
        'email': partner.email,
        'phone': partner.phone,
        'city': partner.city,
        'street': partner.address,
        'vat': partner.vatOrTin,
        'customer_rank': 1,
      },
    );
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
