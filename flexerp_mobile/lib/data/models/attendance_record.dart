class AttendanceRecord {
  final int id;
  final String employeeName;
  final DateTime checkIn;
  DateTime? checkOut;
  /// Null when the device location was unavailable (never faked).
  final double? checkInLat;
  final double? checkInLon;
  final String geofenceLocationName; // e.g. "Colombo HQ Geofence"
  final bool isInsideGeofence;

  AttendanceRecord({
    required this.id,
    required this.employeeName,
    required this.checkIn,
    this.checkOut,
    this.checkInLat,
    this.checkInLon,
    required this.geofenceLocationName,
    required this.isInsideGeofence,
  });

  Duration get workedDuration {
    final end = checkOut ?? DateTime.now();
    return end.difference(checkIn);
  }

  String get formattedWorkedHours {
    final duration = workedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
