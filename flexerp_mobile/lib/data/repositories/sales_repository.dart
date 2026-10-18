import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crm_lead.dart';
import '../models/sale_order.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

final salesErrorProvider = NotifierProvider<_SalesErrorNotifier, String?>(
  _SalesErrorNotifier.new,
);

class _SalesErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setError(String? v) => state = v;
}

class CrmLeadsNotifier extends Notifier<List<CrmLead>> {
  final Map<String, int> _stageIds = {};

  List<String> get stageNames {
    if (_stageIds.isEmpty) {
      return const ['New', 'Qualified', 'Proposition', 'Won'];
    }
    final names = _stageIds.keys.toList()
      ..sort((a, b) => (_stageIds[a] ?? 0).compareTo(_stageIds[b] ?? 0));
    return names;
  }

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
      _stageIds.clear();
      final stages = await api.crmStages();
      for (final s in stages) {
        final name = s['name']?.toString();
        final id = s['id'];
        if (name != null && id is int) _stageIds[name] = id;
      }
      final records = await api.crmLeads();
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
      ref.read(salesErrorProvider.notifier).setError(null);
    } catch (e) {
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  Future<void> updateLeadStage(int id, String newStage) async {
    final previous = state;
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
    } catch (e) {
      state = previous;
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
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
    } catch (e) {
      state = state.where((l) => l.id != lead.id).toList();
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
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
          partnerPhone: '',
          paymentTerms: '30 Days Net',
          creditLimit: 0,
          currentCreditUsed: 0,
          lines: const [],
          globalDiscountPercent: 0,
          state: rec['state']?.toString() ?? 'draft',
          dateOrder: rec['date_order'] != null
              ? DateTime.tryParse(rec['date_order'].toString()) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
      ref.read(salesErrorProvider.notifier).setError(null);
    } catch (e) {
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  Future<void> confirmOrder(int id) async {
    final previous = state;
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
    } catch (e) {
      state = previous;
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }

  Future<SaleOrder> addOrder(SaleOrder order, {int? partnerId}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);

    if (user == null || user.isDemo || api == null) {
      state = [order, ...state];
      return order;
    }

    if (order.lines.isEmpty) {
      throw Exception('Add at least one product line.');
    }
    for (final line in order.lines) {
      if (line.productId <= 0) {
        throw Exception('Invalid product on line ${line.productName}. Pick a live product.');
      }
    }

    var resolvedPartnerId = partnerId;
    if (resolvedPartnerId == null || resolvedPartnerId <= 0) {
      final partners = await api.partners(search: order.partnerName, limit: 5);
      if (partners.isNotEmpty) {
        resolvedPartnerId = partners.first['id'] as int?;
      } else {
        final createdPartner = await api.partnerCreate({
          'name': order.partnerName,
          'phone': order.partnerPhone,
          'customer_rank': 1,
        });
        resolvedPartnerId = createdPartner['id'] as int?;
      }
    }
    if (resolvedPartnerId == null || resolvedPartnerId <= 0) {
      throw Exception('Could not resolve or create customer partner.');
    }

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
        partnerId: resolvedPartnerId,
        lines: lines,
        confirm: order.state == 'sale',
      );
      final id = created['id'] as int? ?? 0;
      final saved = SaleOrder(
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
      );
      state = [saved, ...state.where((o) => o.id != id)];
      ref.read(salesErrorProvider.notifier).setError(null);
      return saved;
    } catch (e) {
      ref.read(salesErrorProvider.notifier).setError(e.toString());
      rethrow;
    }
  }
}

final saleOrdersProvider = NotifierProvider<SaleOrdersNotifier, List<SaleOrder>>(SaleOrdersNotifier.new);
