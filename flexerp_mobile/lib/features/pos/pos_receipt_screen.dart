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
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/vendor_repository.dart';

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
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _result = Map<String, dynamic>.from(widget.checkoutResult);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final orderId = _result['order_id'] as int?;
    final api = ref.read(flexerpApiProvider);
    final user = ref.read(currentUserProvider);
    if (user?.isDemo == true || api == null || orderId == null) {
      setState(() {
        _receipt = {
          'name': _result['name'] ?? 'DEMO/RECEIPT',
          'amount_total': _result['amount_total'] ?? 0,
          'partner_name': 'Walk-in',
          'partner_phone': '',
          'lines': const [],
          'company_name': user?.companyName ?? 'Demo',
        };
        _loading = false;
      });
      return;
    }
    try {
      final receipt = await api.posOrderReceipt(orderId);
      _phoneCtrl.text = receipt['partner_phone']?.toString() ?? '';
      setState(() {
        _receipt = receipt;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendWhatsApp() async {
    final api = ref.read(flexerpApiProvider);
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter customer WhatsApp number (+94…)')),
      );
      return;
    }
    final orderId = _result['order_id'] as int?;
    final invoiceId = _result['invoice_id'] as int? ?? _receipt?['invoice_id'] as int?;
    if (api == null) {
      final text = Uri.encodeComponent(
        'Receipt ${_receipt?['name']} — ${LkFormatters.formatLkr((_receipt?['amount_total'] as num?)?.toDouble() ?? 0)}',
      );
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      await Clipboard.setData(ClipboardData(text: 'https://wa.me/$digits?text=$text'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp link copied (demo / offline)')),
      );
      return;
    }
    final result = await api.whatsappSendInvoice(
      phone: phone,
      moveId: invoiceId,
      posOrderId: invoiceId == null ? orderId : null,
    );
    if (!mounted) return;
    final status = result['status']?.toString() ?? 'unknown';
    final waMe = result['wa_me_url']?.toString();
    if (status == 'not_configured' && waMe != null) {
      await Clipboard.setData(ClipboardData(text: waMe));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp API not configured — wa.me link copied'),
          backgroundColor: FlexColors.warning,
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status == 'sent' ? 'WhatsApp sent' : 'WhatsApp: $status'),
        backgroundColor: status == 'sent' ? FlexColors.success : FlexColors.warning,
      ),
    );
  }

  Future<void> _createInvoice() async {
    final api = ref.read(flexerpApiProvider);
    final features = ref.read(currentVendorFeaturesProvider);
    final orderId = _result['order_id'] as int?;
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
    final invoiceId = _result['invoice_id'] as int? ?? _receipt?['invoice_id'] as int?;
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
    final total = (_receipt?['amount_total'] as num?)?.toDouble() ??
        (_result['amount_total'] as num?)?.toDouble() ??
        0;

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        title: Text('Sale Receipt', style: FlexTypography.headlineMd),
        backgroundColor: FlexColors.surfaceDark,
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
                          const SizedBox(height: 4),
                          Text(_receipt?['name']?.toString() ?? 'Receipt',
                              style: FlexTypography.labelLg),
                          Text('Customer: ${_receipt?['partner_name'] ?? 'Walk-in'}',
                              style: FlexTypography.bodySm),
                          const SizedBox(height: 12),
                          Text(LkFormatters.formatLkr(total),
                              style: FlexTypography.headlineMd.copyWith(color: FlexColors.primaryLight)),
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
                              child: Text('Saved offline — will sync when online',
                                  style: TextStyle(color: FlexColors.warning)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Customer WhatsApp (+94…)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FlexButton(
                      label: 'Send via WhatsApp',
                      icon: Icons.chat,
                      onPressed: _sendWhatsApp,
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
