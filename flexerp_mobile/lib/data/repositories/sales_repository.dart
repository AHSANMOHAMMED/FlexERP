import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crm_lead.dart';
import '../models/sale_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

class CrmLeadsNotifier extends Notifier<List<CrmLead>> {
  final Map<String, int> _stageIds = {};

  @override
  List<CrmLead> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.crmLeads);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final records = await api.crmLeads();
      _stageIds.clear();
      state = records.map((rec) {
        final stage = rec['stage']?.toString() ?? 'New';
        final stageId = rec['stage_id'];
        if (stageId is int && stageId > 0) {
          _stageIds[stage] = stageId;
        }
        return CrmLead(
          id: rec['id'] as int? ?? 0,
          name: rec['name']?.toString() ?? 'Opportunity',
          partnerName: rec['partner_name']?.toString() ?? 'Walk-in Prospect',
          expectedRevenue: (rec['expected_revenue'] as num?)?.toDouble() ?? 0.0,
          stage: stage,
          priority: int.tryParse(rec['priority']?.toString() ?? '1') ?? 1,
          tags: const ['Direct Sales'],
          phone: rec['phone']?.toString() ?? '',
          expectedClosing: '30 Days',
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> updateLeadStage(int id, String newStage) async {
    state = [
      for (final lead in state)
        if (lead.id == id) lead.copyWith(stage: newStage) else lead
    ];
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final stageId = _stageIds[newStage];
    if (user == null || user.isDemo || api == null || stageId == null) return;
    try {
      await api.crmSetStage(leadId: id, stageId: stageId);
    } catch (_) {}
  }

  Future<void> addLead(CrmLead lead) async {
    state = [lead, ...state];
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final created = await api.crmCreateLead(
        name: lead.name,
        expectedRevenue: lead.expectedRevenue,
        phone: lead.phone,
      );
      final newId = created['id'] as int? ?? lead.id;
      state = [
        for (final l in state)
          if (l.name == lead.name && l.id == lead.id) l.copyWith(id: newId) else l
      ];
    } catch (_) {}
  }
}

final crmLeadsProvider = NotifierProvider<CrmLeadsNotifier, List<CrmLead>>(CrmLeadsNotifier.new);

class SaleOrdersNotifier extends Notifier<List<SaleOrder>> {
  @override
  List<SaleOrder> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.saleOrders);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      final records = await api.salesOrders();
      state = records.map((rec) {
        return SaleOrder(
          id: rec['id'] as int? ?? 0,
          name: rec['name']?.toString() ?? 'SO-000',
          partnerName: rec['partner_name']?.toString() ?? 'Customer',
          partnerPhone: '+94 11 200 0000',
          paymentTerms: '30 Days Net',
          creditLimit: 2000000.0,
          currentCreditUsed: 500000.0,
          lines: const [],
          globalDiscountPercent: 0,
          state: rec['state']?.toString() ?? 'draft',
          dateOrder: rec['date_order'] != null
              ? DateTime.tryParse(rec['date_order'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> confirmOrder(int id) async {
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
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      await api.salesConfirmOrder(id);
    } catch (_) {}
  }

  Future<void> addOrder(SaleOrder order) async {
    state = [order, ...state];
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    final client = ref.read(authRepositoryProvider).activeClient;
    if (user == null || user.isDemo || api == null || client == null) return;

    final partners = await client.searchRead(
      model: 'res.partner',
      domain: [
        ['name', 'ilike', order.partnerName]
      ],
      fields: ['id'],
      limit: 1,
    );
    if (partners.isEmpty) return;
    final partnerId = partners.first['id'] as int;
    final lines = order.lines
        .map((line) => {
              'product_id': line.productId,
              'qty': line.quantity,
              'price_unit': line.unitPrice,
              'name': line.productName,
            })
        .toList();
    try {
      final created = await api.salesCreateOrder(
        partnerId: partnerId,
        lines: lines,
        confirm: order.state == 'sale',
      );
      final id = created['id'] as int? ?? 0;
      if (id > 0) {
        state = [
          for (final o in state)
            if (o.name == order.name)
              SaleOrder(
                id: id,
                name: created['name']?.toString() ?? order.name,
                partnerName: order.partnerName,
                partnerPhone: order.partnerPhone,
                paymentTerms: order.paymentTerms,
                creditLimit: order.creditLimit,
                currentCreditUsed: order.currentCreditUsed,
                lines: order.lines,
                globalDiscountPercent: order.globalDiscountPercent,
                state: created['state']?.toString() ?? order.state,
                dateOrder: order.dateOrder,
              )
            else
              o
        ];
      }
    } catch (_) {}
  }
}

final saleOrdersProvider = NotifierProvider<SaleOrdersNotifier, List<SaleOrder>>(SaleOrdersNotifier.new);
