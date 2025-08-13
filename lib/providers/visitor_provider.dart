import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

class VisitorProvider extends ChangeNotifier {
  List<Visitor> _visitors = [];
  List<Map<String, String>> _gates = [];
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
  Map<String, String>? _gateMap;
  String? _userRole;
  String? _userPosition;
  String? _userName;

  List<Visitor> get visitors => _visitors;
  List<Map<String, String>> get gates =>
      _gates.isNotEmpty
          ? _gates
          : [
            {'id': '1', 'name': 'Default Gate'},
          ];
  List<Map<String, dynamic>> get destinations =>
      _destinations.isNotEmpty
          ? _destinations
          : [
            {'id': '1', 'name': 'Default Destination'},
          ];
  List<Map<String, dynamic>> get visitorTags => _visitorTags;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _token != null &&
      _token!.isNotEmpty &&
      _gateId != null &&
      _gateId!.isNotEmpty;
  String? get deviceGate => _deviceGate;
  String? get gateId => _gateId;
  int get totalVisitCount => _totalVisitCount;
  int get todaysVisitCount => _todaysVisitCount;
  int get checkedInCount => _checkedInCount;
  int get checkedOutCount => _checkedOutCount;
  Map<String, String>? get gateMap => _gateMap;
  String? get userRole => _userRole;
  String? get userPosition => _userPosition;
  String? get userName => _userName;

  Future<void> init(String token, String gateId, String deviceGate) async {
    _token = token;
    _gateId = gateId;
    _deviceGate = deviceGate;

    await _loadCachedData();

    if (isAuthenticated) {
      _isLoading = true;
      notifyListeners();

      try {
        final results = await Future.wait([
          loadCheckedInVisitors().then((_) => true).catchError((e) {
            print('❌ Failed to load checked-in visitors during init: $e');
            return false;
          }),
          loadDestinations().then((_) => true).catchError((e) {
            print('❌ Failed to load destinations during init: $e');
            return false;
          }),
          loadGates().then((_) => true).catchError((e) {
            print('❌ Failed to load gates during init: $e');
            return false;
          }),
          logVisitCount().then((_) => true).catchError((e) {
            print('❌ Failed to load visit counts during init: $e');
            return false;
          }),
        ], eagerError: false);

        print('✅ Initialization completed: $results');
        await _saveCachedData();
      } catch (e) {
        print('❌ Initialization error: $e');
        await _loadCachedData();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      await loadGates().catchError((e) {
        print('❌ Failed to load gates for unauthenticated user: $e');
      });
    }
  }

  void printLoggedInUser() {
    if (isAuthenticated && _userName != null) {
      print('👤 Logged-in User:');
      print('  Name: $_userName');
      print('  Role: ${_userRole ?? "N/A"}');
      print('  Position: ${_userPosition ?? "N/A"}');
      print('  Gate ID: $_gateId');
      print('  Device Gate: $_deviceGate');
      print('  Token: ${_token?.substring(0, 10)}... (truncated for security)');
    } else {
      print(
        '⚠️ No user is currently logged in or authentication data is missing',
      );
    }
  }

  Future<void> login(
    String username,
    String password,
    String gateId,
    String deviceGate,
  ) async {
    if (!_validateInput(username) || !_validateInput(password)) {
      print('❌ Login validation failed: Invalid username or password');
      throw Exception('Invalid username or password');
    }

    _isLoading = true;
    notifyListeners();

    try {
      int parsedGateId;
      try {
        parsedGateId = int.parse(gateId);
      } catch (e) {
        print('❌ Invalid gate ID format: $gateId, Error: $e');
        throw Exception('Invalid gate ID format');
      }

      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Visitor-Management': 'true',
        },
        body: jsonEncode({
          'username': _sanitizeInput(username),
          'password': password,
          'gate_id': parsedGateId,
        }),
      );

      print(
        '🌍 Login Response: Status ${response.statusCode}, Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (data['token'] == null ||
            data['user'] == null ||
            data['gate_id'] == null) {
          print(
            '❌ Missing required fields in response: token, user, or gate_id',
          );
          throw Exception(
            'Invalid response from server: Missing token or user data',
          );
        }

        _token = data['token'];
        _gateId = data['gate_id']?.toString();
        _deviceGate = data['gate']?.toString() ?? deviceGate;
        _userRole = data['user']['role']?.toString();
        _userPosition = data['user']['position']?.toString();
        _userName = data['user']['name']?.toString();

        await _saveCachedData();
        print(
          '✅ Login success: Token saved, User: $_userName, Gate ID: $_gateId',
        );
        printLoggedInUser();

        final rawTags = data['visitor_tags'];
        _visitorTags = [];
        if (rawTags != null && rawTags is List) {
          _visitorTags =
              rawTags
                  .map(
                    (tag) =>
                        tag is Map
                            ? {
                              'id': tag['id']?.toString() ?? '',
                              'tag_number': tag['tag_number']?.toString() ?? '',
                              'visitor_gate_id':
                                  tag['visitor_gate_id']?.toString() ?? '',
                              'visitor_gate_name':
                                  tag['visitor_gate_name']?.toString() ?? '',
                              'is_assigned': tag['is_assigned'] == true,
                            }
                            : <String, dynamic>{},
                  )
                  .where((tag) => tag.isNotEmpty)
                  .toList();
        }

        final results = await Future.wait([
          loadCheckedInVisitors().then((_) => true).catchError((e) {
            print('❌ Failed to load checked-in visitors post-login: $e');
            return false;
          }),
          loadVisitors().then((_) => true).catchError((e) {
            print('❌ Failed to load visitors post-login: $e');
            return false;
          }),
          loadDestinations().then((_) => true).catchError((e) {
            print('❌ Failed to load destinations post-login: $e');
            return false;
          }),
          loadGates().then((_) => true).catchError((e) {
            print('❌ Failed to load gates post-login: $e');
            return false;
          }),
          logVisitCount().then((_) => true).catchError((e) {
            print('❌ Failed to load visit counts post-login: $e');
            return false;
          }),
        ], eagerError: false);

        print('✅ Post-login tasks completed: $results');
        await _saveCachedData();
        print('✅ Login successful, navigating to home');
      } else {
        _handleApiError(response, 'Login failed');
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Login error: $e');
      throw Exception(_parseErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGates() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/gates'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print(
        '🌍 Load Gates Response: Status ${response.statusCode}, Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> gatesData = data['data'] ?? data['gates'] ?? [];

        if (gatesData.isNotEmpty) {
          _gates =
              gatesData
                  .map(
                    (gate) => {
                      'id': gate['id']?.toString() ?? '',
                      'name': gate['name']?.toString() ?? 'Unknown Gate',
                    },
                  )
                  .toList();
          _gateMap = {for (var gate in _gates) gate['name']!: gate['id']!};
          _visitorTags =
              gatesData
                  .where(
                    (gate) =>
                        gate.containsKey('visitor_tags') &&
                        gate['visitor_tags'] is List,
                  )
                  .expand(
                    (gate) => (gate['visitor_tags'] as List).map(
                      (tag) => {
                        'id': tag['id']?.toString() ?? '',
                        'tag_number': tag['tag_number']?.toString() ?? '',
                        'visitor_gate_id': gate['id']?.toString() ?? '',
                        'visitor_gate_name': gate['name']?.toString() ?? '',
                        'is_assigned': tag['is_assigned'] == true,
                      },
                    ),
                  )
                  .toList();
          print(
            '✅ Loaded ${_gates.length} gates and ${_visitorTags.length} tags from API',
          );
          print('📴 gateMap: $_gateMap');
          await _saveCachedData();
        } else {
          _gates = [
            {'id': '1', 'name': 'Default Gate'},
          ];
          _gateMap = {'Default Gate': '1'};
          print('⚠️ Gate list is empty; using default gate');
          await _saveCachedData();
        }
      } else {
        _handleApiError(response, 'Failed to load gates');
      }
    } catch (e) {
      print('❌ Error loading gates: $e');
      if (_gates.isEmpty) {
        _gates = [
          {'id': '1', 'name': 'Default Gate'},
        ];
        _gateMap = {'Default Gate': '1'};
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDestinations() async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot load destinations: No authentication token or gate ID found',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/destinations'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
        '🌍 Load Destinations Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['destinations'] != null && data['destinations'] is List) {
          _destinations =
              (data['destinations'] as List)
                  .map(
                    (d) => ({
                      'id': d['id']?.toString() ?? '',
                      'name': d['name']?.toString() ?? 'Unknown Destination',
                    }),
                  )
                  .toList();
          print('✅ Loaded ${_destinations.length} destinations from API');
          await _saveCachedData();
        } else {
          throw Exception('Invalid destinations data format');
        }
      } else {
        _handleApiError(response, 'Failed to load destinations');
      }
    } catch (e) {
      print('❌ Error loading destinations: $e');
      if (_destinations.isEmpty) {
        _destinations = [
          {'id': '1', 'name': 'Default Destination'},
        ];
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVisitorTags() async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot load visitor tags: No authentication token or gate ID found',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(
          '${AppStrings.apiBaseUrl}/api/gates-with-tags?gate_id=$_gateId',
        ),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
        '🌍 Load Visitor Tags Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['gates'] != null && data['gates'] is List) {
          _visitorTags =
              (data['gates'] as List)
                  .expand(
                    (gate) =>
                        (gate['tags'] as List?)?.map<Map<String, dynamic>>(
                          (tag) => {
                            'id': tag['id']?.toString() ?? '',
                            'tag_number': tag['tag_number']?.toString() ?? '',
                            'visitor_gate_id': gate['id']?.toString() ?? '',
                            'visitor_gate_name': gate['name']?.toString() ?? '',
                            'is_assigned': tag['is_assigned'] == true,
                          },
                        ) ??
                        <Map<String, dynamic>>[],
                  )
                  .toList();
          print('✅ Loaded ${_visitorTags.length} visitor tags from API');
          await _saveCachedData();
        } else {
          throw Exception('Invalid visitor tags data format');
        }
      } else {
        _handleApiError(response, 'Failed to load visitor tags');
      }
    } catch (e) {
      print('❌ Error loading visitor tags: $e');
      if (_visitorTags.isEmpty) {
        _visitorTags = [];
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkVisitor(
    String idType,
    String idNumber,
  ) async {
    if (!isAuthenticated) {
      print('❌ Cannot check visitor: No authentication token or gate ID found');
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/check'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'identification_type': idType,
          'identification_number': _sanitizeInput(idNumber),
          'gate_id': _gateId,
        }),
      );

      print(
        '🌍 Check Visitor Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveCachedData();
        return data;
      } else {
        _handleApiError(response, 'Failed to check visitor');
        return null;
      }
    } catch (e) {
      print('❌ Error checking visitor: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_token != null && _token!.isNotEmpty) {
        try {
          final response = await http
              .post(
                Uri.parse('${AppStrings.apiBaseUrl}/api/logout'),
                headers: {
                  'Authorization': 'Bearer $_token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
              .timeout(Duration(seconds: 10));

          print(
            '🌍 Logout Response: Status ${response.statusCode}, Body: ${response.body}',
          );
          if (response.statusCode == 200 || response.statusCode == 401) {
            print('✅ Logout successful or session already expired');
          } else {
            _handleApiError(response, 'Logout failed');
          }
        } catch (e) {
          print('❌ Error during API logout: $e');
        }
      } else {
        print('⚠️ No valid token for logout, clearing authentication state');
      }

      _clearAuthenticationState();
      await _saveCachedData();
      print('✅ Cleared authentication state after logout');
    } catch (e) {
      print('❌ Error during logout: $e');
      _clearAuthenticationState();
      await _saveCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearAuthenticationState() {
    _token = null;
    _deviceGate = null;
    _gateId = null;
    _userRole = null;
    _userPosition = null;
    _userName = null;
  }

  Future<void> loadVisitors({int page = 1, int limit = 50}) async {
    if (!isAuthenticated) {
      print('❌ Cannot load visitors: No authentication token or gate ID found');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(
          '${AppStrings.apiBaseUrl}/api/visitors?gate_id=$_gateId&page=$page&limit=$limit',
        ),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
        '🌍 Load Visitors Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['visits'] != null && data['visits'] is List) {
          final newVisitors =
              (data['visits'] as List)
                  .map(
                    (v) => Visitor.fromMap({
                      ...v['visitor'] ?? {},
                      'action':
                          v['status'] == 'active'
                              ? 'checked in'
                              : v['status'] ?? 'checked out',
                      'gate': _deviceGate,
                      'gate_id': _gateId,
                      'visitor_tag_id': v['visitor_tag']?['id']?.toString(),
                      'tag_number': v['visitor_tag']?['tag_number']?.toString(),
                      'destination_id':
                          v['visitor_destination']?['id']?.toString(),
                      'time': v['check_in_time'],
                      'created_at': v['check_in_time'],
                      'host':
                          v['host_type'] == 'staff'
                              ? {
                                'name': v['host']?.toString() ?? 'N/A',
                                'phone': v['host_phone']?.toString() ?? 'N/A',
                                'email': v['host_email']?.toString() ?? 'N/A',
                                'department':
                                    v['host_department']?.toString() ?? 'N/A',
                                'position':
                                    v['host_position']?.toString() ?? 'N/A',
                              }
                              : null,
                      'office':
                          v['host_type'] == 'office'
                              ? {
                                'name': v['office_name']?.toString() ?? 'N/A',
                                'phone': v['office_phone']?.toString() ?? 'N/A',
                                'email': v['office_email']?.toString() ?? 'N/A',
                                'department':
                                    v['office_department']?.toString() ?? 'N/A',
                                'contact_person':
                                    v['office_contact_person']?.toString() ??
                                    'N/A',
                              }
                              : null,
                      'visit_type': v['host_type']?.toString(),
                      'appointment_details': v['had_appointment']?.toString(),
                      'vehicle_type': v['vehicle_type']?.toString(),
                      'vehicle_registration':
                          v['vehicle_registration']?.toString(),
                    }),
                  )
                  .toList();
          if (page == 1) {
            _visitors = newVisitors;
          } else {
            _visitors.addAll(newVisitors);
          }
          print(
            '✅ Loaded ${newVisitors.length} visitors from API for gate ID=$_gateId',
          );
          await _saveCachedData();
        } else {
          throw Exception('Invalid visitors data format');
        }
      } else {
        _handleApiError(response, 'Failed to load visitors');
      }
    } catch (e) {
      print('❌ Error loading visitors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCheckedInVisitors() async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot load checked-in visitors: No authentication token or gate ID found',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(
          '${AppStrings.apiBaseUrl}/api/visitors/checked-in?gate_id=$_gateId',
        ),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
        '🌍 Checked-In Visitors Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['checked_in_visitors'] != null &&
            data['checked_in_visitors'] is List) {
          _visitors =
              (data['checked_in_visitors'] as List).map((v) {
                final baseVisitor = Map<String, dynamic>.from(
                  v['visitor'] ?? {},
                );
                final visitorData = {
                  ...baseVisitor,
                  'action':
                      v['status'] == 'active' ? 'checked in' : v['status'],
                  'gate': data['gate_name']?.toString() ?? _deviceGate,
                  'gate_id': data['gate_id']?.toString() ?? _gateId,
                  'visitor_tag_id': v['visitor_tag_id']?.toString(),
                  'tag_number': v['visitor_tag_number']?.toString(),
                  'destination_id': v['visitor_destination_id']?.toString(),
                  'time': v['check_in_time'],
                  'created_at': v['created_at'],
                  'host':
                      v['host_type'] == 'staff'
                          ? {
                            'name': v['host']?.toString() ?? 'N/A',
                            'phone': v['host_phone']?.toString() ?? 'N/A',
                            'email': v['host_email']?.toString() ?? 'N/A',
                            'department':
                                v['host_department']?.toString() ?? 'N/A',
                            'position': v['host_position']?.toString() ?? 'N/A',
                          }
                          : null,
                  'office':
                      v['host_type'] == 'office'
                          ? {
                            'name': v['office_name']?.toString() ?? 'N/A',
                            'phone': v['office_phone']?.toString() ?? 'N/A',
                            'email': v['office_email']?.toString() ?? 'N/A',
                            'department':
                                v['office_department']?.toString() ?? 'N/A',
                            'contact_person':
                                v['office_contact_person']?.toString() ?? 'N/A',
                          }
                          : null,
                  'visit_type': v['host_type']?.toString(),
                  'appointment_details': v['had_appointment']?.toString(),
                  'vehicle_type': v['vehicle_type']?.toString(),
                  'vehicle_registration': v['vehicle_registration']?.toString(),
                };
                return Visitor.fromMap(visitorData);
              }).toList();
          print(
            '✅ Loaded ${_visitors.length} checked-in visitors from API for gate ID=$_gateId',
          );
          await _saveCachedData();
        } else {
          throw Exception('Invalid response format from server');
        }
      } else {
        _handleApiError(response, 'Failed to fetch checked-in visitors');
      }
    } catch (e) {
      print('❌ Error loading checked-in visitors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logVisitCount() async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot fetch visit counts: No authentication token or gate ID found',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visits/count?gate_id=$_gateId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print(
        '🌍 Visit Count Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _gateId = data['gate_id']?.toString() ?? _gateId;
        _totalVisitCount =
            data['total_visit_count']?.toInt() ??
            data['visit_count']?.toInt() ??
            0;
        _todaysVisitCount = data['todays_visit_count']?.toInt() ?? 0;
        _checkedInCount = data['checked_in_count']?.toInt() ?? 0;
        _checkedOutCount = data['checked_out_count']?.toInt() ?? 0;
        print(
          '✅ Visit counts updated: Total=$_totalVisitCount, Today=$_todaysVisitCount, Checked In=$_checkedInCount, Checked Out=$_checkedOutCount',
        );
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to fetch visit counts');
      }
    } catch (e) {
      print('❌ Error fetching visit counts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerVisitor(Visitor visitor) async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot register visitor: No authentication token or gate ID found',
      );
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitors'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': _sanitizeInput(visitor.name),
          'phone_number':
              visitor.phoneNumber?.replaceFirst(
                visitor.phoneNumber?.startsWith('+254') ?? false ? '+254' : '',
                '',
              ) ??
              '',
          'country': visitor.country,
          'is_minor': visitor.isMinor,
          'guardian_phone':
              visitor.guardianPhone?.replaceFirst(
                visitor.guardianPhone?.startsWith('+254') ?? false
                    ? '+254'
                    : '',
                '',
              ) ??
              '',
          'visitor_tag_id': visitor.visitorTagId,
          'destination_id': visitor.destinationId,
          'identification_type': visitor.idType,
          'identification_number': _sanitizeInput(visitor.idNumber),
          'visitor_gate_id': visitor.visitorGateId ?? _gateId,
          'appointment_details': visitor.appointmentDetails,
          'vehicle_type': visitor.vehicleType,
          'vehicle_registration': visitor.vehicleRegistration,
          'visit_type': visitor.visitType,
          'host': visitor.host,
          'office': visitor.office,
          'photo_path': visitor.photoPath,
        }),
      );

      print(
        '🌍 Register Visitor Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newVisitor = Visitor.fromMap(data['visitor']);
        _visitors.add(newVisitor);
        print('✅ Registered visitor: ${newVisitor.name} at gate ID=$_gateId');
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to register visitor');
      }
    } catch (e) {
      print('❌ Error registering visitor: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkOutVisitor(Visitor? visitor) async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot check out visitor: No authentication token or gate ID found',
      );
      return;
    }

    if (visitor == null || visitor.id == null) {
      print('❌ checkOutVisitor received null visitor or missing ID');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(
          '${AppStrings.apiBaseUrl}/api/visitors/${visitor.id}/checkout',
        ),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'id': visitor.id, 'gate_id': _gateId}),
      );

      print(
        '🌍 Check Out Visitor Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        _visitors.removeWhere((v) => v.id == visitor.id);
        print('✅ Checked out visitor: ${visitor.name} at gate ID=$_gateId');
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to check out visitor');
      }
    } catch (e) {
      print('❌ Error checking out visitor: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyIdentity({
    String? studentId,
    String? username,
    String? staffNo,
  }) async {
    if (!isAuthenticated) {
      print(
        '❌ Cannot verify identity: No authentication token or gate ID found',
      );
      return {'success': false};
    }

    final providedParams = [
      if (studentId != null) 'studentId',
      if (username != null) 'username',
      if (staffNo != null) 'staffNo',
    ];
    if (providedParams.length != 1) {
      print(
        '❌ Exactly one of studentId, username, or staffNo must be provided',
      );
      return {'success': false};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/verify'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (studentId != null) 'student_id': _sanitizeInput(studentId),
          if (username != null) 'username': _sanitizeInput(username),
          if (staffNo != null) 'staff_no': _sanitizeInput(staffNo),
          'gate_id': _gateId,
        }),
      );

      print(
        '🌍 Verify Identity Response: Status ${response.statusCode}, Body: ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final result = {
            'success': true,
            'type': data['type']?.toString() ?? 'unknown',
            if (data['type'] == 'student') ...{
              'studentId': data['studentId']?.toString() ?? 'N/A',
              'name': data['name']?.toString() ?? 'Unknown',
              'surname': data['surname']?.toString() ?? 'N/A',
              'otherNames': data['otherNames']?.toString() ?? 'N/A',
              'gender': data['gender']?.toString() ?? 'N/A',
              'dateOfBirth': data['dateOfBirth']?.toString() ?? 'N/A',
              'courses': data['courses']?.toString() ?? 'N/A',
              'faculties': data['faculties']?.toString() ?? 'N/A',
              'email': data['email']?.toString() ?? 'N/A',
              'status': data['status']?.toString() ?? 'Active',
              'idExpiry': data['idExpiry']?.toString() ?? 'N/A',
            } else ...{
              'username': data['username']?.toString() ?? 'N/A',
              'staffNo': data['staffNo']?.toString() ?? 'N/A',
              'name': data['names']?.toString() ?? 'Unknown',
              'department': data['department']?.toString() ?? 'N/A',
              'status': data['status']?.toString() ?? 'Active',
            },
            'message':
                data['message']?.toString() ?? 'Identity verified successfully',
          };
          await _saveCachedData();
          return result;
        } else {
          print(
            '❌ Verification failed: ${data['message'] ?? 'Invalid response'}',
          );
          return {'success': false};
        }
      } else {
        _handleApiError(response, 'Failed to verify identity');
        return {'success': false};
      }
    } catch (e) {
      print('❌ Error verifying identity: $e');
      return {'success': false};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final visitorsJson = jsonEncode(_visitors.map((v) => v.toMap()).toList());
    final destinationsJson = jsonEncode(_destinations);
    final tagsJson = jsonEncode(_visitorTags);
    final gatesJson = jsonEncode(_gates);
    final countsJson = jsonEncode({
      'total_visit_count': _totalVisitCount,
      'todays_visit_count': _todaysVisitCount,
      'checked_in_count': _checkedInCount,
      'checked_out_count': _checkedOutCount,
    });

    await prefs.setString('token', _token ?? '');
    await prefs.setString('gate_id', _gateId ?? '');
    await prefs.setString('device_gate', _deviceGate ?? '');
    await prefs.setString('user_name', _userName ?? '');
    await prefs.setString('user_role', _userRole ?? '');
    await prefs.setString('user_position', _userPosition ?? '');
    await prefs.setString('visitors', visitorsJson);
    await prefs.setString('destinations', destinationsJson);
    await prefs.setString('visitor_tags', tagsJson);
    await prefs.setString('gates', gatesJson);
    await prefs.setString('visit_counts', countsJson);

    print(
      '💾 Saved to SharedPreferences: visitors=${_visitors.length} (${visitorsJson.length} bytes), '
      'gates=${_gates.length} (${gatesJson.length} bytes), tags=${_visitorTags.length} (${tagsJson.length} bytes), '
      'destinations=${_destinations.length} (${destinationsJson.length} bytes), counts=${countsJson.length} bytes, '
      'token=${_token?.length ?? 0} bytes',
    );
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    _token =
        prefs.getString('token')?.isNotEmpty == true
            ? prefs.getString('token')
            : null;
    _gateId =
        prefs.getString('gate_id')?.isNotEmpty == true
            ? prefs.getString('gate_id')
            : null;
    _deviceGate =
        prefs.getString('device_gate')?.isNotEmpty == true
            ? prefs.getString('device_gate')
            : null;
    _userName =
        prefs.getString('user_name')?.isNotEmpty == true
            ? prefs.getString('user_name')
            : null;
    _userRole =
        prefs.getString('user_role')?.isNotEmpty == true
            ? prefs.getString('user_role')
            : null;
    _userPosition =
        prefs.getString('user_position')?.isNotEmpty == true
            ? prefs.getString('user_position')
            : null;

    final cachedVisitors = prefs.getString('visitors');
    if (cachedVisitors != null && cachedVisitors.isNotEmpty) {
      try {
        _visitors =
            (jsonDecode(cachedVisitors) as List)
                .map((v) => Visitor.fromMap(Map<String, dynamic>.from(v)))
                .toList();
        print(
          '✅ Loaded ${_visitors.length} visitors from SharedPreferences (${cachedVisitors.length} bytes)',
        );
      } catch (e) {
        print('❌ Error loading visitors from SharedPreferences: $e');
        _visitors = [];
      }
    } else {
      _visitors = [];
    }

    final cachedDestinations = prefs.getString('destinations');
    if (cachedDestinations != null && cachedDestinations.isNotEmpty) {
      try {
        _destinations =
            (jsonDecode(cachedDestinations) as List)
                .cast<Map<String, dynamic>>();
        print(
          '✅ Loaded ${_destinations.length} destinations from SharedPreferences (${cachedDestinations.length} bytes)',
        );
      } catch (e) {
        print('❌ Error loading destinations from SharedPreferences: $e');
        _destinations = [
          {'id': '1', 'name': 'Default Destination'},
        ];
      }
    } else {
      _destinations = [
        {'id': '1', 'name': 'Default Destination'},
      ];
    }

    final cachedTags = prefs.getString('visitor_tags');
    if (cachedTags != null && cachedTags.isNotEmpty) {
      try {
        _visitorTags =
            (jsonDecode(cachedTags) as List).cast<Map<String, dynamic>>();
        print(
          '✅ Loaded ${_visitorTags.length} visitor tags from SharedPreferences (${cachedTags.length} bytes)',
        );
      } catch (e) {
        print('❌ Error loading visitor tags from SharedPreferences: $e');
        _visitorTags = [];
      }
    } else {
      _visitorTags = [];
    }

    final cachedGates = prefs.getString('gates');
    if (cachedGates != null && cachedGates.isNotEmpty) {
      try {
        final decodedGates = jsonDecode(cachedGates) as List;
        _gates =
            decodedGates
                .map(
                  (gate) => {
                    'id': gate['id']?.toString() ?? '',
                    'name': gate['name']?.toString() ?? 'Unknown Gate',
                  },
                )
                .toList();
        _gateMap = {for (var g in _gates) g['name']!: g['id']!};
        print(
          '✅ Loaded ${_gates.length} gates from SharedPreferences (${cachedGates.length} bytes)',
        );
      } catch (e) {
        print('❌ Error loading gates from SharedPreferences: $e');
        _gates = [
          {'id': '1', 'name': 'Default Gate'},
        ];
        _gateMap = {'Default Gate': '1'};
      }
    } else {
      _gates = [
        {'id': '1', 'name': 'Default Gate'},
      ];
      _gateMap = {'Default Gate': '1'};
    }

    final cachedCounts = prefs.getString('visit_counts');
    if (cachedCounts != null && cachedCounts.isNotEmpty) {
      try {
        final counts = jsonDecode(cachedCounts) as Map<String, dynamic>;
        _totalVisitCount = counts['total_visit_count']?.toInt() ?? 0;
        _todaysVisitCount = counts['todays_visit_count']?.toInt() ?? 0;
        _checkedInCount = counts['checked_in_count']?.toInt() ?? 0;
        _checkedOutCount = counts['checked_out_count']?.toInt() ?? 0;
        print(
          '✅ Loaded visit counts from SharedPreferences: total=$_totalVisitCount, today=$_todaysVisitCount, '
          'checked_in=$_checkedInCount, checked_out=$_checkedOutCount (${cachedCounts.length} bytes)',
        );
      } catch (e) {
        print('❌ Error loading visit counts from SharedPreferences: $e');
        _totalVisitCount = 0;
        _todaysVisitCount = 0;
        _checkedInCount = 0;
        _checkedOutCount = 0;
      }
    } else {
      _totalVisitCount = 0;
      _todaysVisitCount = 0;
      _checkedInCount = 0;
      _checkedOutCount = 0;
    }
  }

  void _handleApiError(http.Response response, String defaultMessage) {
    String errorMessage = defaultMessage;
    try {
      if (response.body.startsWith('<!DOCTYPE html') ||
          response.body.contains('<html')) {
        errorMessage =
            '$defaultMessage: Server returned HTML instead of JSON (Status ${response.statusCode})';
      } else {
        final errorData = jsonDecode(response.body);
        errorMessage =
            errorData['message']?.toString() ??
            errorData['error']?.toString() ??
            'Status ${response.statusCode}';
        switch (response.statusCode) {
          case 400:
            errorMessage = 'Invalid request: $errorMessage';
            break;
          case 401:
            errorMessage = 'Session expired. Please log in again.';
            break;
          case 403:
            errorMessage =
                errorData['error'] == 'Gate not assigned to user'
                    ? 'Access denied: Gate not assigned to user.'
                    : 'Access denied: $errorMessage';
            break;
          case 404:
            errorMessage = 'Resource not found: $errorMessage';
            break;
          case 429:
            errorMessage = 'Too many requests. Please try again later.';
            break;
          case 500:
            errorMessage = 'Server error: $errorMessage';
            break;
          default:
            errorMessage = '$defaultMessage: $errorMessage';
        }
      }
    } catch (e) {
      errorMessage =
          '$defaultMessage: Invalid response format (Status ${response.statusCode})';
    }
    print('❌ API error: $errorMessage');
  }

  Future<http.Response> _retryApiCall(
    Future<http.Response> Function() apiCall, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    dynamic error;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final response = await apiCall().timeout(Duration(seconds: 10));
        print(
          '📥 API response: Status ${response.statusCode}, Body: ${response.body}',
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else {
          error = Exception('Request failed: Status ${response.statusCode}');
          _handleApiError(response, 'API call failed');
          throw error;
        }
      } catch (e) {
        error = e;
        print('❌ API attempt $attempt failed: $e');
        if (attempt == maxRetries) throw error;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    throw error;
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
    if (idType == 'passport_number' &&
        !RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(idNumber)) {
      return 'Passport number must be 6-12 alphanumeric characters';
    }
    if (idType == 'birth_certificate_number' &&
        !RegExp(r'^[A-Za-z0-9]{8,12}$').hasMatch(idNumber)) {
      return 'Birth certificate number must be 8-12 alphanumeric characters';
    }
    if (idType == 'driving_licence' &&
        !RegExp(r'^[A-Za-z0-9]{8,12}$').hasMatch(idNumber)) {
      return 'Driving licence must be 8-12 alphanumeric characters';
    }
    return null;
  }

  String _parseErrorMessage(String error) {
    if (error.contains('Failed to connect') ||
        error.contains('SocketException')) {
      return 'Network error: Unable to connect to the server.';
    } else if (error.contains('TimeoutException')) {
      return 'Request timed out. Please try again later.';
    } else if (error.contains('Invalid response format')) {
      return 'Invalid response from server.';
    } else {
      return 'An unexpected error occurred: $error';
    }
  }
}
