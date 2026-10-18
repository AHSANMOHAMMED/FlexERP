import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/flex_colors.dart';
import '../../core/theme/flex_typography.dart';
import '../../core/widgets/flex_card.dart';
import '../../core/widgets/flex_badge.dart';
import '../../core/widgets/flex_app_bar.dart';
import '../../core/api/odoo_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/hr_repository.dart';

class AttendanceKioskScreen extends ConsumerStatefulWidget {
  const AttendanceKioskScreen({super.key});

  @override
  ConsumerState<AttendanceKioskScreen> createState() => _AttendanceKioskScreenState();
}

class _AttendanceKioskScreenState extends ConsumerState<AttendanceKioskScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentBranch = ref.watch(currentBranchProvider);
    final user = ref.watch(currentUserProvider);
    final attendance = ref.watch(attendanceProvider);
    final gpsNote = ref.watch(attendanceGpsNoteProvider);

    final isCheckedIn = attendance != null && attendance.checkOut == null;
    final timeFormat = DateFormat('hh:mm:ss a');
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

    return Scaffold(
      backgroundColor: FlexColors.canvasDark,
      appBar: FlexAppBar(
        title: 'Attendance Kiosk',
        subtitle: 'HR Geofenced Time Clock',
        currentBranch: currentBranch,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Live Digital Clock
            FlexCard(
              backgroundColor: FlexColors.surfaceRaisedDark,
              child: Column(
                children: [
                  Text(
                    dateFormat.format(_currentTime).toUpperCase(),
                    style: FlexTypography.labelSm.copyWith(color: FlexColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeFormat.format(_currentTime),
                    style: FlexTypography.headlineXl.copyWith(
                      color: FlexColors.primaryLight,
                      fontSize: 32,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Geofence Radar Preview Card
            FlexCard(
              child: Column(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: FlexColors.canvasDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlexColors.borderDark),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Simulated Radar concentric circles
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: FlexColors.success.withOpacity(0.3), width: 1.5),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FlexColors.success.withOpacity(0.1),
                            border: Border.all(color: FlexColors.success, width: 2),
                          ),
                          child: const Icon(Icons.my_location, color: FlexColors.success, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: FlexColors.success, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              attendance?.geofenceLocationName ??
                                  'Geofence: ${currentBranch.city}',
                              style: FlexTypography.labelMd,
                            ),
                          ),
                        ],
                      ),
                      FlexBadge(
                        text: gpsNote != null ? 'CHECK NOTE' : 'GPS READY',
                        variant: gpsNote != null ? FlexBadgeVariant.warning : FlexBadgeVariant.success,
                      ),
                    ],
                  ),
                  if (gpsNote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      gpsNote,
                      style: FlexTypography.bodySm.copyWith(color: FlexColors.warning),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Check-in records device GPS when available. If location is unavailable '
                      'the punch is recorded without coordinates and you will be told.',
                      style: FlexTypography.bodySm.copyWith(color: FlexColors.textSecondaryDark),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Check-in Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCheckedIn ? FlexColors.successBg : FlexColors.surfaceRaisedDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCheckedIn ? FlexColors.success.withOpacity(0.3) : FlexColors.borderDark,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCheckedIn ? Icons.check_circle : Icons.pause_circle_outline,
                    color: isCheckedIn ? FlexColors.success : FlexColors.textDisabledDark,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckedIn ? 'Currently Checked In' : 'Currently Checked Out',
                          style: FlexTypography.labelLg.copyWith(
                            color: isCheckedIn ? FlexColors.success : FlexColors.textPrimaryDark,
                          ),
                        ),
                        if (isCheckedIn)
                          Text(
                            'Logged Since ${DateFormat('hh:mm a').format(attendance.checkIn)} (${attendance.formattedWorkedHours})',
                            style: FlexTypography.bodySm,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Animated Large Action Button
            GestureDetector(
              onTap: () async {
                try {
                  if (isCheckedIn) {
                    await ref.read(attendanceProvider.notifier).checkOut();
                    if (!context.mounted) return;
                    final note = ref.read(attendanceGpsNoteProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: note == null ? null : FlexColors.warning,
                        content: Text(
                          note == null
                              ? 'Successfully Checked Out! Shift recorded.'
                              : 'Checked out. $note',
                        ),
                      ),
                    );
                  } else {
                    await ref.read(attendanceProvider.notifier).checkIn(
                          employeeName: user?.name ?? 'Employee',
                          isInsideGeofence: true,
                        );
                    if (!context.mounted) return;
                    final note = ref.read(attendanceGpsNoteProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: note == null ? FlexColors.success : FlexColors.warning,
                        content: Text(
                          note == null
                              ? 'Successfully Checked In! Location recorded.'
                              : 'Checked in. $note',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: FlexColors.danger,
                      content: Text('Attendance not recorded: ${describeError(e)}'),
                    ),
                  );
                }
              },
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCheckedIn ? FlexColors.dangerBg : FlexColors.successBg,
                  border: Border.all(
                    color: isCheckedIn ? FlexColors.danger : FlexColors.success,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isCheckedIn ? FlexColors.danger : FlexColors.success).withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCheckedIn ? Icons.logout : Icons.touch_app,
                      size: 44,
                      color: isCheckedIn ? FlexColors.danger : FlexColors.success,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: isCheckedIn ? FlexColors.danger : FlexColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Day Summary
            FlexCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("TODAY'S SHIFT SUMMARY", style: FlexTypography.labelSm),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Check-in Timestamp', style: FlexTypography.bodySm),
                      Text(
                        attendance != null ? DateFormat('hh:mm a').format(attendance.checkIn) : '--:--',
                        style: FlexTypography.labelMd,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Hours Logged Today', style: FlexTypography.bodySm),
                      Text(
                        attendance != null ? attendance.formattedWorkedHours : '0h 00m',
                        style: FlexTypography.labelMd.copyWith(color: FlexColors.primaryLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
