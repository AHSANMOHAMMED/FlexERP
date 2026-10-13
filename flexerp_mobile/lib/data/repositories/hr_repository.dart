import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';

class AttendanceNotifier extends Notifier<AttendanceRecord?> {
  @override
  AttendanceRecord? build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return null;
    return MockSriLankaDataService.currentAttendance;
  }

  Future<void> checkIn({required String employeeName, required bool isInsideGeofence}) async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      try {
        final result = await api.hrAttendance(checkIn: true, latitude: 6.9271, longitude: 79.8612);
        state = AttendanceRecord(
          id: result['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          employeeName: employeeName,
          checkIn: DateTime.tryParse(result['check_in']?.toString() ?? '') ?? DateTime.now(),
          checkInLat: 6.9271,
          checkInLon: 79.8612,
          geofenceLocationName: 'Colombo HQ Office (Radius 100m)',
          isInsideGeofence: isInsideGeofence,
        );
        return;
      } catch (_) {
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'hr_attendance',
              payload: {'check_in': true, 'latitude': 6.9271, 'longitude': 79.8612},
            );
      }
    }
    state = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch,
      employeeName: employeeName,
      checkIn: DateTime.now(),
      checkInLat: 6.9271,
      checkInLon: 79.8612,
      geofenceLocationName: 'Colombo HQ Office (Radius 100m)',
      isInsideGeofence: isInsideGeofence,
    );
  }

  Future<void> checkOut() async {
    if (state == null) return;
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      try {
        final result = await api.hrAttendance(checkIn: false, latitude: 6.9271, longitude: 79.8612);
        state = AttendanceRecord(
          id: result['id'] as int? ?? state!.id,
          employeeName: state!.employeeName,
          checkIn: state!.checkIn,
          checkOut: DateTime.tryParse(result['check_out']?.toString() ?? '') ?? DateTime.now(),
          checkInLat: state!.checkInLat,
          checkInLon: state!.checkInLon,
          geofenceLocationName: state!.geofenceLocationName,
          isInsideGeofence: state!.isInsideGeofence,
        );
        return;
      } catch (_) {
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'hr_attendance',
              payload: {'check_in': false, 'latitude': 6.9271, 'longitude': 79.8612},
            );
      }
    }
    state = AttendanceRecord(
      id: state!.id,
      employeeName: state!.employeeName,
      checkIn: state!.checkIn,
      checkOut: DateTime.now(),
      checkInLat: state!.checkInLat,
      checkInLon: state!.checkInLon,
      geofenceLocationName: state!.geofenceLocationName,
      isInsideGeofence: state!.isInsideGeofence,
    );
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceRecord?>(
  AttendanceNotifier.new,
);

class EmployeeDirectoryNotifier extends Notifier<List<EmployeeProfile>> {
  @override
  List<EmployeeProfile> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.mockEmployees);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;

    try {
      final results = await api.hrEmployees();
      state = results.map((item) {
        return EmployeeProfile(
          id: (item['id'] as num?)?.toInt() ?? 0,
          name: item['name']?.toString() ?? 'Employee',
          jobTitle: item['job_title']?.toString() ?? 'Staff Member',
          department: item['department']?.toString() ?? 'Operations',
          workEmail: item['work_email']?.toString() ?? 'staff@flexcorp.lk',
          workPhone: item['work_phone']?.toString() ?? '+94 11 200 0000',
          epfNumber: 'EPF/${item['id']}',
        );
      }).toList();
    } catch (_) {}
  }
}

final employeeDirectoryProvider = NotifierProvider<EmployeeDirectoryNotifier, List<EmployeeProfile>>(
  EmployeeDirectoryNotifier.new,
);

class LeaveRequestsNotifier extends Notifier<List<LeaveRequest>> {
  @override
  List<LeaveRequest> build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return const [];
    return List.from(MockSriLankaDataService.mockLeaveRequests);
  }

  Future<void> syncFromOdoo() async {
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;

    try {
      final results = await api.hrLeaves();
      state = results.map((item) {
        final fromStr = item['date_from']?.toString();
        final toStr = item['date_to']?.toString();
        final from = fromStr != null ? DateTime.tryParse(fromStr) ?? DateTime.now() : DateTime.now();
        final to = toStr != null ? DateTime.tryParse(toStr) ?? DateTime.now() : DateTime.now();
        final days = to.difference(from).inDays + 1;
        return LeaveRequest(
          id: (item['id'] as num?)?.toInt() ?? 0,
          employeeName: item['employee']?.toString() ?? 'Staff Member',
          employeeId: 0,
          leaveType: item['type']?.toString() ?? 'Annual Leave',
          dateFrom: from,
          dateTo: to,
          numberOfDays: days.toDouble(),
          status: item['state']?.toString() ?? 'confirm',
          reason: 'Leave request',
        );
      }).toList();
    } catch (_) {}
  }

  Future<void> submitLeaveRequest(LeaveRequest request, {int? holidayStatusId}) async {
    state = [request, ...state];
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user == null || user.isDemo || api == null) return;
    try {
      var typeId = holidayStatusId;
      if (typeId == null) {
        final types = await api.hrLeaveTypes();
        typeId = types.isNotEmpty ? types.first['id'] as int? : 1;
      }
      final created = await api.hrSubmitLeave(
        holidayStatusId: typeId ?? 1,
        dateFrom: request.dateFrom.toIso8601String().split('T').first,
        dateTo: request.dateTo.toIso8601String().split('T').first,
        name: request.reason,
      );
      final id = created['id'] as int? ?? request.id;
      state = [
        for (final l in state)
          if (l.id == request.id)
            LeaveRequest(
              id: id,
              employeeName: request.employeeName,
              employeeId: request.employeeId,
              leaveType: request.leaveType,
              dateFrom: request.dateFrom,
              dateTo: request.dateTo,
              numberOfDays: request.numberOfDays,
              status: created['state']?.toString() ?? request.status,
              reason: request.reason,
            )
          else
            l
      ];
    } catch (_) {}
  }
}

final leaveRequestsProvider = NotifierProvider<LeaveRequestsNotifier, List<LeaveRequest>>(
  LeaveRequestsNotifier.new,
);
