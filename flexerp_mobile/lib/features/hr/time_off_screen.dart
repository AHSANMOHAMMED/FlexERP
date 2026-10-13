import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../data/models/hr_models.dart';
import '../../data/repositories/hr_repository.dart';

class TimeOffScreen extends ConsumerStatefulWidget {
  const TimeOffScreen({super.key});

  @override
  ConsumerState<TimeOffScreen> createState() => _TimeOffScreenState();
}

class _TimeOffScreenState extends ConsumerState<TimeOffScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(leaveRequestsProvider.notifier).syncFromOdoo();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave sync failed: $e'), backgroundColor: FlexColors.danger),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaveRequests = ref.watch(leaveRequestsProvider);

    return Scaffold(
      backgroundColor: FlexColors.background,
      appBar: FlexAppBar(
        title: 'Leaves & Time Off',
        subtitle: 'hr.leave Balances & Statutory Allocations',
        showCompanySwitcher: false,
        onSync: () => ref.read(leaveRequestsProvider.notifier).syncFromOdoo(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveModal(context),
        backgroundColor: FlexColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply for Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: FlexColors.primary,
        backgroundColor: FlexColors.surface,
        onRefresh: () => ref.read(leaveRequestsProvider.notifier).syncFromOdoo(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statutory Sri Lanka Leave Balances
            const Text(
              'Statutory Leave Allocations (Shop & Office Act)',
              style: TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLeaveBalanceCard(
                    title: 'Annual Leave',
                    available: '11',
                    total: '14 Days',
                    color: FlexColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLeaveBalanceCard(
                    title: 'Casual Leave',
                    available: '6',
                    total: '7 Days',
                    color: FlexColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLeaveBalanceCard(
                    title: 'Medical Leave',
                    available: '12',
                    total: '14 Days',
                    color: FlexColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Leave History Section
            const Text(
              'My Leave Applications',
              style: TextStyle(
                color: FlexColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (leaveRequests.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: FlexColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FlexColors.cardBorder),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.event_available, color: FlexColors.textSecondary, size: 40),
                    SizedBox(height: 12),
                    Text('No leave applications recorded', style: TextStyle(color: FlexColors.textSecondary)),
                  ],
                ),
              )
            else
              ...leaveRequests.map((leave) {
                final isApproved = leave.isApproved;
                final isPending = leave.isPending;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: FlexColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FlexColors.cardBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            leave.leaveType,
                            style: const TextStyle(
                              color: FlexColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? FlexColors.success.withValues(alpha: 0.15)
                                  : (isPending
                                      ? FlexColors.warning.withValues(alpha: 0.15)
                                      : FlexColors.error.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isApproved
                                    ? FlexColors.success
                                    : (isPending ? FlexColors.warning : FlexColors.error),
                              ),
                            ),
                            child: Text(
                              isApproved ? 'APPROVED' : (isPending ? 'PENDING APPROVAL' : 'REJECTED'),
                              style: TextStyle(
                                color: isApproved
                                    ? FlexColors.success
                                    : (isPending ? FlexColors.warning : FlexColors.error),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Period: ${leave.dateFrom.day}/${leave.dateFrom.month} - ${leave.dateTo.day}/${leave.dateTo.month}/${leave.dateTo.year} (${leave.numberOfDays.toStringAsFixed(0)} day${leave.numberOfDays > 1 ? 's' : ''})',
                        style: const TextStyle(color: FlexColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${leave.reason}',
                        style: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceCard({
    required String title,
    required String available,
    required String total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FlexColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlexColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: FlexColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                available,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $total',
                style: const TextStyle(color: FlexColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showApplyLeaveModal(BuildContext context) {
    String selectedType = 'Annual Leave';
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlexColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apply for Leave',
                    style: TextStyle(
                      color: FlexColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Leave Type', style: TextStyle(color: FlexColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: FlexColors.surface,
                    style: const TextStyle(color: FlexColors.textPrimary, fontSize: 13),
                    items: ['Annual Leave', 'Casual Leave', 'Medical Leave'].map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: FlexColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: FlexColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Reason / Remarks', style: TextStyle(color: FlexColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    style: const TextStyle(color: FlexColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter reason for time off...',
                      hintStyle: const TextStyle(color: FlexColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: FlexColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: FlexColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlexColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final newRequest = LeaveRequest(
                          id: DateTime.now().millisecondsSinceEpoch,
                          employeeName: 'Anushka Wickramasinghe',
                          employeeId: 806,
                          leaveType: selectedType,
                          dateFrom: DateTime.now().add(const Duration(days: 2)),
                          dateTo: DateTime.now().add(const Duration(days: 3)),
                          numberOfDays: 2.0,
                          status: 'confirm',
                          reason: reasonController.text.isNotEmpty ? reasonController.text : 'Personal matters',
                        );
                        ref.read(leaveRequestsProvider.notifier).submitLeaveRequest(newRequest);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Leave application submitted for supervisor approval')),
                        );
                      },
                      child: const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
