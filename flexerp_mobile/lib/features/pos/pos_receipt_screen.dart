import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/vendor_repository.dart';
import '../shared/whatsapp_number_sheet.dart';

class PosReceiptScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> checkoutResult;
  final double changeDue;

  const PosReceiptScreen({
    super.key,
    required this.checkoutResult,
    this.changeDue = 0,
  });

  @override
  ConsumerState<PosReceiptScreen> createState() => _PosReceiptScreenState();
}

class _PosReceiptScreenState extends ConsumerState<PosReceiptScreen> {
  Map<String, dynamic>? _receipt;
  late Map<String, dynamic> _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _result = Map<String, dynamic>.from(widget.checkoutResult);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final orderId = parseOdooInt(_result['order_id']) ?? parseOdooInt(_result['id']);
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    if (user?.isDemo == true || api == null || orderId == null) {
      final queued = _result['queued'] == true;
      setState(() {
        _receipt = {
          'name': _result['name'] ?? (queued ? 'PENDING SYNC' : 'DEMO/RECEIPT'),
          'amount_total': _result['amount_total'] ?? 0,
          if (_result['amount_tax'] != null) 'amount_tax': _result['amount_tax'],
          'partner_name': 'Walk-in',
          'partner_phone': '',
          'company_name': user?.companyName ?? 'Demo',
          'company_phone': '',
          'lines': const [],
        };
        _loading = false;
      });
      return;
    }
    try {
      final receipt = await api.posOrderReceipt(orderId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _loading = false;
      });
    } catch (e) {
      debugPrint('FlexERP: receipt fetch failed for order $orderId: $e');
      if (!mounted) return;
      // The sale itself was accepted — fall back to the push response totals.
      setState(() {
        _receipt = {
          'name': _result['name'] ?? 'POS/$orderId',
          'amount_total': _result['amount_total'] ?? 0,
          if (_result['amount_tax'] != null) 'amount_tax': _result['amount_tax'],
          'partner_name': _result['partner_name'] ?? 'Walk-in',
          'lines': const [],
          'company_name': user?.companyName ?? 'FlexERP',
        };
        _error = null;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sale recorded, but receipt details failed to load: ${describeError(e)}')),
      );
    }
  }

  Future<void> _openWhatsApp() async {
    final total = (_receipt?['amount_total'] as num?)?.toDouble() ??
        (_result['amount_total'] as num?)?.toDouble() ??
        0;
    final orderId = parseOdooInt(_result['order_id']) ?? parseOdooInt(_result['id']);
    final invoiceId =
        parseOdooInt(_result['invoice_id']) ?? parseOdooInt(_receipt?['invoice_id']);
    await showWhatsAppNumberSheet(
      context,
      ref,
      title: 'Send receipt',
      prefillPhone: _receipt?['partner_phone']?.toString(),
      storePhone: _receipt?['company_phone']?.toString(),
      customerName: _receipt?['partner_name']?.toString(),
      storeName: _receipt?['company_name']?.toString(),
      moveId: invoiceId,
      posOrderId: invoiceId == null ? orderId : null,
      amountLabel: LkFormatters.formatLkr(total),
    );
  }

  Future<void> _createInvoice() async {
    final api = ref.read(flexerpApiProvider);
    final features = ref.read(currentVendorFeaturesProvider);
    final orderId = parseOdooInt(_result['order_id']);
    if (!features.enableInvoicing || api == null || orderId == null) return;
    try {
      final inv = await api.invoiceCreateFromPos(orderId);
      setState(() {
        _result['invoice_id'] = inv['invoice_id'];
        _result['invoice_name'] = inv['name'];
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ${inv['name']} created'), backgroundColor: FlexColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice failed: $e'), backgroundColor: FlexColors.danger),
      );
    }
  }

  Future<void> _sharePdf() async {
    final api = ref.read(flexerpApiProvider);
    final invoiceId = parseOdooInt(_result['invoice_id']) ?? parseOdooInt(_receipt?['invoice_id']);
    if (api == null || invoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a tax invoice first to share branded PDF')),
      );
      return;
    }
    try {
      final pdf = await api.invoicePdf(invoiceId);
      final b64 = pdf['pdf_base64']?.toString();
      if (b64 == null || b64.isEmpty) throw Exception('Empty PDF');
      final bytes = base64Decode(b64);
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: 'PDF ${pdf['filename']} ready (${bytes.length} bytes)'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF fetched (web share limited — filename copied)')),
        );
        return;
      }
      final file = File('${Directory.systemTemp.path}/${pdf['filename'] ?? 'invoice.pdf'}');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Branded PDF saved: ${file.path}'), backgroundColor: FlexColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF error: $e'), backgroundColor: FlexColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(currentVendorFeaturesProvider);
    // Server totals (pos/order or receipt) are authoritative for live sales.
    final total = (_receipt?['amount_total'] as num?)?.toDouble() ??
        (_result['amount_total'] as num?)?.toDouble() ??
        0;
    final tax = (_receipt?['amount_tax'] as num?)?.toDouble() ??
        (_result['amount_tax'] as num?)?.toDouble();
    final companyPhone = _receipt?['company_phone']?.toString() ?? '';

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        title: Text('Sale Receipt', style: FlexTypography.headlineMd),
        backgroundColor: FlexColors.surfaceDark,
        actions: [
          IconButton(
            tooltip: 'WhatsApp receipt',
            icon: const Icon(Icons.chat),
            onPressed: _loading || _error != null ? null : _openWhatsApp,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: FlexTypography.bodyMd))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FlexCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_receipt?['company_name']?.toString() ?? 'FlexERP',
                              style: FlexTypography.headlineSm),
                          if (companyPhone.isNotEmpty)
                            Text(
                              LkFormatters.formatLkPhone(companyPhone),
                              style: FlexTypography.bodySm,
                            ),
                          const SizedBox(height: 4),
                          Text(_receipt?['name']?.toString() ?? 'Receipt',
                              style: FlexTypography.labelLg),
                          Text(
                            'Customer: ${_receipt?['partner_name'] ?? 'Walk-in'}'
                            '${(_receipt?['partner_phone']?.toString().isNotEmpty ?? false) ? ' · ${LkFormatters.formatLkPhone(_receipt!['partner_phone'].toString())}' : ''}',
                            style: FlexTypography.bodySm,
                          ),
                          const SizedBox(height: 12),
                          Text(LkFormatters.formatLkr(total),
                              style: FlexTypography.headlineMd.copyWith(color: FlexColors.primaryLight)),
                          if (tax != null)
                            Text('Incl. taxes: ${LkFormatters.formatLkr(tax)}',
                                style: FlexTypography.bodySm),
                          if (widget.changeDue > 0)
                            Text('Change: ${LkFormatters.formatLkr(widget.changeDue)}',
                                style: FlexTypography.bodySm),
                          if (_result['invoice_name'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Invoice: ${_result['invoice_name']}',
                                  style: FlexTypography.labelMd),
                            ),
                          if (_result['queued'] == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'QUEUED OFFLINE – PENDING SYNC\n'
                                'Not yet recorded in Odoo. It will be sent automatically when the '
                                'connection returns (see Profile → Offline sync). Total shown is an estimate.',
                                style: TextStyle(color: FlexColors.warning, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FlexButton(
                      label: 'Send via WhatsApp',
                      icon: Icons.chat,
                      onPressed: _openWhatsApp,
                    ),
                    const SizedBox(height: 8),
                    if (features.enableInvoicing)
                      FlexButton(
                        label: 'Create Tax Invoice',
                        icon: Icons.receipt_long,
                        variant: FlexButtonVariant.secondary,
                        onPressed: _createInvoice,
                      ),
                    if (features.enableInvoicing) const SizedBox(height: 8),
                    if (features.enableInvoicing)
                      FlexButton(
                        label: 'Branded PDF (watermark + seal)',
                        icon: Icons.picture_as_pdf,
                        variant: FlexButtonVariant.secondary,
                        onPressed: _sharePdf,
                      ),
                    const SizedBox(height: 16),
                    FlexButton(
                      label: 'Done — New Sale',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
    );
  }
}
