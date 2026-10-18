import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../mock/mock_sri_lanka_data.dart';
import '../../core/offline/offline_queue.dart';
import 'auth_repository.dart';

/// Colombo HQ fallback when device GPS is unavailable or denied.
const double kDefaultAttendanceLat = 6.9271;
const double kDefaultAttendanceLon = 79.8612;

class AttendanceGpsFix {
  const AttendanceGpsFix({
    required this.lat,
    required this.lon,
    required this.usedDefault,
    required this.label,
  });
  final double lat;
  final double lon;
  final bool usedDefault;
  final String label;
}

Future<AttendanceGpsFix> resolveAttendanceGps() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const AttendanceGpsFix(
        lat: kDefaultAttendanceLat,
        lon: kDefaultAttendanceLon,
        usedDefault: true,
        label: 'Colombo HQ (GPS unavailable — defaulted)',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const AttendanceGpsFix(
        lat: kDefaultAttendanceLat,
        lon: kDefaultAttendanceLon,
        usedDefault: true,
        label: 'Colombo HQ (location permission denied — defaulted)',
      );
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    return AttendanceGpsFix(
      lat: pos.latitude,
      lon: pos.longitude,
      usedDefault: false,
      label: 'Device GPS (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
    );
  } catch (_) {
    return const AttendanceGpsFix(
      lat: kDefaultAttendanceLat,
      lon: kDefaultAttendanceLon,
      usedDefault: true,
      label: 'Colombo HQ (GPS error — defaulted)',
    );
  }
}

class AttendanceGpsNoteNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setNote(String? v) => state = v;
}

final attendanceGpsNoteProvider =
    NotifierProvider<AttendanceGpsNoteNotifier, String?>(AttendanceGpsNoteNotifier.new);

class AttendanceNotifier extends Notifier<AttendanceRecord?> {
  @override
  AttendanceRecord? build() {
    final user = ref.watch(currentUserProvider);
    if (user != null && !user.isDemo) return null;
    return MockSriLankaDataService.currentAttendance;
  }

  Future<void> checkIn({required String employeeName, required bool isInsideGeofence}) async {
    final gps = await resolveAttendanceGps();
    ref.read(attendanceGpsNoteProvider.notifier).setNote(
          gps.usedDefault
              ? 'Using Colombo HQ default coordinates — device location unavailable.'
              : null,
        );
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      try {
        final result = await api.hrAttendance(
          checkIn: true,
          latitude: gps.lat,
          longitude: gps.lon,
        );
        state = AttendanceRecord(
          id: result['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          employeeName: employeeName,
          checkIn: DateTime.tryParse(result['check_in']?.toString() ?? '') ?? DateTime.now(),
          checkInLat: gps.lat,
          checkInLon: gps.lon,
          geofenceLocationName: gps.label,
          isInsideGeofence: isInsideGeofence,
        );
        return;
      } catch (_) {
        await ref.read(offlineQueueProvider.notifier).enqueue(
              type: 'hr_attendance',
              payload: {'check_in': true, 'latitude': gps.lat, 'longitude': gps.lon},
            );
      }
    }
    state = AttendanceRecord(
      id: DateTime.now().millisecondsSinceEpoch,
      employeeName: employeeName,
      checkIn: DateTime.now(),
      checkInLat: gps.lat,
      checkInLon: gps.lon,
      geofenceLocationName: gps.label,
      isInsideGeofence: isInsideGeofence,
    );
  }

  Future<void> checkOut() async {
    if (state == null) return;
    final gps = await resolveAttendanceGps();
    ref.read(attendanceGpsNoteProvider.notifier).setNote(
          gps.usedDefault
              ? 'Using Colombo HQ default coordinates — device location unavailable.'
              : null,
        );
    final user = ref.read(currentUserProvider);
    final api = ref.read(flexerpApiProvider);
    if (user != null && !user.isDemo && api != null) {
      try {
        final result = await api.hrAttendance(
          checkIn: false,
          latitude: gps.lat,
          longitude: gps.lon,
        );
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
              payload: {'check_in': false, 'latitude': gps.lat, 'longitude': gps.lon},
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
    } catch (e) {
      rethrow;
    }
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
    } catch (e) {
      rethrow;
    }
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
    } catch (e) {
      state = state.where((l) => l.id != request.id).toList();
      rethrow;
    }
  }
}

final leaveRequestsProvider = NotifierProvider<LeaveRequestsNotifier, List<LeaveRequest>>(
  LeaveRequestsNotifier.new,
);
