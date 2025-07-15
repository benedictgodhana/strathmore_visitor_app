import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import '../models/visitor.dart';
import '../models/host.dart';
import '../models/visit_record.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class VisitorProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Visitor> _visitors = [];
  List<String> _gates = [];
  List<Host> _hosts = [];
  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _visitorTags = [];
  bool _isLoading = false;
  String? _token;
  String? _deviceGate;
  String? _gateId;
  int _totalVisitCount = 0;
  int _todaysVisitCount = 0;
  int _checkedInCount = 0;
  int _checkedOutCount = 0;
  String? _errorMessage;

  List<Visitor> get visitors => _visitors;
  List<String> get gates => _gates;
  List<Host> get hosts => _hosts;
  List<Map<String, dynamic>> get destinations => _destinations;
  List<Map<String, dynamic>> get visitorTags => _visitorTags;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get deviceGate => _deviceGate;
  int get totalVisitCount => _totalVisitCount;
  int get todaysVisitCount => _todaysVisitCount;
  int get checkedInCount => _checkedInCount;
  int get checkedOutCount => _checkedOutCount;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _deviceGate = prefs.getString('deviceGate');
    _gateId = prefs.getString('gateId');

    if (_token != null && _deviceGate != null) {
      await Future.wait([
        loadCheckedInVisitors(),
        logVisitCount(),
        loadHosts(),
        loadDestinations(),
        loadVisitorTags(),
        loadGates(),
        syncQueuedActions(),
      ]);
    } else {
      await loadGates();
    }
    notifyListeners();
  }

  Future<void> loadGates() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _isOnline()) {
        await _loadGatesFromCache();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/gates-with-tags'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Load Gates Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['gates'] != null && data['gates'] is List) {
          _gates = (data['gates'] as List).map((gate) => gate['name'].toString()).toList();
          _visitorTags = (data['gates'] as List)
              .expand((gate) => (gate['tags'] as List).map((tag) => ({
                    'id': tag['id'].toString(),
                    'name': tag['name'].toString(),
                    'visitor_gate_id': gate['id'].toString(),
                    'visitor_gate_name': gate['name'].toString(),
                  })))
              .toList();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('gates', jsonEncode(_gates));
          await prefs.setString('visitorTags', jsonEncode(_visitorTags));
          print('✅ Loaded ${_gates.length} gates and ${_visitorTags.length} tags from API');
        } else {
          throw Exception('Invalid gates data format');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to load gates: Status ${response.statusCode}, Body: ${response.body}');
        await _loadGatesFromCache();
      }
    } catch (e) {
      print('❌ Error loading gates: $e');
      _errorMessage = 'Failed to load gates: $e';
      await _loadGatesFromCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadGatesFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedGates = prefs.getString('gates');
    final cachedVisitorTags = prefs.getString('visitorTags');
    if (cachedGates != null) {
      _gates = List<String>.from(jsonDecode(cachedGates));
      print('📴 Loaded ${_gates.length} gates from cache');
    }
    if (cachedVisitorTags != null) {
      _visitorTags = List<Map<String, dynamic>>.from(jsonDecode(cachedVisitorTags));
      print('📴 Loaded ${_visitorTags.length} visitor tags from cache');
    }
  }

  Future<void> loadHosts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _isOnline()) {
        _hosts = await _databaseService.getHosts();
        print('📴 Loaded ${_hosts.length} hosts from local database');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/hosts'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Load Hosts Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['hosts'] != null && data['hosts'] is List) {
          _hosts = (data['hosts'] as List).map((h) => Host.fromMap(h)).toList();
          for (var host in _hosts) {
            await _databaseService.insertHost(host);
          }
          print('✅ Loaded ${_hosts.length} hosts from API');
        } else {
          throw Exception('Invalid hosts data format');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to load hosts: Status ${response.statusCode}, Body: ${response.body}');
        _hosts = await _databaseService.getHosts();
      }
    } catch (e) {
      print('❌ Error loading hosts: $e');
      _errorMessage = 'Failed to load hosts: $e';
      _hosts = await _databaseService.getHosts();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDestinations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _isOnline()) {
        _destinations = await _databaseService.getDestinations();
        print('📴 Loaded ${_destinations.length} destinations from local database');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/destinations'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Load Destinations Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['destinations'] != null && data['destinations'] is List) {
          _destinations = (data['destinations'] as List).map((d) => ({
                'id': d['id'].toString(),
                'name': d['name'].toString(),
              })).toList();
          await _databaseService.saveDestinations(_destinations);
          print('✅ Loaded ${_destinations.length} destinations from API');
        } else {
          throw Exception('Invalid destinations data format');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to load destinations: Status ${response.statusCode}, Body: ${response.body}');
        _destinations = await _databaseService.getDestinations();
      }
    } catch (e) {
      print('❌ Error loading destinations: $e');
      _errorMessage = 'Failed to load destinations: $e';
      _destinations = await _databaseService.getDestinations();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVisitorTags() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _isOnline()) {
        _visitorTags = await _databaseService.getVisitorTags();
        print('📴 Loaded ${_visitorTags.length} visitor tags from local database');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/gates-with-tags'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Load Visitor Tags Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['gates'] != null && data['gates'] is List) {
          _visitorTags = (data['gates'] as List)
              .expand((gate) => (gate['tags'] as List).map((tag) => ({
                    'id': tag['id'].toString(),
                    'name': tag['name'].toString(),
                    'visitor_gate_id': gate['id'].toString(),
                    'visitor_gate_name': gate['name'].toString(),
                  })))
              .toList();
          await _databaseService.saveVisitorTags(_visitorTags);
          print('✅ Loaded ${_visitorTags.length} visitor tags from API');
        } else {
          throw Exception('Invalid visitor tags data format');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to load visitor tags: Status ${response.statusCode}, Body: ${response.body}');
        _visitorTags = await _databaseService.getVisitorTags();
      }
    } catch (e) {
      print('❌ Error loading visitor tags: $e');
      _errorMessage = 'Failed to load visitor tags: $e';
      _visitorTags = await _databaseService.getVisitorTags();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkVisitor(String idType, String idNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await _isOnline()) {
        final visitor = await _databaseService.getVisitorById(idType, idNumber);
        return visitor != null ? visitor.toMap() : null;
      }

      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/check'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identification_type': idType,
          'identification_number': _sanitizeInput(idNumber),
        }),
      ).timeout(Duration(seconds: 10));

      print('🌍 Check Visitor Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          final visitor = Visitor.fromMap(data);
          await _databaseService.insertVisitor(visitor);
          return data;
        }
        return null;
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to check visitor: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to check visitor: Status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking visitor: $e');
      _errorMessage = 'Failed to check visitor: $e';
      final visitor = await _databaseService.getVisitorById(idType, idNumber);
      return visitor != null ? visitor.toMap() : null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password, String selectedGate) async {
    if (!_validateInput(username) || !_validateInput(password)) {
      _errorMessage = 'Invalid username or password';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'X-Visitor-Management': 'true',
        },
        body: jsonEncode({
          'username': _sanitizeInput(username),
          'password': password,
          'gate': selectedGate,
        }),
      ).timeout(Duration(seconds: 10));

      print('🌍 Login Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _deviceGate = data['gate'] ?? selectedGate;
        _gateId = data['gate_id']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('deviceGate', _deviceGate!);
        if (_gateId != null) await prefs.setString('gateId', _gateId!);

        await Future.wait([
          loadCheckedInVisitors(),
          logVisitCount(),
          loadHosts(),
          loadDestinations(),
          loadVisitorTags(),
          loadGates(),
          syncQueuedActions(),
        ]);
      } else {
        print('⚠️ Login failed: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          _errorMessage = errorData['message'] ?? 'Invalid credentials';
          throw Exception(_errorMessage);
        } catch (e) {
          _errorMessage = 'Invalid response format: Status ${response.statusCode}';
          throw Exception(_errorMessage);
        }
      }
    } catch (e) {
      print('❌ Error during login: $e');
      _errorMessage = 'Login failed: $e';
      throw Exception(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null && token.isNotEmpty && await _isOnline()) {
        final response = await http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(Duration(seconds: 10));
        print('🌍 Logout Response: Status ${response.statusCode}, Body: ${response.body}');
      }

      await prefs.remove('token');
      await prefs.remove('deviceGate');
      await prefs.remove('gateId');
      await prefs.remove('gates');
      await prefs.remove('visitorTags');

      _token = null;
      _deviceGate = null;
      _gateId = null;
      _visitors = [];
      _hosts = [];
      _destinations = [];
      _visitorTags = [];
      _totalVisitCount = 0;
      _todaysVisitCount = 0;
      _checkedInCount = 0;
      _checkedOutCount = 0;
    } catch (e) {
      print('❌ Error during logout: $e');
      _errorMessage = 'Logout failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVisitors({int page = 1, int limit = 50}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final gate = prefs.getString('deviceGate') ?? 'Main Gate';
      final gateId = prefs.getString('gateId');

      if (!await _isOnline()) {
        _visitors = await _databaseService.getVisitors(page: page, limit: limit);
        print('📴 Loaded ${_visitors.length} visitors from local database');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors?gate=$gate&page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Load Visitors Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['visits'] != null && data['visits'] is List) {
          final newVisitors = (data['visits'] as List).map((v) => Visitor.fromMap({
                ...v['visitor'],
                'action': v['status'] == 'active' ? 'checked in' : 'checked out',
                'gate': gate,
                'gate_id': gateId ?? v['gate_id'],
                'visitor_tag_id': v['visitor_tag']?['id'],
                'destination_id': v['visitor_destination']?['id'],
                'time': v['check_in_time'],
                'created_at': v['check_in_time'],
              })).toList();
          final visitRecords = newVisitors
              .where((v) => v.action == 'checked in' || v.action == 'checked out')
              .map((v) => VisitRecord(
                    id: v.id,
                    visitorId: v.id,
                    checkInTime: v.time != null ? DateTime.parse(v.time.toString()) : DateTime.now(),
                    checkOutTime: v.action == 'checked out' ? (v.time != null ? DateTime.parse(v.time.toString()) : DateTime.now()) : null,
                    status: v.action == 'checked in' ? 'active' : 'checked_out',
                    visitorTagId: v.visitorTagId,
                    gateId: gateId ?? v.gate,
                    createdAt: v.createdAt?.toString() ?? DateTime.now().toIso8601String(),
                  ))
              .toList();
          await _databaseService.syncVisitRecords(visitRecords);
          if (page == 1) {
            _visitors = newVisitors;
          } else {
            _visitors.addAll(newVisitors);
          }
          for (var visitor in newVisitors) {
            await _databaseService.insertVisitor(visitor);
          }
          print('✅ Loaded ${newVisitors.length} visitors from API');
        } else {
          throw Exception('Invalid visitors data format');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to load visitors: Status ${response.statusCode}, Body: ${response.body}');
        _visitors = await _databaseService.getVisitors(page: page, limit: limit);
        _errorMessage = 'Failed to load visitors: Status ${response.statusCode}';
      }
    } catch (e) {
      print('❌ Error loading visitors: $e');
      _errorMessage = 'Failed to load visitors: $e';
      _visitors = await _databaseService.getVisitors(page: page, limit: limit);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCheckedInVisitors() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final gate = prefs.getString('deviceGate') ?? 'Main Gate';
    final gateId = prefs.getString('gateId');

    if (!await _isOnline()) {
      _visitors = await _databaseService.getCheckedInVisitors() ?? [];
      print('📴 Loaded ${_visitors.length} checked-in visitors from local database');
      return;
    }

    if (token == null) {
      throw Exception('No authentication token found');
    }

    final response = await http.get(
      Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/checked-in?gate=$gate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(Duration(seconds: 10));

    print('🌍 Checked-In Visitors Response: Status ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['checked_in_visitors'] != null && data['checked_in_visitors'] is List) {
        _visitors = (data['checked_in_visitors'] as List).map((v) {
          final baseVisitor = Map<String, dynamic>.from(v['visitor'] ?? {});
          final visitorData = {
            ...baseVisitor,
            'action': v['status'] == 'active' ? 'checked in' : v['status'],
            'gate': data['gate_name'] ?? gate,
            'gate_id': data['gate_id']?.toString() ?? gateId,
            'visitor_tag_id': v['visitor_tag_id']?.toString(),
            'destination_id': v['visitor_destination_id']?.toString(),
            'time': v['check_in_time'],
            'created_at': v['created_at'],
            'host': v['host_type'] == 'staff'
                ? {
                    'name': v['host']?.toString(),
                    'phone': v['host_phone']?.toString(),
                    'email': v['host_email']?.toString(),
                    'department': v['host_department']?.toString(),
                    'position': v['host_position']?.toString(),
                  }
                : null,
            'office': v['host_type'] == 'office'
                ? {
                    'name': v['office_name']?.toString(),
                    'phone': v['office_phone']?.toString(),
                    'email': v['office_email']?.toString(),
                    'department': v['office_department']?.toString(),
                    'contact_person': v['office_contact_person']?.toString(),
                  }
                : null,
            'visit_type': v['host_type'],
            'appointment_details': v['had_appointment']?.toString(),
            'vehicle_type': v['vehicle_type']?.toString(),
            'vehicle_registration': v['vehicle_registration']?.toString(),
          };

          return Visitor.fromMap(Map<String, dynamic>.from(visitorData));
        }).toList();

        final visitRecords = _visitors.map((v) => VisitRecord(
              id: v.id,
              visitorId: v.id,
              checkInTime: v.time != null ? DateTime.parse(v.time.toString()) : DateTime.now(),
              checkOutTime: null,
              status: 'active',
              visitorTagId: v.visitorTagId,
              gateId: gateId ?? v.gate,
              createdAt: v.createdAt?.toString() ?? DateTime.now().toIso8601String(),
            )).toList();

        await _databaseService.syncVisitRecords(visitRecords);
        for (var visitor in _visitors) {
          await _databaseService.insertVisitor(visitor);
        }

        print('✅ Loaded ${_visitors.length} checked-in visitors from API');
      } else {
        print('⚠️ Unexpected response format: $data');
        _visitors = await _databaseService.getCheckedInVisitors() ?? [];
        _errorMessage = 'Invalid response format from server';
      }
    } else if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired. Please log in again.');
    } else if (response.statusCode == 404) {
      print('⚠️ Endpoint not found or invalid gate: $gate');
      _errorMessage = 'API endpoint not found or invalid gate: $gate';
      _visitors = await _databaseService.getCheckedInVisitors() ?? [];
    } else {
      print('⚠️ Failed to fetch checked-in visitors: Status ${response.statusCode}, Body: ${response.body}');
      try {
        final errorData = jsonDecode(response.body);
        _errorMessage = 'Failed to fetch checked-in visitors: ${errorData['error'] ?? 'Status ${response.statusCode}'}';
      } catch (e) {
        _errorMessage = 'Failed to fetch checked-in visitors: Invalid response format (Status ${response.statusCode})';
      }
      _visitors = await _databaseService.getCheckedInVisitors() ?? [];
    }
  } catch (e) {
    print('❌ Error loading checked-in visitors: $e');
    _errorMessage = 'Failed to load checked-in visitors: $e';
    _visitors = await _databaseService.getCheckedInVisitors() ?? [];
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  Future<void> registerVisitor(Visitor visitor, {File? photo}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final gateId = prefs.getString('gateId');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      String? photoUrl;
      if (photo != null) {
        final compressedPhoto = await _compressImage(photo);
        photoUrl = await _uploadPhoto(compressedPhoto, token);
      }

      final visitorWithPhoto = Visitor(
        id: visitor.id,
        name: _sanitizeInput(visitor.name),
        phoneNumber: _sanitizeInput(visitor.phoneNumber),
        idNumber: _sanitizeInput(visitor.idNumber),
        idType: visitor.idType,
        office: visitor.office,
        host: visitor.host,
        vehicleRegistration: visitor.vehicleRegistration,
        vehicleType: visitor.vehicleType,
        country: visitor.country,
        isMinor: visitor.isMinor,
        guardianPhone: visitor.guardianPhone,
        destinationId: visitor.destinationId,
        visitorTagId: visitor.visitorTagId,
        visitorGateId: gateId ?? visitor.gate,
        visitType: visitor.visitType,
        appointmentDetails: visitor.appointmentDetails,
        photoPath: photoUrl,
        action: visitor.action ?? 'checked in',
        gate: visitor.gate,
        time: visitor.time ?? DateTime.now(),
        createdAt: visitor.createdAt ?? DateTime.now(),
      );

      if (!await _isOnline()) {
        await _databaseService.queueAction(visitorWithPhoto, 'register');
        _visitors.add(visitorWithPhoto);
        await _databaseService.insertVisitor(visitorWithPhoto);
        print('📴 Queued visitor registration for ${visitorWithPhoto.name}');
        return;
      }

      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': visitorWithPhoto.name,
          'phone_number': visitorWithPhoto.phoneNumber?.replaceFirst(visitorWithPhoto.phoneNumber!.startsWith('+254') ? '+254' : '', ''),
          'country': visitorWithPhoto.country,
          'is_minor': visitorWithPhoto.isMinor,
          'guardian_phone': visitorWithPhoto.guardianPhone?.replaceFirst(visitorWithPhoto.guardianPhone?.startsWith('+254') ?? false ? '+254' : '', ''),
          'visitor_tag_id': visitorWithPhoto.visitorTagId,
          'destination_id': visitorWithPhoto.destinationId,
          'identification_type': visitorWithPhoto.idType,
          'identification_number': visitorWithPhoto.idNumber,
          'visitor_gate_id': visitorWithPhoto.visitorGateId,
          'appointment_details': visitorWithPhoto.appointmentDetails,
          'vehicle_type': visitorWithPhoto.vehicleType,
          'vehicle_registration': visitorWithPhoto.vehicleRegistration,
          'visit_type': visitorWithPhoto.visitType,
          'host': visitorWithPhoto.host,
          'office': visitorWithPhoto.office,
          'photo_path': visitorWithPhoto.photoPath,
        }),
      ).timeout(Duration(seconds: 10));

      print('🌍 Register Visitor Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newVisitor = Visitor.fromMap(data['visitor']);
        _visitors.add(newVisitor);
        await _databaseService.insertVisitor(newVisitor);
        await logVisitCount();
        print('✅ Registered visitor: ${newVisitor.name}');
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to register visitor: Status ${response.statusCode}, Body: ${response.body}');
        if (response.body.startsWith('<!DOCTYPE html') || response.body.contains('<html')) {
          throw Exception('Server returned HTML instead of JSON. Possible server error or misconfiguration (Status ${response.statusCode}).');
        }
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to register visitor');
        } catch (e) {
          throw Exception('Failed to register visitor: Invalid response format (Status ${response.statusCode})');
        }
      }
    } catch (e) {
      print('❌ Error registering visitor: $e');
      _errorMessage = 'Failed to register visitor: $e';
      await _databaseService.queueAction(visitor, 'register');
      throw Exception(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkOutVisitor(Visitor visitor) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Define updatedVisitor outside try-catch so it's available in both
    final updatedVisitor = Visitor(
      id: visitor.id,
      name: visitor.name,
      phoneNumber: visitor.phoneNumber,
      idNumber: visitor.idNumber,
      idType: visitor.idType,
      office: visitor.office,
      host: visitor.host,
      vehicleRegistration: visitor.vehicleRegistration,
      vehicleType: visitor.vehicleType,
      country: visitor.country,
      isMinor: visitor.isMinor,
      guardianPhone: visitor.guardianPhone,
      destinationId: visitor.destinationId,
      visitorTagId: visitor.visitorTagId,
      visitorGateId: visitor.visitorGateId,
      visitType: visitor.visitType,
      appointmentDetails: visitor.appointmentDetails,
      photoPath: visitor.photoPath,
      action: 'checked out',
      gate: visitor.gate,
      time: visitor.time,
      createdAt: visitor.createdAt,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (!await _isOnline()) {
        await _databaseService.queueAction(updatedVisitor, 'checkout');
        final visitRecord = await _databaseService.getActiveVisitRecord(visitor.id);
        if (visitRecord != null) {
          visitRecord.status = 'checked_out';
          visitRecord.checkOutTime = DateTime.now();
          await _databaseService.insertVisitRecord(visitRecord);
        }
        _visitors.removeWhere((v) => v.id == visitor.id);
        await _databaseService.updateVisitor(updatedVisitor);
        print('📴 Queued visitor checkout for ${visitor.name}');
        return;
      }

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/${visitor.id}/checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Check Out Visitor Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final visitRecord = await _databaseService.getActiveVisitRecord(visitor.id);
        if (visitRecord != null) {
          visitRecord.status = 'checked_out';
          visitRecord.checkOutTime = DateTime.now();
          await _databaseService.insertVisitRecord(visitRecord);
        }
        _visitors.removeWhere((v) => v.id == visitor.id);
        await _databaseService.updateVisitor(updatedVisitor);
        await logVisitCount();
        print('✅ Checked out visitor: ${visitor.name}');
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to check out visitor: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to check out visitor: Status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking out visitor: $e');
      _errorMessage = 'Failed to check out visitor: $e';
      await _databaseService.queueAction(updatedVisitor, 'checkout');
      final visitRecord = await _databaseService.getActiveVisitRecord(visitor.id);
      if (visitRecord != null) {
        visitRecord.status = 'checked_out';
        visitRecord.checkOutTime = DateTime.now();
        await _databaseService.insertVisitRecord(visitRecord);
      }
      _visitors.removeWhere((v) => v.id == visitor.id);
      await _databaseService.updateVisitor(updatedVisitor);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncQueuedActions() async {
    if (!await _isOnline()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final queuedActions = await _databaseService.getQueuedActions();
    print('🔄 Syncing ${queuedActions.length} queued actions');

    for (var action in queuedActions) {
      try {
        if (action.action == 'register') {
          final visitor = Visitor.fromMap(jsonDecode(action.data ?? '{}'));
          final response = await http.post(
            Uri.parse('${AppStrings.apiBaseUrl}/api/visitors'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': visitor.name,
              'phone_number': visitor.phoneNumber?.replaceFirst(visitor.phoneNumber!.startsWith('+254') ? '+254' : '', ''),
              'country': visitor.country,
              'is_minor': visitor.isMinor,
              'guardian_phone': visitor.guardianPhone?.replaceFirst(visitor.guardianPhone?.startsWith('+254') ?? false ? '+254' : '', ''),
              'visitor_tag_id': visitor.visitorTagId,
              'destination_id': visitor.destinationId,
              'identification_type': visitor.idType,
              'identification_number': visitor.idNumber,
              'visitor_gate_id': visitor.visitorGateId,
              'appointment_details': visitor.appointmentDetails,
              'vehicle_type': visitor.vehicleType,
              'vehicle_registration': visitor.vehicleRegistration,
              'visit_type': visitor.visitType,
              'host': visitor.host,
              'office': visitor.office,
              'photo_path': visitor.photoPath,
            }),
          ).timeout(Duration(seconds: 10));

          print('🌍 Sync Register Action Response: Status ${response.statusCode}, Body: ${response.body}');
          if (response.statusCode == 201) {
            final data = jsonDecode(response.body);
            final newVisitor = Visitor.fromMap(data['visitor']);
            _visitors.add(newVisitor);
            await _databaseService.insertVisitor(newVisitor);
            await _databaseService.removeQueuedAction(action.id);
            print('✅ Synced visitor registration: ${newVisitor.name}');
          } else {
            print('⚠️ Failed to sync register action: Status ${response.statusCode}, Body: ${response.body}');
            continue;
          }
        } else if (action.action == 'checkout') {
          final visitor = Visitor.fromMap(jsonDecode(action.data ?? '{}'));
          final response = await http.post(
            Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/${visitor.id}/checkout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ).timeout(Duration(seconds: 10));

          print('🌍 Sync Checkout Action Response: Status ${response.statusCode}, Body: ${response.body}');
          if (response.statusCode == 200) {
            final visitRecord = await _databaseService.getActiveVisitRecord(visitor.id);
            if (visitRecord != null) {
              visitRecord.status = 'checked_out';
              visitRecord.checkOutTime = DateTime.now();
              await _databaseService.insertVisitRecord(visitRecord);
            }
            _visitors.removeWhere((v) => v.id == visitor.id);
            await _databaseService.updateVisitor(visitor);
            await _databaseService.removeQueuedAction(action.id);
            print('✅ Synced visitor checkout: ${visitor.name}');
          } else {
            print('⚠️ Failed to sync checkout action: Status ${response.statusCode}, Body: ${response.body}');
            continue;
          }
        }
      } catch (e) {
        print('❌ Error syncing action ${action.id}: $e');
        _errorMessage = 'Failed to sync action: $e';
      }
    }
    notifyListeners();
  }

  Future<File> _compressImage(File photo) async {
    final image = img.decodeImage(await photo.readAsBytes());
    if (image == null) throw Exception('Failed to decode image');
    final compressed = img.encodeJpg(image, quality: 85);
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/compressed_${photo.path.split('/').last}');
    return await tempFile.writeAsBytes(compressed);
  }

  Future<String> _uploadPhoto(File photo, String token) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppStrings.apiBaseUrl}/api/upload-photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      final response = await request.send().timeout(Duration(seconds: 10));

      print('🌍 Upload Photo Response: Status ${response.statusCode}');
      final responseBody = await response.stream.bytesToString();
      print('📸 Photo Upload Body: $responseBody');
      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['photo_url'] ?? '';
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        throw Exception('Failed to upload photo: Status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error uploading photo: $e');
      throw Exception('Photo upload failed: $e');
    }
  }

  Future<Map<String, dynamic>> verifyIdentity({String? studentId, String? username, String? staffNo}) async {
    final providedParams = [
      if (studentId != null) 'studentId',
      if (username != null) 'username',
      if (staffNo != null) 'staffNo',
    ];
    if (providedParams.length != 1) {
      _errorMessage = 'Exactly one of studentId, username, or staffNo must be provided';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    if (studentId != null && !RegExp(r'^\d{6,7}$').hasMatch(studentId)) {
      _errorMessage = 'Invalid input: Student ID must be 6 or 7 digits';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    if ((studentId?.isEmpty ?? true) && (username?.isEmpty ?? true) && (staffNo?.isEmpty ?? true)) {
      _errorMessage = 'Invalid input: Provide a valid student ID, username, or staff number';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      if (!await _isOnline()) {
        final identifier = studentId ?? username ?? staffNo!;
        final cachedResult = await _databaseService.getCachedVerification(identifier);
        if (cachedResult != null) {
          return cachedResult;
        }
        throw Exception('No internet connection and no cached data available');
      }

      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (studentId != null) 'student_id': _sanitizeInput(studentId),
          if (username != null) 'username': _sanitizeInput(username),
          if (staffNo != null) 'staff_no': _sanitizeInput(staffNo),
        }),
      ).timeout(Duration(seconds: 10));

      print('🌍 Verify Identity Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final result = {
            'success': true,
            'type': data['type'],
            if (data['type'] == 'student') ...{
              'studentId': data['studentId'],
              'name': data['name'] ?? 'Unknown',
              'surname': data['surname'] ?? 'N/A',
              'otherNames': data['otherNames'] ?? 'N/A',
              'gender': data['gender'] ?? 'N/A',
              'dateOfBirth': data['dateOfBirth'] ?? 'N/A',
              'courses': data['courses'] ?? 'N/A',
              'faculties': data['faculties'] ?? 'N/A',
              'email': data['email'] ?? 'N/A',
              'status': data['status'] ?? 'Active',
              'idExpiry': data['idExpiry'] ?? 'N/A',
            } else ...{
              'username': data['username'] ?? 'N/A',
              'staffNo': data['staffNo'] ?? 'N/A',
              'name': data['names'] ?? 'Unknown',
              'department': data['department'] ?? 'N/A',
              'status': data['status'] ?? 'Active',
            },
            'message': data['message'] ?? 'Identity verified successfully',
          };

          await _databaseService.cacheVerification(studentId ?? username ?? staffNo!, result);
          return result;
        } else {
          throw Exception(data['message'] ?? 'Invalid response: Verification failed');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to verify identity: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['message'] ?? 'Failed to verify identity');
        } catch (e) {
          throw Exception('Failed to verify identity: Invalid response format (Status ${response.statusCode})');
        }
      }
    } catch (e) {
      print('❌ Error verifying identity: $e');
      _errorMessage = 'Verification failed: $e';
      throw Exception(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logVisitCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final storedGate = prefs.getString('deviceGate') ?? 'Main Gate';
      final storedGateId = prefs.getString('gateId');

      if (token == null) {
        _errorMessage = 'No authentication token found';
        print('❌ No token found for logVisitCount');
        return;
      }

      if (!await _isOnline()) {
        _totalVisitCount = await _databaseService.getTotalVisitCount();
        _todaysVisitCount = await _databaseService.getTodaysVisitCount();
        _checkedInCount = await _databaseService.getCheckedInCount();
        _checkedOutCount = await _databaseService.getCheckedOutCount();
        print('📴 Offline visit counts: Total: $_totalVisitCount, Today: $_todaysVisitCount, Checked In: $_checkedInCount, Checked Out: $_checkedOutCount');
        return;
      }

      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visits/count?gate=$storedGate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      print('🌍 Visit Count Response: Status ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _gateId = data['gate_id']?.toString();
        _totalVisitCount = data['total_visit_count'] ?? data['visit_count'] ?? 0;
        _todaysVisitCount = data['todays_visit_count'] ?? 0;
        _checkedInCount = data['checked_in_count'] ?? 0;
        _checkedOutCount = data['checked_out_count'] ?? 0;
        await prefs.setString('gateId', _gateId ?? '');
        if (_totalVisitCount > 0) {
          await _databaseService.insertVisitRecord(VisitRecord(
            id: 'count_${DateTime.now().millisecondsSinceEpoch}',
            visitorId: '',
            checkInTime: _checkedInCount > 0 ? DateTime.now() : DateTime.now(),
            checkOutTime: _checkedOutCount > 0 ? DateTime.now() : null,
            status: _checkedInCount > 0 ? 'active' : 'checked_out',
            visitorTagId: null,
            gateId: _gateId,
            createdAt: DateTime.now().toIso8601String(),
          ));
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      } else {
        print('⚠️ Failed to fetch visit counts: Status ${response.statusCode}, Body: ${response.body}');
        try {
          final errorData = jsonDecode(response.body);
          _errorMessage = 'Failed to fetch visit counts: ${errorData['message'] ?? 'Status ${response.statusCode}'}';
        } catch (e) {
          _errorMessage = 'Failed to fetch visit counts: Invalid response format (Status ${response.statusCode})';
        }
        _totalVisitCount = await _databaseService.getTotalVisitCount();
        _todaysVisitCount = await _databaseService.getTodaysVisitCount();
        _checkedInCount = await _databaseService.getCheckedInCount();
        _checkedOutCount = await _databaseService.getCheckedOutCount();
      }
    } catch (e) {
      print('❌ Error fetching visit counts: $e');
      _errorMessage = 'Failed to fetch visit counts: $e';
      _totalVisitCount = await _databaseService.getTotalVisitCount();
      _todaysVisitCount = await _databaseService.getTodaysVisitCount();
      _checkedInCount = await _databaseService.getCheckedInCount();
      _checkedOutCount = await _databaseService.getCheckedOutCount();
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  String _sanitizeInput(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[<>]'), '').trim();
  }

  bool _validateInput(String? input) {
    return input != null && input.trim().isNotEmpty;
  }

  String? validateIdNumber(String idNumber, String? idType) {
    if (idNumber.isEmpty) return 'ID number is required';
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(idNumber)) {
      return 'Invalid ID number format';
    }
    if (idType == 'national_id' && !RegExp(r'^\d{8}$').hasMatch(idNumber)) {
      return 'National ID must be 8 digits';
    }
    if (idType == 'passport_number' && !RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(idNumber)) {
      return 'Passport number must be 6-12 alphanumeric characters';
    }
    if (idType == 'birth_certificate_number' && !RegExp(r'^[A-Za-z0-9]{8,12}$').hasMatch(idNumber)) {
      return 'Birth certificate number must be 8-12 alphanumeric characters';
    }
    if (idType == 'driving_licence' && !RegExp(r'^[A-Za-z0-9]{8,12}$').hasMatch(idNumber)) {
      return 'Driving licence must be 8-12 alphanumeric characters';
    }
    return null;
  }
}