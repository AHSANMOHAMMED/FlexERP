import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crm_lead.dart';
import '../models/sale_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

class CrmLeadsNotifier extends Notifier<List<CrmLead>> {
  @override
  List<CrmLead> build() {
    return List.from(MockSriLankaDataService.crmLeads);
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client == null) return;
    try {
      final records = await client.searchRead(
        model: 'crm.lead',
        domain: [],
        fields: ['id', 'name', 'partner_id', 'expected_revenue', 'stage_id', 'priority', 'phone', 'email_from'],
        limit: 50,
      );
      if (records.isNotEmpty) {
        state = records.map((rec) {
          final partner = rec['partner_id'];
          final partnerName = partner is List && partner.length > 1 ? partner[1].toString() : 'Walk-in Prospect';
          final stage = rec['stage_id'];
          final stageName = stage is List && stage.length > 1 ? stage[1].toString() : 'New';
          return CrmLead(
            id: rec['id'] as int,
            name: rec['name'] as String? ?? 'Opportunity',
            partnerName: partnerName,
            expectedRevenue: (rec['expected_revenue'] as num?)?.toDouble() ?? 0.0,
            stage: stageName,
            priority: int.tryParse(rec['priority']?.toString() ?? '1') ?? 1,
            tags: const ['Direct Sales'],
            phone: rec['phone']?.toString() ?? '+94 77 123 4567',
            expectedClosing: '30 Days',
          );
        }).toList();
      }
    } catch (_) {
      // Gracefully maintain offline state
    }
  }

  void updateLeadStage(int id, String newStage) {
    state = [
      for (final lead in state)
        if (lead.id == id) lead.copyWith(stage: newStage) else lead
    ];
  }

  void addLead(CrmLead lead) {
    state = [lead, ...state];
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client != null) {
      client.create(
        model: 'crm.lead',
        values: {
          'name': lead.name,
          'expected_revenue': lead.expectedRevenue,
        },
      ).catchError((_) => 0);
    }
  }
}

final crmLeadsProvider = NotifierProvider<CrmLeadsNotifier, List<CrmLead>>(CrmLeadsNotifier.new);

class SaleOrdersNotifier extends Notifier<List<SaleOrder>> {
  @override
  List<SaleOrder> build() {
    return List.from(MockSriLankaDataService.saleOrders);
  }

  Future<void> syncFromOdoo() async {
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client == null) return;
    try {
      final records = await client.searchRead(
        model: 'sale.order',
        domain: [],
        fields: ['id', 'name', 'partner_id', 'amount_total', 'state', 'date_order'],
        limit: 50,
      );
      if (records.isNotEmpty) {
        state = records.map((rec) {
          final partner = rec['partner_id'];
          final partnerName = partner is List && partner.length > 1 ? partner[1].toString() : 'Customer';
          return SaleOrder(
            id: rec['id'] as int,
            name: rec['name'] as String? ?? 'SO-000',
            partnerName: partnerName,
            partnerPhone: '+94 11 200 0000',
            paymentTerms: '30 Days Net',
            creditLimit: 2000000.0,
            currentCreditUsed: 500000.0,
            lines: [],
            globalDiscountPercent: 0,
            state: rec['state']?.toString() ?? 'draft',
            dateOrder: rec['date_order'] != null
                ? DateTime.tryParse(rec['date_order'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();
      }
    } catch (_) {
      // Gracefully maintain offline state
    }
  }

  void confirmOrder(int id) {
    state = [
      for (final order in state)
        if (order.id == id)
          SaleOrder(
            id: order.id,
            name: order.name,
            partnerName: order.partnerName,
            partnerPhone: order.partnerPhone,
            paymentTerms: order.paymentTerms,
            creditLimit: order.creditLimit,
            currentCreditUsed: order.currentCreditUsed + order.totalAmount,
            lines: order.lines,
            globalDiscountPercent: order.globalDiscountPercent,
            state: 'sale',
            dateOrder: order.dateOrder,
          )
        else
          order
    ];
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client != null) {
      client.callButton(model: 'sale.order', method: 'action_confirm', ids: [id]).catchError((_) => null);
    }
  }

  void addOrder(SaleOrder order) {
    state = [order, ...state];
    final client = ref.read(authRepositoryProvider).activeClient;
    if (client != null) {
      client.create(
        model: 'sale.order',
        values: {
          'name': order.name,
        },
      ).catchError((_) => 0);
    }
  }
}

final saleOrdersProvider = NotifierProvider<SaleOrdersNotifier, List<SaleOrder>>(SaleOrdersNotifier.new);
