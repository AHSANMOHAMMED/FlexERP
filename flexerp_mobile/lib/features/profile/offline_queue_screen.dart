import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/lk_formatters.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';

/// Pending + failed offline work for the signed-in tenant. Failed items are
/// never deleted silently: the user retries or explicitly discards them.
class OfflineQueueScreen extends ConsumerStatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  ConsumerState<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends ConsumerState<OfflineQueueScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final sent = await ref.read(offlineQueueProvider.notifier).flush();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sent > 0 ? 'Synced $sent item(s)' : 'Nothing synced (still offline or no pending items)')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _confirmDiscard(OfflineQueueItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard queued item?'),
        content: Text(
          '${item.label} will be permanently removed and NEVER sent to Odoo. '
          'Only discard it if you have recorded it another way.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: FlexColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(offlineQueueProvider.notifier).discard(item.id);
    }
  }

  String _summary(OfflineQueueItem item) {
    final p = item.payload;
    switch (item.type) {
      case 'pos_order':
        final total = (p['amount_total'] as num?)?.toDouble();
        final lines = (p['lines'] as List?)?.length ?? 0;
        return '$lines line(s)${total != null ? ' · ~${LkFormatters.formatLkr(total)}' : ''}'
            '${item.uuid != null ? ' · ${item.uuid!.substring(0, 8)}' : ''}';
      case 'payment_register':
        final amount = (p['amount'] as num?)?.toDouble();
        return 'Invoice #${p['move_id']}${amount != null ? ' · ${LkFormatters.formatLkr(amount)}' : ''}';
      case 'hr_attendance':
        return 'At ${p['timestamp'] ?? '?'} UTC';
      default:
        return '';
    }
  }

  Widget _tile(OfflineQueueItem item, {required bool failed}) {
    return FlexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed ? Icons.error_outline : Icons.schedule,
                color: failed ? FlexColors.danger : FlexColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(item.label, style: FlexTypography.labelLg)),
              Text(LkFormatters.formatDateTime(item.createdAt), style: FlexTypography.bodySm),
            ],
          ),
          const SizedBox(height: 4),
          Text(_summary(item), style: FlexTypography.bodySm),
          if (item.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              'Attempts: ${item.attempts} · ${item.lastError}',
              style: FlexTypography.bodySm.copyWith(color: failed ? FlexColors.danger : FlexColors.textSecondaryDark),
            ),
          ],
          if (failed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Discard'),
                  onPressed: () => _confirmDiscard(item),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  onPressed: () => ref.read(offlineQueueProvider.notifier).retry(item.id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineQueueProvider);
    final notifier = ref.read(offlineQueueProvider.notifier);
    final pending = notifier.pendingForCurrentScope;
    final failed = notifier.failedForCurrentScope;

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: AppBar(
        title: Text('Offline Sync Queue', style: FlexTypography.headlineMd),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : _syncNow,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('FAILED — NEEDS ATTENTION (${failed.length})', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          if (failed.isEmpty)
            Text('No failed items.', style: FlexTypography.bodySm)
          else
            ...failed.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _tile(i, failed: true),
                )),
          const SizedBox(height: 20),
          Text('PENDING SYNC (${pending.length})', style: FlexTypography.labelSm),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            Text('Everything is synced.', style: FlexTypography.bodySm)
          else
            ...pending.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _tile(i, failed: false),
                )),
        ],
      ),
    );
  }
}

/// Compact profile entry showing pending / failed counts.
class OfflineQueueEntryTile extends ConsumerWidget {
  const OfflineQueueEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(offlineQueueProvider);
    final notifier = ref.read(offlineQueueProvider.notifier);
    final pending = notifier.pendingForCurrentScope.length;
    final failed = notifier.failedForCurrentScope.length;
    return FlexCard(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfflineQueueScreen()),
        ),
        child: Row(
          children: [
            Icon(
              failed > 0 ? Icons.sync_problem : Icons.cloud_sync_outlined,
              color: failed > 0 ? FlexColors.danger : (pending > 0 ? FlexColors.warning : FlexColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Offline sync', style: FlexTypography.labelLg),
                  Text(
                    failed > 0
                        ? '$failed failed · $pending pending — tap to review'
                        : pending > 0
                            ? '$pending pending sync'
                            : 'All changes synced',
                    style: FlexTypography.bodySm,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FlexColors.textSecondaryDark),
          ],
        ),
      ),
    );
  }
}
