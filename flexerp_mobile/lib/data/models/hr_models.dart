class LeaveRequest {
  final int id;
  final String employeeName;
  final int employeeId;
  final String leaveType; // 'Annual Leave', 'Casual Leave', 'Medical Leave', 'Maternity Leave'
  final DateTime dateFrom;
  final DateTime dateTo;
  final double numberOfDays;
  final String status; // 'draft', 'confirm', 'validate', 'refuse'
  final String reason;

  const LeaveRequest({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    required this.leaveType,
    required this.dateFrom,
    required this.dateTo,
    required this.numberOfDays,
    required this.status,
    required this.reason,
  });

  bool get isApproved => status == 'validate';
  bool get isPending => status == 'confirm';
}

class EmployeeProfile {
  final int id;
  final String name;
  final String jobTitle;
  final String department;
  final String workEmail;
  final String workPhone;
  final String epfNumber;
  final String location;
  final String status; // 'active', 'on_leave', 'remote'

  const EmployeeProfile({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.department,
    required this.workEmail,
    required this.workPhone,
    required this.epfNumber,
    this.location = 'Colombo HQ',
    this.status = 'active',
  });
}
