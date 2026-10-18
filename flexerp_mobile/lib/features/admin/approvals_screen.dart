import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_button.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/localization/lk_formatters.dart';
import '../../data/repositories/admin_repository.dart';

/// Standalone approvals list for roles that do not embed Admin Hub.
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_sync);
  }

  Future<void> _sync() async {
    setState(() => _error = null);
    try {
      await ref.read(pendingApprovalsProvider.notifier).syncFromServer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final approvals = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Approvals',
        subtitle: 'Pending authorizations',
        showCompanySwitcher: false,
        onSync: _sync,
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: _sync,
        child: approvals.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.verified_outlined,
                    size: 48,
                    color: FlexColors.textSecondaryDark.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error != null ? 'Sync failed' : 'No pending approvals',
                    textAlign: TextAlign.center,
                    style: FlexTypography.bodyMd,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: FlexColors.danger, fontSize: 12),
                      ),
                    ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: approvals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final approval = approvals[index];
                  return FlexCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FlexBadge(text: approval.type, variant: FlexBadgeVariant.warning),
                            Text(
                              LkFormatters.formatLkr(approval.amount),
                              style: FlexTypography.codeNum.copyWith(color: FlexColors.primaryLight),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${approval.reference} · ${approval.customerOrVendor}',
                            style: FlexTypography.labelLg),
                        const SizedBox(height: 4),
                        Text(approval.reason, style: FlexTypography.bodySm),
                        const SizedBox(height: 6),
                        Text(
                          'Requested by: ${approval.requestedBy}',
                          style: FlexTypography.bodySm.copyWith(color: FlexColors.textDisabledDark),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FlexButton(
                                label: 'Approve',
                                icon: Icons.check,
                                height: 36,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(pendingApprovalsProvider.notifier)
                                        .approve(approval.id);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Approve failed: $e'),
                                        backgroundColor: FlexColors.danger,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FlexButton(
                                label: 'Reject',
                                icon: Icons.close,
                                variant: FlexButtonVariant.danger,
                                height: 36,
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(pendingApprovalsProvider.notifier)
                                        .reject(approval.id);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Reject failed: $e'),
                                        backgroundColor: FlexColors.danger,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
