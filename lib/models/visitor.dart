import 'dart:convert';

class Visitor {
  final String id;
  final String idType;
  final String idNumber;
  final String name;
  final String? phoneNumber;
  final String? guardianPhone;
  final String? country;
  final String? visitType;
  final Map<String, dynamic>? host;
  final Map<String, dynamic>? office;
  final String? appointmentDetails;
  final String? destinationId;
  final String? visitorTagId;
  final String? visitorGateId;
  final String? vehicleType;
  final String? vehicleRegistration;
  final String? photoPath;
  final bool isMinor;
  final String? action;
  final String? gate;
  final DateTime? time;
  final DateTime? createdAt;

  Visitor({
    required this.id,
    required this.idType,
    required this.idNumber,
    required this.name,
    this.phoneNumber,
    this.guardianPhone,
    this.country,
    this.visitType,
    this.host,
    this.office,
    this.appointmentDetails,
    this.destinationId,
    this.visitorTagId,
    this.visitorGateId,
    this.vehicleType,
    this.vehicleRegistration,
    this.photoPath,
    required this.isMinor,
    this.action,
    this.gate,
    this.time,
    this.createdAt,
  });

  factory Visitor.fromMap(Map<String, dynamic> map) {
    return Visitor(
      id: map['id']?.toString() ?? '',
      idType: map['identification_type']?.toString() ?? map['id_type']?.toString() ?? '',
      idNumber: map['id_number']?.toString() ?? map['identification_number']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phoneNumber: map['phone_number']?.toString(),
      guardianPhone: map['guardian_phone']?.toString(),
      country: map['country']?.toString(),
      visitType: map['visit_type']?.toString() ?? map['host_type']?.toString(),
      host: map['host'] is String ? jsonDecode(map['host']) : map['host'] as Map<String, dynamic>?,
      office: map['office'] is String ? jsonDecode(map['office']) : map['office'] as Map<String, dynamic>?,
      appointmentDetails: map['appointment_details']?.toString() ?? map['had_appointment']?.toString(),
      destinationId: map['destination_id']?.toString() ?? map['visitor_destination']?['id']?.toString(),
      visitorTagId: map['visitor_tag_id']?.toString() ?? map['visitor_tag']?['id']?.toString(),
      visitorGateId: map['gate_id']?.toString() ?? map['visitor_tag']?['visitor_gate']?['id']?.toString(),
      vehicleType: map['vehicle_type']?.toString(),
      vehicleRegistration: map['vehicle_registration']?.toString(),
      photoPath: map['photo_path']?.toString(),
      isMinor: map['is_minor'] == 1 || map['is_minor'] == true,
      action: map['action']?.toString() ?? map['status']?.toString(),
      gate: map['gate']?.toString() ?? map['visitor_tag']?['visitor_gate']?['name']?.toString(),
      time: map['time'] != null
          ? DateTime.tryParse(map['time'].toString())
          : map['check_in_time'] != null
              ? DateTime.tryParse(map['check_in_time'].toString())
              : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : map['check_in_time'] != null
              ? DateTime.tryParse(map['check_in_time'].toString())
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identification_type': idType,
      'id_number': idNumber, // ✅ Correct column name for SQLite
      'name': name,
      'phone_number': phoneNumber,
      'guardian_phone': guardianPhone,
      'country': country,
      'visit_type': visitType,
      'host': host,
      'office': office,
      'appointment_details': appointmentDetails,
      'destination_id': destinationId,
      'visitor_tag_id': visitorTagId,
      'gate_id': visitorGateId,
      'vehicle_type': vehicleType,
      'vehicle_registration': vehicleRegistration,
      'photo_path': photoPath,
      'is_minor': isMinor ? 1 : 0,
      'action': action,
      'gate': gate,
      'time': time?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }
}
