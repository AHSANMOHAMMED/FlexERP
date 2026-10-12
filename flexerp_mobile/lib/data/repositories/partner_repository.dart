import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../models/customer_partner.dart';
import 'auth_repository.dart';

class PartnersNotifier extends Notifier<List<CustomerPartner>> {
  @override
  List<CustomerPartner> build() {
    return MockSriLankaDataService.mockPartners;
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(odooClientProvider);
    if (client == null || !client.isAuthenticated) {
      // Offline/sandbox: maintain loaded mock data
      return;
    }

    try {
      final results = await client.searchRead(
        model: 'res.partner',
        domain: [
          ['is_company', '=', true]
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

      if (results.isNotEmpty) {
        final partners = results.map((item) {
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

        state = partners;
      }
    } catch (_) {
      // Keep sandbox fallback on connection/auth issue
    }
  }

  void addPartner(CustomerPartner partner) {
    state = [partner, ...state];
  }
}

final partnersProvider = NotifierProvider<PartnersNotifier, List<CustomerPartner>>(
  PartnersNotifier.new,
);
