class CrmLead {
  final int id;
  final String name;
  final String partnerName;
  final double expectedRevenue;
  final String stage; // 'New', 'Qualified', 'Proposition', 'Won'
  final int priority; // 1, 2, 3 stars
  final List<String> tags;
  final String phone;
  final String expectedClosing;
  final bool isOverdue;

  const CrmLead({
    required this.id,
    required this.name,
    required this.partnerName,
    required this.expectedRevenue,
    required this.stage,
    required this.priority,
    required this.tags,
    required this.phone,
    required this.expectedClosing,
    this.isOverdue = false,
  });

  CrmLead copyWith({
    int? id,
    String? name,
    String? partnerName,
    double? expectedRevenue,
    String? stage,
    int? priority,
    List<String>? tags,
    String? phone,
    String? expectedClosing,
    bool? isOverdue,
  }) {
    return CrmLead(
      id: id ?? this.id,
      name: name ?? this.name,
      partnerName: partnerName ?? this.partnerName,
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      stage: stage ?? this.stage,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      phone: phone ?? this.phone,
      expectedClosing: expectedClosing ?? this.expectedClosing,
      isOverdue: isOverdue ?? this.isOverdue,
    );
  }
}
