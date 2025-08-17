import 'dart:convert';

class Visitor {
  final int id; // Changed to int to match backend
  final String name;
  final String phoneNumber;
  final String? phoneCountryCode;
  final String? country;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? visitorTagId; // Changed to int?
  final String? tagNumber;
  final int? destinationId; // Changed to int?
  final String? destination;
  final int? gateId; // Changed to int?
  final String? gate;
  final String visitType;
  final Map<String, String>? host;
  final String? officeName;
  final String? officePhone;
  final String? officeEmail;
  final String? officeDepartment;
  final String? officeContactPerson;
  final bool isMinor;
  final String? guardianPhone;
  final String? accompanyingLetter;
  final String? identificationType;
  final String? identificationNumber;
  final String? hadAppointment;
  final String? vehicleType;
  final String? vehicleRegistration;
  final int? floorId; // Changed to int?
  final String? gender; // Add gender field

  String get hostType =>
      visitType.toLowerCase() == 'staff' ? 'staff' : 'office';

  Visitor({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.phoneCountryCode,
    this.country,
    this.checkInTime,
    this.checkOutTime,
    this.visitorTagId,
    this.tagNumber,
    this.destinationId,
    this.destination,
    this.gateId,
    this.gate,
    required this.visitType,
    this.host,
    this.officeName,
    this.officePhone,
    this.officeEmail,
    this.officeDepartment,
    this.officeContactPerson,
    this.isMinor = false,
    this.guardianPhone,
    this.accompanyingLetter,
    this.identificationType,
    this.identificationNumber,
    this.hadAppointment,
    this.vehicleType,
    this.vehicleRegistration,
    this.floorId,
    this.gender, // Include gender in constructor
  });

  static DateTime? parseDate(dynamic value, {bool isCheckIn = false}) {
    if (value == null || value.toString().isEmpty) {
      if (isCheckIn) {
        print('⚠️ Check-in date missing or empty: $value');
      } // Suppress logging for check-out dates, as null is expected
      return null;
    }
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      print('❌ Error parsing date: $value, Error: $e');
      return null;
    }
  }
static int? parseInt(dynamic value, String fieldName) {
  if (value == null) {
    print('⚠️ $fieldName is null');
    return null;
  }
  try {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.parse(value); // Directly parse string to int
    }
    throw FormatException('Invalid $fieldName: $value');
  } catch (e) {
    print('❌ Error parsing $fieldName: $value, Error: $e');
    return null; // Or handle differently based on requirements
  }
}
  factory Visitor.fromMap(Map<String, dynamic> map) {
  final visitType = map['visit_type']?.toString() ?? map['host_type']?.toString() ?? 'staff';

  Map<String, String>? hostData;
  if (visitType.toLowerCase() == 'staff') {
    if (map['host'] is String?) {
      hostData = {
        'name': map['host']?.toString() ?? 'N/A',
        'phone': map['host_phone']?.toString() ?? 'N/A',
        'email': map['host_email']?.toString() ?? 'N/A',
        'department': map['host_department']?.toString() ?? 'N/A',
        'position': map['host_position']?.toString() ?? 'N/A',
      };
    } else if (map['host'] is Map?) {
      hostData = {
        'name': map['host']?['name']?.toString() ?? 'N/A',
        'phone': map['host']?['phone']?.toString() ?? 'N/A',
        'email': map['host']?['email']?.toString() ?? 'N/A',
        'department': map['_prod']?['department']?.toString() ?? 'N/A',
        'position': map['host']?['position']?.toString() ?? 'N/A',
      };
    }
  }

  return Visitor(
    id: parseInt(map['id'], 'id') ?? (throw Exception('Invalid or missing id')), // Remove fallback to 0
    name: map['name']?.toString() ?? 'Unknown Visitor',
    phoneNumber: map['phone_number']?.toString() ?? '',
    phoneCountryCode: map['phone_country_code']?.toString(),
    country: map['country']?.toString(),
    checkInTime: parseDate(
      map['check_in_time'] ?? map['checked_in_at'] ?? map['time'] ?? map['created_at'],
      isCheckIn: true,
    ),
    checkOutTime: parseDate(
      map['check_out_time'] ?? map['checked_out_at'],
      isCheckIn: false,
    ),
    visitorTagId: parseInt(map['visitor_tag_id'] ?? map['visitor_tag']?['id'], 'visitor_tag_id'),
    tagNumber: map['tag_number']?.toString() ??
        map['visitor_tag_number']?.toString() ??
        map['visitor_tag']?['tag_number']?.toString(),
    destinationId: parseInt(
        map['destination_id'] ?? map['visitor_destination_id'] ?? map['visitor_destination']?['id'],
        'destination_id'),
    destination: map['destination']?.toString() ??
        map['visitor_destination_name']?.toString() ??
        map['visitor_destination']?['name']?.toString(),
    gateId: parseInt(map['gate_id'] ?? map['gate']?['id'], 'gate_id'),
    gate: map['gate']?.toString() ?? map['visitor_gate_name']?.toString(),
    visitType: visitType,
    host: hostData,
    officeName: visitType.toLowerCase() == 'office' ? map['office_name']?.toString() : null,
    officePhone: visitType.toLowerCase() == 'office' ? map['office_phone']?.toString() : null,
    officeEmail: visitType.toLowerCase() == 'office' ? map['office_email']?.toString() : null,
    officeDepartment: visitType.toLowerCase() == 'office' ? map['office_department']?.toString() : null,
    officeContactPerson: visitType.toLowerCase() == 'office' ? map['office_contact_person']?.toString() : null,
    isMinor: map['is_minor'] == true,
    guardianPhone: map['guardian_phone']?.toString(),
    accompanyingLetter: map['accompanying_letter']?.toString(),
    identificationType: map['identification_type']?.toString(),
    identificationNumber: map['identification_number']?.toString(),
    hadAppointment: map['had_appointment']?.toString() ?? map['appointment_details']?.toString(),
    vehicleType: map['vehicle_type']?.toString(),
    vehicleRegistration: map['vehicle_registration']?.toString(),
  );
}
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'phone_country_code': phoneCountryCode,
      'country': country,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'visitor_tag_id': visitorTagId,
      'tag_number': tagNumber,
      'destination_id': destinationId,
      'destination': destination,
      'gate_id': gateId,
      'gate': gate,
      'visit_type': visitType,
      'host_type': hostType,
      'host': host,
      'office_name': officeName,
      'office_phone': officePhone,
      'office_email': officeEmail,
      'office_department': officeDepartment,
      'office_contact_person': officeContactPerson,
      'is_minor': isMinor,
      'guardian_phone': guardianPhone,
      'accompanying_letter': accompanyingLetter,
      'identification_type': identificationType,
      'identification_number': identificationNumber,
      'had_appointment': hadAppointment,
      'vehicle_type': vehicleType,
      'vehicle_registration': vehicleRegistration,
    }..removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );
  }

  String toJson() => jsonEncode(toMap());

  String get status => checkOutTime != null ? 'Checked Out' : 'Checked In';
}
