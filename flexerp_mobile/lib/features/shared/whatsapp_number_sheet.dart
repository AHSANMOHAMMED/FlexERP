import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_button.dart';
import '../../data/repositories/auth_repository.dart';

const _recentPhonesKey = 'flexerp_wa_recent_phones_v1';

/// Choose WhatsApp recipient number, then send invoice/receipt (or copy wa.me).
Future<void> showWhatsAppNumberSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? prefillPhone,
  String? storePhone,
  String? customerName,
  String? storeName,
  int? moveId,
  int? posOrderId,
  String? amountLabel,
}) async {
  final phoneCtrl = TextEditingController(
    text: prefillPhone != null && prefillPhone.isNotEmpty
        ? LkFormatters.formatLkPhone(prefillPhone)
        : '',
  );
  final prefs = await SharedPreferences.getInstance();
  var recent = prefs.getStringList(_recentPhonesKey) ?? <String>[];

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlexColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FlexTypography.headlineMd),
                const SizedBox(height: 6),
                Text(
                  [
                    if (storeName != null && storeName.isNotEmpty) 'Store: $storeName',
                    if (customerName != null && customerName.isNotEmpty) 'Customer: $customerName',
                    if (amountLabel != null && amountLabel.isNotEmpty) amountLabel,
                  ].join(' · '),
                  style: FlexTypography.bodySm,
                ),
                if (storePhone != null && storePhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Store contact: ${LkFormatters.formatLkPhone(storePhone)}',
                    style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number (+94…)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.chat),
                  ),
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Recent', style: FlexTypography.labelSm),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recent.take(5).map((p) {
                      return ActionChip(
                        label: Text(LkFormatters.formatLkPhone(p), style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          phoneCtrl.text = LkFormatters.formatLkPhone(p);
                          setSheet(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                FlexButton(
                  label: 'Send receipt via WhatsApp',
                  icon: Icons.send,
                  height: 48,
                  onPressed: () async {
                    final raw = phoneCtrl.text.trim();
                    if (raw.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a WhatsApp number'),
                          backgroundColor: FlexColors.danger,
                        ),
                      );
                      return;
                    }
                    final normalized = LkFormatters.formatLkPhone(raw);
                    final digits = raw.replaceAll(RegExp(r'\D'), '');
                    final api = ref.read(flexerpApiProvider);
                    final user = ref.read(currentUserProvider);

                    Future<void> remember() async {
                      final list = [
                        digits,
                        ...recent.where((e) => e != digits),
                      ].take(5).toList();
                      await prefs.setStringList(_recentPhonesKey, list);
                    }

                    if (api == null || user?.isDemo == true) {
                      final text = Uri.encodeComponent(
                        [
                          title,
                          if (storeName != null) 'From: $storeName',
                          if (customerName != null) 'To: $customerName',
                          if (amountLabel != null) amountLabel,
                        ].join('\n'),
                      );
                      final wa = 'https://wa.me/$digits?text=$text';
                      await Clipboard.setData(ClipboardData(text: wa));
                      await remember();
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WhatsApp link copied (demo / offline)')),
                      );
                      return;
                    }

                    try {
                      final result = await api.whatsappSendInvoice(
                        phone: digits.startsWith('0') ? '94${digits.substring(1)}' : digits,
                        moveId: moveId,
                        posOrderId: moveId == null ? posOrderId : null,
                      );
                      await remember();
                      if (!ctx.mounted) return;
                      final status = result['status']?.toString() ?? 'unknown';
                      final waMe = result['wa_me_url']?.toString();
                      Navigator.pop(ctx);
                      if (status == 'not_configured' && waMe != null) {
                        await Clipboard.setData(ClipboardData(text: waMe));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('WhatsApp API not configured — link for $normalized copied'),
                            backgroundColor: FlexColors.warning,
                          ),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            status == 'sent' ? 'WhatsApp sent to $normalized' : 'WhatsApp: $status',
                          ),
                          backgroundColor:
                              status == 'sent' ? FlexColors.success : FlexColors.warning,
                        ),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('WhatsApp failed: $e'),
                          backgroundColor: FlexColors.danger,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
  phoneCtrl.dispose();
}
