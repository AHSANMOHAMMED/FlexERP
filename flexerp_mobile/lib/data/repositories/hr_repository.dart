import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../mock/mock_sri_lanka_data.dart';
import 'auth_repository.dart';

class AttendanceNotifier extends Notifier<AttendanceRecord?> {
  @override
  AttendanceRecord? build() => MockSriLankaDataService.currentAttendance;

  void checkIn({required String employeeName, required bool isInsideGeofence}) {
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

  void checkOut() {
    if (state != null) {
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
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceRecord?>(
  AttendanceNotifier.new,
);

class EmployeeDirectoryNotifier extends Notifier<List<EmployeeProfile>> {
  @override
  List<EmployeeProfile> build() => MockSriLankaDataService.mockEmployees;

  Future<void> syncFromOdoo() async {
    final client = ref.read(odooClientProvider);
    if (client == null || !client.isAuthenticated) return;

    try {
      final results = await client.searchRead(
        model: 'hr.employee',
        fields: ['id', 'name', 'job_title', 'department_id', 'work_email', 'work_phone'],
        limit: 50,
      );

      if (results.isNotEmpty) {
        final employees = results.map((item) {
          final dept = item['department_id'] is List ? item['department_id'] as List : [0, 'General'];
          return EmployeeProfile(
            id: (item['id'] as num?)?.toInt() ?? 0,
            name: item['name']?.toString() ?? 'Employee',
            jobTitle: item['job_title']?.toString() ?? 'Staff Member',
            department: dept.length > 1 ? dept[1].toString() : 'Operations',
            workEmail: item['work_email']?.toString() ?? 'staff@flexcorp.lk',
            workPhone: item['work_phone']?.toString() ?? '+94 11 200 0000',
            epfNumber: 'EPF/${item['id']}',
          );
        }).toList();

        state = employees;
      }
    } catch (_) {
      // Fallback
    }
  }
}

final employeeDirectoryProvider = NotifierProvider<EmployeeDirectoryNotifier, List<EmployeeProfile>>(
  EmployeeDirectoryNotifier.new,
);

class LeaveRequestsNotifier extends Notifier<List<LeaveRequest>> {
  @override
  List<LeaveRequest> build() => MockSriLankaDataService.mockLeaveRequests;

  Future<void> syncFromOdoo() async {
    final client = ref.read(odooClientProvider);
    if (client == null || !client.isAuthenticated) return;

    try {
      final results = await client.searchRead(
        model: 'hr.leave',
        fields: [
          'id',
          'employee_id',
          'holiday_status_id',
          'request_date_from',
          'request_date_to',
          'number_of_days',
          'state',
          'name',
        ],
        limit: 30,
      );

      if (results.isNotEmpty) {
        final leaves = results.map((item) {
          final emp = item['employee_id'] is List ? item['employee_id'] as List : [0, 'Staff'];
          final holiday = item['holiday_status_id'] is List ? item['holiday_status_id'] as List : [0, 'Annual Leave'];
          final fromStr = item['request_date_from']?.toString();
          final toStr = item['request_date_to']?.toString();

          return LeaveRequest(
            id: (item['id'] as num?)?.toInt() ?? 0,
            employeeName: emp.length > 1 ? emp[1].toString() : 'Staff Member',
            employeeId: (emp[0] as num?)?.toInt() ?? 0,
            leaveType: holiday.length > 1 ? holiday[1].toString() : 'Annual Leave',
            dateFrom: fromStr != null ? DateTime.tryParse(fromStr) ?? DateTime.now() : DateTime.now(),
            dateTo: toStr != null ? DateTime.tryParse(toStr) ?? DateTime.now() : DateTime.now(),
            numberOfDays: (item['number_of_days'] as num?)?.toDouble() ?? 1.0,
            status: item['state']?.toString() ?? 'confirm',
            reason: item['name']?.toString() ?? 'Leave request',
          );
        }).toList();

        state = leaves;
      }
    } catch (_) {
      // Fallback
    }
  }

  void submitLeaveRequest(LeaveRequest request) {
    state = [request, ...state];
  }
}

final leaveRequestsProvider = NotifierProvider<LeaveRequestsNotifier, List<LeaveRequest>>(
  LeaveRequestsNotifier.new,
);
