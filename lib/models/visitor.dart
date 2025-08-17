import 'dart:convert';

class Visitor {
  final int id;
  final String name;
  final String phoneNumber;
  final String? phoneCountryCode;
  final String? country;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? visitorTagId;
  final String? tagNumber;
  final int? destinationId;
  final String? destination;
  final int? gateId;
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
  final bool? hadAppointment; // Boolean field
  final String? appointmentDetails; // Added: New field for appointment details
  final String? vehicleType;
  final String? vehicleRegistration;
  final int? floorId;
  final String? gender;

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
    this.appointmentDetails, // Added
    this.vehicleType,
    this.vehicleRegistration,
    this.floorId,
    this.gender,
  });

  static DateTime? parseDate(dynamic value, {bool isCheckIn = false}) {
    if (value == null || value.toString().isEmpty) {
      if (isCheckIn) {
        print('⚠️ Check-in date missing or empty: $value');
      }
      return null;
    }
    try {
      print('📅 Attempting to parse date: $value');
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
        print('✅ $fieldName is already an int: $value');
        return value;
      }
      if (value is double) {
        print('✅ Converting $fieldName from double to int: $value');
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          print('✅ Parsed $fieldName from string "$value" to int $parsed');
          return parsed;
        }
        throw FormatException('Invalid $fieldName format: $value');
      }
      throw FormatException('Unsupported $fieldName type: ${value.runtimeType} ($value)');
    } catch (e) {
      print('❌ Error parsing $fieldName: $value, Error: $e');
      if (fieldName == 'id') {
        print('⚠️ Returning 0 for id to prevent null error; this should be investigated');
        return 0;
      }
      return null;
    }
  }

  factory Visitor.fromMap(Map<String, dynamic> map) {
    print('📥 Creating Visitor from map: ${jsonEncode(map)}');

    final visitType = map['visit_type']?.toString() ??
        map['host_type']?.toString() ??
        'staff';
    print('ℹ️ Determined visitType: $visitType');

    Map<String, String>? hostData;
    if (visitType.toLowerCase() == 'staff') {
      print('ℹ️ Processing host data for staff visit');
      if (map['host'] != null) {
        if (map['host'] is String) {
          print('ℹ️ Host is a string: ${map['host']}');
          hostData = {
            'name': map['host']?.toString() ?? 'N/A',
            'phone': map['host_phone']?.toString() ?? 'N/A',
            'email': map['host_email']?.toString() ?? 'N/A',
            'department': map['host_department']?.toString() ?? 'N/A',
            'position': map['host_position']?.toString() ?? 'N/A',
          };
        } else if (map['host'] is Map) {
          print('ℹ️ Host is a map: ${map['host']}');
          hostData = {
            'name': map['host']['name']?.toString() ?? 'N/A',
            'phone': map['host']['phone']?.toString() ?? 'N/A',
            'email': map['host']['email']?.toString() ?? 'N/A',
            'department': map['host']['department']?.toString() ?? 'N/A',
            'position': map['host']['position']?.toString() ?? 'N/A',
          };
        } else {
          print('⚠️ Unexpected host type: ${map['host'].runtimeType}');
          hostData = {
            'name': 'N/A',
            'phone': 'N/A',
            'email': 'N/A',
            'department': 'N/A',
            'position': 'N/A',
          };
        }
      } else {
        print('⚠️ Host data is null');
        hostData = {
          'name': map['host_name']?.toString() ?? 'N/A',
          'phone': map['host_phone']?.toString() ?? 'N/A',
          'email': map['host_email']?.toString() ?? 'N/A',
          'department': map['host_department']?.toString() ?? 'N/A',
          'position': map['host_position']?.toString() ?? 'N/A',
        };
      }
    }

    final id = parseInt(map['id'], 'id');
    if (id == null) {
      print('❌ id is null after parsing; throwing exception');
      throw Exception('Invalid or missing id: ${map['id']}');
    }

    return Visitor(
      id: id,
      name: map['name']?.toString() ?? 'Unknown Visitor',
      phoneNumber: map['phone_number']?.toString() ?? '',
      phoneCountryCode: map['phone_country_code']?.toString(),
      country: map['country']?.toString(),
      checkInTime: parseDate(
        map['check_in_time'] ??
            map['checked_in_at'] ??
            map['time'] ??
            map['created_at'],
        isCheckIn: true,
      ),
      checkOutTime: parseDate(
        map['check_out_time'] ?? map['checked_out_at'],
        isCheckIn: false,
      ),
      visitorTagId: parseInt(
          map['visitor_tag_id'] ?? map['visitor_tag']?['id'], 'visitor_tag_id'),
      tagNumber: map['tag_number']?.toString() ??
          map['visitor_tag_number']?.toString() ??
          map['visitor_tag']?['tag_number']?.toString(),
      destinationId: parseInt(
          map['destination_id'] ??
              map['visitor_destination_id'] ??
              map['visitor_destination']?['id'],
          'destination_id'),
      destination: map['destination']?.toString() ??
          map['visitor_destination_name']?.toString() ??
          map['visitor_destination']?['name']?.toString(),
      gateId: parseInt(map['gate_id'] ?? map['gate']?['id'], 'gate_id'),
      gate: map['gate']?.toString() ?? map['visitor_gate_name']?.toString(),
      visitType: visitType,
      host: hostData,
      officeName:
          visitType.toLowerCase() == 'office' ? map['office_name']?.toString() : null,
      officePhone:
          visitType.toLowerCase() == 'office' ? map['office_phone']?.toString() : null,
      officeEmail:
          visitType.toLowerCase() == 'office' ? map['office_email']?.toString() : null,
      officeDepartment: visitType.toLowerCase() == 'office'
          ? map['office_department']?.toString()
          : null,
      officeContactPerson: visitType.toLowerCase() == 'office'
          ? map['office_contact_person']?.toString()
          : null,
      isMinor: map['is_minor'] == true || map['is_minor'] == 'true',
      guardianPhone: map['guardian_phone']?.toString(),
      accompanyingLetter: map['accompanying_letter']?.toString(),
      identificationType: map['identification_type']?.toString(),
      identificationNumber: map['identification_number']?.toString(),
      hadAppointment: map['had_appointment'] is bool
          ? map['had_appointment']
          : (map['had_appointment'] == 'true'
              ? true
              : (map['had_appointment'] == 'false' ? false : null)),
      appointmentDetails: map['appointment_details']?.toString(),
      vehicleType: map['vehicle_type']?.toString() ??
          map['vehicle_info']?['vehicle_type']?.toString(),
      vehicleRegistration: map['vehicle_registration']?.toString() ??
          map['vehicle_info']?['vehicle_registration']?.toString(),
      floorId: parseInt(map['floor_id'], 'floor_id'),
      gender: map['gender']?.toString(),
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
      'had_appointment': hadAppointment?.toString(), // Ensure boolean string
      'appointment_details': appointmentDetails,
      'vehicle_type': vehicleType,
      'vehicle_registration': vehicleRegistration,
      'floor_id': floorId,
      'gender': gender,
    }..removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );
  }

  String toJson() => jsonEncode(toMap());

  String get status => checkOutTime != null ? 'Checked Out' : 'Checked In';
}