import 'odoo_client.dart';

/// Typed client for `/flexerp/mobile/*` facades.
class FlexerpMobileApi {
  final OdooClient client;

  FlexerpMobileApi(this.client);

  Future<Map<String, dynamic>> bootstrap({int? companyId, String? appVersion}) async {
    final res = await client.callRoute('/flexerp/mobile/bootstrap', {
      if (companyId != null) 'company_id': companyId,
      if (appVersion != null) 'app_version': appVersion,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> switchCompany(int companyId) async {
    final res = await client.callRoute('/flexerp/mobile/company/switch', {
      'company_id': companyId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- Admin / tenants ----
  Future<List<Map<String, dynamic>>> listTenants() async {
    final res = await client.callRoute('/flexerp/mobile/admin/tenants', {});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> updateTenantFeatures({
    required int companyId,
    Map<String, bool>? features,
    String? preset,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/admin/tenant/features', {
      'company_id': companyId,
      if (features != null) 'features': features,
      if (preset != null) 'preset': preset,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> provisionTenant(Map<String, dynamic> vals) async {
    final res = await client.callRoute('/flexerp/mobile/admin/tenant/provision', vals);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> deactivateTenant(int companyId) async {
    final res = await client.callRoute('/flexerp/mobile/admin/tenant/deactivate', {
      'company_id': companyId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> listTenantUsers(int companyId) async {
    final res = await client.callRoute('/flexerp/mobile/admin/users', {
      'company_id': companyId,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createTenantUser({
    required int companyId,
    required String name,
    required String login,
    String role = 'posCashier',
    String? password,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/admin/users/create', {
      'company_id': companyId,
      'name': name,
      'login': login,
      'role': role,
      if (password != null) 'password': password,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> setTenantUserActive(int userId, {required bool active}) async {
    final res = await client.callRoute('/flexerp/mobile/admin/users/active', {
      'user_id': userId,
      'active': active,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> listApprovals({int limit = 40}) async {
    final res = await client.callRoute('/flexerp/mobile/admin/approvals', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---- Ops ----
  Future<Map<String, dynamic>> opsOverview() async {
    final res = await client.callRoute('/flexerp/mobile/ops/overview', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> opsWake() async {
    final res = await client.callRoute('/flexerp/mobile/ops/wake', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> opsRestart() async {
    final res = await client.callRoute('/flexerp/mobile/ops/restart', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> opsStop() async {
    final res = await client.callRoute('/flexerp/mobile/ops/stop', {});
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> opsPool() async {
    final res = await client.callRoute('/flexerp/mobile/ops/pool', {});
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- POS ----
  Future<List<Map<String, dynamic>>> posConfigs() async {
    final res = await client.callRoute('/flexerp/mobile/pos/configs', {});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> posOpenSession(int configId) async {
    final res = await client.callRoute('/flexerp/mobile/pos/session/open', {
      'config_id': configId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> posCloseSession(int sessionId) async {
    final res = await client.callRoute('/flexerp/mobile/pos/session/close', {
      'session_id': sessionId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> posProducts({int? configId, int limit = 500}) async {
    final res = await client.callRoute(
      '/flexerp/mobile/pos/products',
      {
        if (configId != null) 'config_id': configId,
        'limit': limit,
      },
      'pos/products:${configId ?? 0}:$limit',
    );
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> posPushOrder(Map<String, dynamic> payload) async {
    final res = await client.callRoute('/flexerp/mobile/pos/order', payload);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> posOrderReceipt(int orderId) async {
    final res = await client.callRoute('/flexerp/mobile/pos/order/receipt', {
      'order_id': orderId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> posOrders({int limit = 40}) async {
    final res = await client.callRoute('/flexerp/mobile/pos/orders', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---- Partners / catalog / purchase ----
  Future<List<Map<String, dynamic>>> partners({
    int limit = 80,
    String? search,
    String partnerType = 'customer',
  }) async {
    final res = await client.callRoute(
      '/flexerp/mobile/partners',
      {
        'limit': limit,
        if (search != null) 'search': search,
        'partner_type': partnerType,
      },
      search == null || search.isEmpty ? 'partners:$partnerType:$limit' : null,
    );
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> partnerCreate(Map<String, dynamic> vals) async {
    client.invalidateCachePrefix('partners');
    final res = await client.callRoute('/flexerp/mobile/partners/create', vals);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> products({
    int limit = 200,
    String? search,
    int? categoryId,
  }) async {
    final res = await client.callRoute(
      '/flexerp/mobile/products',
      {
        'limit': limit,
        if (search != null) 'search': search,
        if (categoryId != null) 'category_id': categoryId,
      },
      (search == null || search.isEmpty) && categoryId == null ? 'products:$limit' : null,
    );
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> productCategories({int limit = 80}) async {
    final res = await client.callRoute('/flexerp/mobile/products/categories', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> purchaseOrders({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/purchase/orders', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> purchaseCreateOrder({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    bool confirm = false,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/purchase/order/create', {
      'partner_id': partnerId,
      'lines': lines,
      'confirm': confirm,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> crmStages() async {
    final res = await client.callRoute('/flexerp/mobile/crm/stages', {});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> hrLeaveTypes() async {
    final res = await client.callRoute('/flexerp/mobile/hr/leave/types', {});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> salesOrderDetail(int orderId) async {
    final res = await client.callRoute('/flexerp/mobile/sales/order/detail', {
      'order_id': orderId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> stockLocations({int limit = 40}) async {
    final res = await client.callRoute('/flexerp/mobile/stock/locations', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ---- Stock ----
  Future<Map<String, dynamic>?> stockBarcode(String barcode) async {
    final res = await client.callRoute('/flexerp/mobile/stock/barcode', {
      'barcode': barcode,
    });
    if (res == null || res == false) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> stockQuants({int limit = 80, String? search}) async {
    final res = await client.callRoute('/flexerp/mobile/stock/quants', {
      'limit': limit,
      if (search != null) 'search': search,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> stockPickings({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/stock/pickings', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> stockPicking(int pickingId) async {
    final res = await client.callRoute('/flexerp/mobile/stock/picking', {
      'picking_id': pickingId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> validatePicking(int pickingId) async {
    final res = await client.callRoute('/flexerp/mobile/stock/picking/validate', {
      'picking_id': pickingId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> stockAdjust({
    required int productId,
    required double quantityDelta,
    int? locationId,
    String? reason,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/stock/adjust', {
      'product_id': productId,
      'quantity_delta': quantityDelta,
      if (locationId != null) 'location_id': locationId,
      if (reason != null) 'reason': reason,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- Sales / CRM ----
  Future<List<Map<String, dynamic>>> salesOrders({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/sales/orders', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> salesCreateOrder({
    required int partnerId,
    required List<Map<String, dynamic>> lines,
    bool confirm = false,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/sales/order/create', {
      'partner_id': partnerId,
      'lines': lines,
      'confirm': confirm,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> salesConfirmOrder(int orderId) async {
    final res = await client.callRoute('/flexerp/mobile/sales/order/confirm', {
      'order_id': orderId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> crmLeads({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/crm/leads', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> crmCreateLead({
    required String name,
    double expectedRevenue = 0,
    String? phone,
    String? email,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/crm/lead/create', {
      'name': name,
      'expected_revenue': expectedRevenue,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> crmSetStage({required int leadId, required int stageId}) async {
    final res = await client.callRoute('/flexerp/mobile/crm/lead/stage', {
      'lead_id': leadId,
      'stage_id': stageId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- Accounting ----
  Future<List<Map<String, dynamic>>> accountingInvoices({
    String moveType = 'out_invoice',
    int limit = 50,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/accounting/invoices', {
      'move_type': moveType,
      'limit': limit,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> accountingJournals() async {
    final res = await client.callRoute('/flexerp/mobile/accounting/journals', {});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> registerPayment({
    required int moveId,
    double? amount,
    int? journalId,
    String? paymentDate,
    String? memo,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/payment/register', {
      'move_id': moveId,
      if (amount != null) 'amount': amount,
      if (journalId != null) 'journal_id': journalId,
      if (paymentDate != null) 'payment_date': paymentDate,
      if (memo != null) 'memo': memo,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> invoiceDetail(int moveId) async {
    final res = await client.callRoute('/flexerp/mobile/accounting/invoice/detail', {
      'move_id': moveId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> invoiceCreateFromPos(int orderId) async {
    final res = await client.callRoute('/flexerp/mobile/accounting/invoice/create_from_pos', {
      'order_id': orderId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> invoicePdf(int moveId) async {
    final res = await client.callRoute('/flexerp/mobile/invoice/pdf', {
      'move_id': moveId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> whatsappSendInvoice({
    required String phone,
    int? moveId,
    int? posOrderId,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/invoice/whatsapp/send', {
      'phone': phone,
      if (moveId != null) 'move_id': moveId,
      if (posOrderId != null) 'pos_order_id': posOrderId,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> paymentLinkCreate({
    required double amount,
    String? orderRef,
    String? returnUrl,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/payment/link/create', {
      'amount': amount,
      if (orderRef != null) 'order_ref': orderRef,
      if (returnUrl != null) 'return_url': returnUrl,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> paymentLinkStatus(String reference, {bool markPaid = false}) async {
    final res = await client.callRoute('/flexerp/mobile/payment/link/status', {
      'reference': reference,
      'mark_paid': markPaid,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> livePoll({int sinceId = 0, int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/live/poll', {
      'since_id': sinceId,
      'limit': limit,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- HR ----
  Future<List<Map<String, dynamic>>> hrEmployees({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/hr/employees', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> hrLeaves({int limit = 50}) async {
    final res = await client.callRoute('/flexerp/mobile/hr/leaves', {'limit': limit});
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> hrSubmitLeave({
    required int holidayStatusId,
    required String dateFrom,
    required String dateTo,
    String? name,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/hr/leave/submit', {
      'holiday_status_id': holidayStatusId,
      'date_from': dateFrom,
      'date_to': dateTo,
      if (name != null) 'name': name,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> hrAttendance({
    required bool checkIn,
    double? latitude,
    double? longitude,
  }) async {
    final res = await client.callRoute('/flexerp/mobile/hr/attendance', {
      'check_in': checkIn,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> executiveKpis() async {
    final res = await client.callRoute('/flexerp/mobile/executive/kpis', {});
    return Map<String, dynamic>.from(res as Map);
  }

  // ---- Website shop ----
  Future<List<Map<String, dynamic>>> shopCatalog({int limit = 40, String? search}) async {
    final res = await client.callRoute('/flexerp/mobile/shop/catalog', {
      'limit': limit,
      if (search != null) 'search': search,
    });
    if (res is List) {
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> shopCart() async {
    final res = await client.callRoute('/flexerp/mobile/shop/cart', {});
    return Map<String, dynamic>.from(res as Map? ?? {});
  }

  Future<Map<String, dynamic>> shopCartAdd({required int productId, double qty = 1}) async {
    final res = await client.callRoute('/flexerp/mobile/shop/cart/add', {
      'product_id': productId,
      'qty': qty,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> shopCartUpdate({required int lineId, required double qty}) async {
    final res = await client.callRoute('/flexerp/mobile/shop/cart/update', {
      'line_id': lineId,
      'qty': qty,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> shopCheckout() async {
    final res = await client.callRoute('/flexerp/mobile/shop/checkout', {});
    return Map<String, dynamic>.from(res as Map);
  }
}
