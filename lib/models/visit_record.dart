class VisitRecord {
  final String id;
  final String visitorId;
  final String? visitorTagId;
  final String? gateId;
  final DateTime checkInTime;
  late final DateTime? checkOutTime;
  late final String status;
  final String createdAt;

  VisitRecord({
    required this.id,
    required this.visitorId,
    this.visitorTagId,
    this.gateId,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitor_id': visitorId,
      'visitor_tag_id': visitorTagId,
      'gate_id': gateId,
      'check_in_time': checkInTime.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status,
      'created_at': createdAt,
    };
  }

  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] ?? '',
      visitorId: map['visitor_id'] ?? '',
      visitorTagId: map['visitor_tag_id'],
      gateId: map['gate_id'],
      checkInTime: DateTime.parse(map['check_in_time']),
      checkOutTime: map['check_out_time'] != null
          ? DateTime.parse(map['check_out_time'])
          : null,
      status: map['status'] ?? '',
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}
