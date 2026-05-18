import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

/// Exception for authentication-related errors
class VisitorAuthException implements Exception {
  final String message;
  VisitorAuthException(this.message);
  @override
  String toString() => message;
}

/// Exception for validation-related errors
class VisitorValidationException implements Exception {
  final String message;
  VisitorValidationException(this.message);
  @override
  String toString() => message;
}

/// Exception for network-related errors
class VisitorNetworkException implements Exception {
  final String message;
  VisitorNetworkException(this.message);
  @override
  String toString() => message;
}

/// Manages visitor-related data and operations
class VisitorProvider extends ChangeNotifier {
  List<Visitor> _visitors = [];
  List<Map<String, String>> _gates = [];
  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _visitorTags = [];
  bool _isLoading = false;
  String? _token;
  String? _deviceGate;
  String? _gateId;
  int _checkedInCount = 0;
  int _checkedOutCount = 0;
  int _todaysTotalCount = 0;

  Map<String, String>? _gateMap;
  String? _userRole;
  String? _userPosition;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userAvatarUrl;
  bool _isActive = true;
  bool _isDisposed = false;
  bool _isRefreshing = false;

  // Getters
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
  int get checkedInCount => _checkedInCount;
  int get checkedOutCount => _checkedOutCount;
  int get todaysTotalCount => _todaysTotalCount;
  Map<String, String>? get gateMap => _gateMap;
  String? get userRole => _userRole;
  String? get userPosition => _userPosition;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userAvatarUrl => _userAvatarUrl;

  Map<String, String?> get user => {
    'name': _userName,
    'email': _userEmail,
    'phone': _userPhone,
    'role': _userRole,
    'position': _userPosition,
    'avatar_url': _userAvatarUrl,
  };
  get floors => null;
  String? get token => _token;

  @override
  void dispose() {
    _isDisposed = true;
    _isActive = false;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed && _isActive) {
      notifyListeners();
    }
  }

  /// Retrieves authentication token from SharedPreferences
  Future<String?> _getTokenFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        debugPrint(
          '✅ Retrieved auth token from SharedPreferences: ${token.substring(0, 10)}...',
        );
        return token;
      }
      debugPrint('⚠️ No valid auth token found in SharedPreferences');
      return null;
    } catch (e) {
      debugPrint('❌ Error retrieving token from SharedPreferences: $e');
      throw VisitorAuthException('Failed to retrieve authentication token: $e');
    }
  }

  /// Loads authentication data from SharedPreferences
  Future<void> _loadTokenFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = await _getTokenFromPreferences();
      _gateId =
          prefs.getString('gate_id')?.isNotEmpty == true
              ? prefs.getString('gate_id')
              : null;
      _deviceGate =
          prefs.getString('device_gate')?.isNotEmpty == true
              ? prefs.getString('device_gate')
              : 'Gate A';
      _userName =
          prefs.getString('userName')?.isNotEmpty == true
              ? prefs.getString('userName')
              : null;
      _userEmail =
          prefs.getString('userEmail')?.isNotEmpty == true
              ? prefs.getString('userEmail')
              : null;
      _userPhone =
          prefs.getString('userPhone')?.isNotEmpty == true
              ? prefs.getString('userPhone')
              : null;
      _userRole =
          prefs.getString('userRole')?.isNotEmpty == true
              ? prefs.getString('userRole')
              : null;
      _userPosition =
          prefs.getString('userPosition')?.isNotEmpty == true
              ? prefs.getString('userPosition')
              : null;
      _userAvatarUrl = prefs.getString('userAvatarUrl');
      debugPrint(
        _token != null
            ? '✅ Loaded auth token: ${_token!.substring(0, 10)}...'
            : '⚠️ No auth token found',
      );
      debugPrint(
        _gateId != null ? '✅ Loaded gateId: $_gateId' : '⚠️ No gateId found',
      );
      debugPrint('📴 Loaded cached gate: $_deviceGate');
    } catch (e) {
      debugPrint('❌ Error loading token or gateId: $e');
      throw VisitorAuthException('Failed to load authentication data: $e');
    }
  }

  /// Debugs SharedPreferences contents
  Future<void> debugSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('SharedPreferences Contents:');
      debugPrint('  token: ${prefs.getString('token')}');
      debugPrint('  gate_id: ${prefs.getString('gate_id')}');
      debugPrint('  device_gate: ${prefs.getString('device_gate')}');
      debugPrint('  userName: ${prefs.getString('userName')}');
      debugPrint('  userEmail: ${prefs.getString('userEmail')}');
      debugPrint('  userPhone: ${prefs.getString('userPhone')}');
      debugPrint('  userRole: ${prefs.getString('userRole')}');
      debugPrint('  userPosition: ${prefs.getString('userPosition')}');
      debugPrint('  userAvatarUrl: ${prefs.getString('userAvatarUrl')}');
    } catch (e) {
      debugPrint('❌ Error debugging SharedPreferences: $e');
    }
  }

  /// Validates the current authentication token
  Future<bool> _validateToken() async {
    final token = await _getTokenFromPreferences();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ No valid token found for validation');
      return false;
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppStrings.apiBaseUrl}/api/user'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ Token validated successfully');
        return true;
      } else {
        debugPrint(
          '🔑 Token validation failed: Status ${response.statusCode}, Body: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('🔑 Token validation failed: $e');
      throw VisitorAuthException('Token validation failed: $e');
    }
  }

  /// Checks if a visitor exists with the given ID number and type
  Future<Map<String, dynamic>?> checkExistingVisitor(
    String idNumber,
    String idType,
  ) async {
    if (!_validateInput(idNumber) || !_validateInput(idType)) {
      throw VisitorValidationException('ID number and type are required');
    }

    try {
      final token = await _getTokenFromPreferences();
      final prefs = await SharedPreferences.getInstance();
      final gateId = prefs.getString('gate_id');
      if (token == null || gateId == null) {
        debugPrint(
          '⚠️ No authentication token or gate ID found for checking visitor',
        );
        throw VisitorAuthException('No authentication token or gate ID found');
      }

      if (!RegExp(r'^\d+$').hasMatch(gateId)) {
        debugPrint('⚠️ Invalid gate ID format: $gateId');
        throw VisitorValidationException('Invalid gate ID format');
      }

      final validationError = validateIdNumber(idNumber, idType);
      if (validationError != null) {
        debugPrint(
          '⚠️ Validation error for ID $idNumber ($idType): $validationError',
        );
        throw VisitorValidationException(validationError);
      }

      debugPrint(
        '📤 Sending check visitor request with token: ${token.substring(0, 10)}..., gate_id: $gateId, idNumber: $idNumber, idType: $idType',
      );

      final response = await _retryApiCall(
        () => http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/check-visitor'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identification_type': idType,
            'identification_number': _sanitizeInput(idNumber),
            'gate_id': gateId,
          }),
        ),
        maxRetries: 2,
      );

      debugPrint(
        '📥 Check visitor response: ${response.statusCode}, ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['visitor'] != null) {
          final visitor = data['visitor'] as Map<String, dynamic>;
          final isCheckedIn =
              data['alreadyCheckedIn'] == true ||
              (visitor['status'] != null && visitor['status'] == 'checked_in');
          final isCheckedOut =
              visitor['status'] == 'checked_out' ||
              visitor['check_out_time'] != null;
          final visitorStatus =
              isCheckedIn ? 'active' : (isCheckedOut ? 'completed' : 'unknown');

          data['alreadyCheckedIn'] = isCheckedIn;
          data['visitorStatus'] = visitorStatus;

          debugPrint(
            'Visitor status: ID=$idNumber, exists=${data['exists']}, alreadyCheckedIn=$isCheckedIn, status=${visitor['status']}, check_out_time=${visitor['check_out_time']}, computedStatus=$visitorStatus',
          );

          if (visitor['tag'] != null) {
            final tag = visitor['tag'] as Map<String, dynamic>;
            final tagNumber = tag['tag_number']?.toString();
            if (tagNumber == null || tagNumber.isEmpty) {
              debugPrint(
                '⚠️ Visitor tag has empty tag_number: $tag, using fallback Tag ${tag['id']}',
              );
              tag['tag_number'] = 'Tag ${tag['id'] ?? 'Unknown'}';
            }
          }
        }
        return data;
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No visitor found for ID $idNumber');
        return {
          'exists': false,
          'visitor': null,
          'message': 'No visitor found',
          'visitorStatus': 'none',
        };
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed: Invalid or expired token');
        await _clearAuthenticationState();
        throw VisitorAuthException(
          'Authentication failed: Invalid or expired token',
        );
      } else if (response.statusCode == 419) {
        debugPrint('❌ CSRF token mismatch');
        throw VisitorAuthException('CSRF token mismatch');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Validation failed';
        final details =
            errorData['details']?.toString() ?? 'No details provided';
        debugPrint('❌ Validation error: $errorMessage, Details: $details');
        throw VisitorValidationException('$errorMessage: $details');
      }
      throw VisitorNetworkException(
        'Failed to check visitor: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error checking existing visitor: $e');
      rethrow;
    }
  }

  Future<void> createVisitForExistingVisitor(Map<String, dynamic> visit) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint(
        '⚠️ Cannot create visit: No authentication token or gate ID found',
      );
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;

    try {
      final isValidToken = await _validateToken();
      if (!isValidToken) {
        debugPrint('⚠️ Invalid or expired token');
        throw VisitorAuthException('Session expired. Please log in again.');
      }
    } catch (e) {
      debugPrint('❌ Token validation error: $e');
      throw VisitorAuthException('Failed to validate token: $e');
    }

    try {
      final payload = {
        'visitor_id': Visitor.parseInt(visit['visitor_id'], 'visitor_id'),
        'visitor_destination_id': Visitor.parseInt(
          visit['visitor_destination_id'],
          'visitor_destination_id',
        ),
        'visitor_tag_id': Visitor.parseInt(
          visit['visitor_tag_id'],
          'visitor_tag_id',
        ),
        'gate_id': Visitor.parseInt(visit['gate_id'], 'gate_id'),
        // Include visit details only if they are provided
        if (visit['visit_type'] != null) ...{
          'visit_type': _sanitizeInput(visit['visit_type']),
          if (visit['visit_type'] == 'staff') ...{
            if (visit['host']?.isNotEmpty == true)
              'host': _sanitizeInput(visit['host']),
            if (visit['host_phone']?.isNotEmpty == true)
              'host_phone': _sanitizeInput(
                visit['host_phone']?.trim().replaceFirst(RegExp(r'^\+254'), ''),
              ),
            if (visit['host_email']?.isNotEmpty == true)
              'host_email': _sanitizeInput(visit['host_email']),
            if (visit['host_department']?.isNotEmpty == true)
              'host_department': _sanitizeInput(visit['host_department']),
            if (visit['host_position']?.isNotEmpty == true)
              'host_position': _sanitizeInput(visit['host_position']),
          },
          if (visit['visit_type'] == 'office') ...{
            if (visit['office_name']?.isNotEmpty == true)
              'office_name': _sanitizeInput(visit['office_name']),
            if (visit['office_phone']?.isNotEmpty == true)
              'office_phone': _sanitizeInput(
                visit['office_phone']?.trim().replaceFirst(
                  RegExp(r'^\+254'),
                  '',
                ),
              ),
            if (visit['office_email']?.isNotEmpty == true)
              'office_email': _sanitizeInput(visit['office_email']),
            if (visit['office_department']?.isNotEmpty == true)
              'office_department': _sanitizeInput(visit['office_department']),
            if (visit['office_contact_person']?.isNotEmpty == true)
              'office_contact_person': _sanitizeInput(
                visit['office_contact_person'],
              ),
          },
          if (visit['had_appointment'] != null)
            'had_appointment': visit['had_appointment'],
          if (visit['appointment_details']?.isNotEmpty == true)
            'appointment_details': _sanitizeInput(visit['appointment_details']),
          if (visit['vehicle_type']?.isNotEmpty == true)
            'vehicle_type': _sanitizeInput(visit['vehicle_type']),
          if (visit['vehicle_registration']?.isNotEmpty == true)
            'vehicle_registration': _sanitizeInput(
              visit['vehicle_registration'],
            ),
        },
      }..removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );

      debugPrint('📤 Sending payload to /api/visits: ${jsonEncode(payload)}');

      final response = await _retryApiCall(
        () => http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/visits'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        ),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 201) {
        debugPrint('✅ Visit created successfully for existing visitor');
      } else {
        if (response.statusCode == 422) {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message']?.toString() ??
              errorData['error']?.toString() ??
              'Validation failed';
          final validationErrors =
              errorData['details'] != null
                  ? (errorData['details'] as Map<String, dynamic>).entries
                      .map((e) => '${e.key}: ${e.value.join(', ')}')
                      .join('; ')
                  : 'No specific error details provided';
          debugPrint('❌ Validation error: $errorMessage - $validationErrors');
          throw VisitorValidationException('$errorMessage - $validationErrors');
        } else if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        debugPrint('❌ API error: ${response.statusCode} - ${response.body}');
        throw VisitorNetworkException(
          'Failed to create visit: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Create visit error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Initializes the provider with authentication data
  Future<void> init(String token, String gateId, String deviceGate) async {
    if (_isDisposed) return;

    if (!_validateInput(token) ||
        !_validateInput(gateId) ||
        !_validateInput(deviceGate)) {
      throw VisitorValidationException('Invalid initialization parameters');
    }

    _token = token;
    _gateId = gateId;
    _deviceGate = deviceGate;

    await _loadCachedData();
    await debugSharedPreferences();

    if (isAuthenticated) {
      _isLoading = true;
      _safeNotifyListeners();
      try {
        final isTokenValid = await _validateToken();
        if (!isTokenValid) {
          debugPrint('🔑 Token validation failed, clearing authentication');
          await _clearAuthenticationState();
          _isLoading = false;
          _safeNotifyListeners();
          return;
        }

        await refreshData();
      } catch (e) {
        debugPrint('❌ Initialization error: $e');
        if (e is VisitorAuthException) {
          await _clearAuthenticationState();
        }
      } finally {
        _isLoading = false;
        _safeNotifyListeners();
      }
    } else {
      await loadGates().catchError((e) {
        debugPrint('❌ Error loading gates: $e');
      });
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Authenticates a user with the provided credentials
  Future<void> login(
    String username,
    String password,
    String gateId,
    String deviceGate,
  ) async {
    if (_isDisposed) return;

    if (!_validateInput(username) ||
        !_validateInput(password) ||
        !_validateInput(gateId)) {
      throw VisitorValidationException(
        'Invalid username, password, or gate ID',
      );
    }

    _isLoading = true;
    _safeNotifyListeners();

    try {
      int parsedGateId;
      try {
        parsedGateId = int.parse(gateId);
      } catch (e) {
        throw VisitorValidationException('Invalid gate ID format');
      }

      debugPrint(
        '🔍 Attempting login with Username: $username, Gate: $deviceGate (ID: $gateId)',
      );
      final response = await _retryApiCall(
        () => http.post(
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
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['token'] == null ||
            data['user'] == null ||
            data['gate_id'] == null) {
          throw VisitorAuthException(
            'Invalid response from server: Missing token or user data',
          );
        }

        _token = data['token']?.toString();
        _gateId = data['gate_id']?.toString();
        _deviceGate = data['gate']?.toString() ?? deviceGate;
        _userName = data['user']['name']?.toString();
        _userEmail = data['user']['email']?.toString();
        _userPhone = data['user']['phone_number']?.toString();
        _userRole = data['user']['role']?.toString();
        _userPosition = data['user']['position']?.toString();
        _userAvatarUrl = data['user']['avatar_url']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token ?? '');
        await prefs.setString('gate_id', _gateId ?? '');
        await prefs.setString('device_gate', _deviceGate ?? '');
        await prefs.setString('userName', _userName ?? '');
        await prefs.setString('userEmail', _userEmail ?? '');
        await prefs.setString('userPhone', _userPhone ?? '');
        await prefs.setString('userRole', _userRole ?? '');
        await prefs.setString('userPosition', _userPosition ?? '');
        if (_userAvatarUrl != null) {
          await prefs.setString('userAvatarUrl', _userAvatarUrl!);
        } else {
          await prefs.remove('userAvatarUrl');
        }

        debugPrint(
          '📝 Saved token to SharedPreferences: ${_token!.substring(0, 10)}...',
        );
        debugPrint(
          '📴 Saved gate to preferences: ID=$_gateId, Name=$_deviceGate',
        );
        await debugSharedPreferences();

        _visitorTags = [];
        final rawTags = data['visitor_tags'];
        if (rawTags != null && rawTags is List) {
          _visitorTags =
              rawTags
                  .where((tag) => tag is Map)
                  .map(
                    (tag) => ({
                      'id': tag['id']?.toString() ?? '',
                      'tag_number': tag['tag_number']?.toString() ?? '',
                      'visitor_gate_id':
                          tag['visitor_gate_id']?.toString() ?? '',
                      'visitor_gate_name':
                          tag['visitor_gate_name']?.toString() ?? '',
                      'is_assigned': tag['is_assigned'] == true,
                    }),
                  )
                  .where((tag) => tag.isNotEmpty)
                  .toList();
        }

        debugPrint('✅ Login successful, navigating to home');
        await _saveCachedData();
        await refreshData();
      } else {
        _handleApiError(response, 'Login failed');
        throw VisitorAuthException('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Loads available gates from the API
  Future<void> loadGates() async {
    if (_isDisposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final token = await _getTokenFromPreferences();
      final response = await _retryApiCall(
        () => http.get(
          Uri.parse('${AppStrings.apiBaseUrl}/api/gates'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': token != null ? 'Bearer $token' : '',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> gatesData = data['data'] ?? data['gates'] ?? [];

        if (gatesData.isNotEmpty) {
          _gates =
              gatesData
                  .map(
                    (gate) => ({
                      'id': gate['id']?.toString() ?? '',
                      'name': gate['name']?.toString() ?? 'Unknown Gate',
                    }),
                  )
                  .toList();
          _gateMap = {for (var gate in _gates) gate['name']!: gate['id']!};
          debugPrint('✅ Loaded ${_gates.length} gates: $_gates');
          await _saveCachedData();
        } else {
          _gates = [
            {'id': '1', 'name': 'Default Gate'},
          ];
          _gateMap = {'Default Gate': '1'};
          debugPrint('⚠️ No gates available from API');
          await _saveCachedData();
        }
      } else {
        _handleApiError(response, 'Failed to load gates');
        if (response.statusCode == 401) {
          await _clearAuthenticationState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading gates: $e');
      if (_gates.isEmpty) {
        _gates = [
          {'id': '1', 'name': 'Default Gate'},
        ];
        _gateMap = {'Default Gate': '1'};
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Loads available destinations from the API
  Future<void> loadDestinations() async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot load destinations: Not authenticated');
      throw VisitorAuthException('Not authenticated');
    }

    _token = token;
    _gateId = gateId;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final response = await _retryApiCall(
        () => http.get(
          Uri.parse('${AppStrings.apiBaseUrl}/api/destinations'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
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
          await _saveCachedData();
        } else {
          throw VisitorValidationException('Invalid destinations data format');
        }
      } else {
        _handleApiError(response, 'Failed to load destinations');
        if (response.statusCode == 401) {
          await _clearAuthenticationState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading destinations: $e');
      if (_destinations.isEmpty) {
        _destinations = [
          {'id': '1', 'name': 'Default Destination'},
        ];
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Loads visitor tags for the current gate
  Future<void> loadVisitorTags() async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot load visitor tags: Not authenticated');
      throw VisitorAuthException('Not authenticated');
    }

    _token = token;
    _gateId = gateId;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final response = await _retryApiCall(
        () => http.get(
          Uri.parse(
            '${AppStrings.apiBaseUrl}/api/gates-with-tags?gate_id=$gateId',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['gates'] != null && data['gates'] is List) {
          _visitorTags =
              (data['gates'] as List)
                  .expand(
                    (gate) =>
                        (gate['tags'] as List?)?.map<Map<String, dynamic>>(
                          (tag) => ({
                            'id': tag['id']?.toString() ?? '',
                            'tag_number': tag['tag_number']?.toString() ?? '',
                            'visitor_gate_id': gate['id']?.toString() ?? '',
                            'visitor_gate_name': gate['name']?.toString() ?? '',
                            'is_assigned': tag['is_assigned'] == true,
                          }),
                        ) ??
                        <Map<String, dynamic>>[],
                  )
                  .toList();
          await _saveCachedData();
        } else {
          throw VisitorValidationException('Invalid visitor tags data format');
        }
      } else {
        _handleApiError(response, 'Failed to load visitor tags');
        if (response.statusCode == 401) {
          await _clearAuthenticationState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading visitor tags: $e');
      if (_visitorTags.isEmpty) {
        _visitorTags = [];
      }
      await _saveCachedData();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Checks visitor by ID type and number
  Future<Map<String, dynamic>?> checkVisitor(
    String idType,
    String idNumber,
  ) async {
    if (_isDisposed) return null;

    if (!_validateInput(idType) || !_validateInput(idNumber)) {
      throw VisitorValidationException('ID type and number are required');
    }

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot check visitor: Not authenticated');
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final response = await _retryApiCall(
        () => http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/visitors/check'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'identification_type': idType,
            'identification_number': _sanitizeInput(idNumber),
            'gate_id': gateId,
          }),
        ),
      );

      debugPrint(
        '📥 Check visitor response: ${response.statusCode}, ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveCachedData();
        return data;
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw VisitorAuthException(
          'Authentication failed: Invalid or expired token',
        );
      }
      throw VisitorNetworkException(
        'Failed to check visitor: ${response.statusCode} - ${response.body}',
      );
    } catch (e) {
      debugPrint('❌ Error checking visitor: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> registerVisitor(Visitor visitor) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint(
        '⚠️ Cannot register visitor: No authentication token or gate ID found',
      );
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;

    try {
      final isValidToken = await _validateToken();
      if (!isValidToken) {
        debugPrint('⚠️ Invalid or expired token');
        throw VisitorAuthException('Session expired. Please log in again.');
      }
    } catch (e) {
      debugPrint('❌ Token validation error: $e');
      throw VisitorAuthException('Failed to validate token: $e');
    }

    int? visitorId;
    try {
      final existingVisitor = await checkExistingVisitor(
        visitor.identificationNumber ?? '',
        visitor.identificationType ?? '',
      );
      if (existingVisitor != null && existingVisitor['exists'] == true) {
        visitorId = Visitor.parseInt(existingVisitor['id'], 'visitor_id');
        debugPrint('✅ Existing visitor found: ID $visitorId');
      }
    } catch (e) {
      if (e is! VisitorAuthException) {
        rethrow;
      }
      debugPrint('❌ Error checking existing visitor: $e');
      throw e;
    }

    _isLoading = true;
    _safeNotifyListeners();

    int? visitorTagId;
    try {
      visitorTagId = await getAvailableVisitorTagId(gateId: gateId);
      debugPrint('✅ Retrieved available visitor tag ID: $visitorTagId');
    } catch (e) {
      debugPrint('❌ Failed to get available tag: $e');
      throw VisitorValidationException(
        'Unable to register visitor: No available tags: $e',
      );
    }

    try {
      final payload = {
        if (visitorId != null) 'visitor_id': visitorId,
        if (visitorId == null) ...{
          'name': _sanitizeInput(visitor.name),
          'phone_number':
              visitor.phoneNumber?.trim().replaceFirst(RegExp(r'^\+254'), '') ??
              '',
          'phone_country_code': visitor.phoneCountryCode ?? '+254',
          'is_minor': visitor.isMinor ?? false,
          'guardian_phone':
              visitor.isMinor == true && visitor.guardianPhone != null
                  ? visitor.guardianPhone!.trim().replaceFirst(
                    RegExp(r'^\+254'),
                    '',
                  )
                  : null,
          'identification_type': _sanitizeInput(visitor.identificationType),
          'identification_number': _sanitizeInput(visitor.identificationNumber),
          'gender': _sanitizeInput(visitor.gender),
        },
        'visitor_tag_id': Visitor.parseInt(visitorTagId, 'visitor_tag_id'),
        'destination_id': Visitor.parseInt(
          visitor.destinationId,
          'destination_id',
        ),
        'visitor_gate_id': Visitor.parseInt(
          visitor.gateId ?? gateId,
          'visitor_gate_id',
        ),
        if (visitor.hadAppointment != null)
          'had_appointment': visitor.hadAppointment,
        if (visitor.appointmentDetails?.isNotEmpty ?? false)
          'appointment_details': _sanitizeInput(visitor.appointmentDetails),
        if (visitor.vehicleType?.isNotEmpty ?? false)
          'vehicle_type': _sanitizeInput(visitor.vehicleType),
        if (visitor.vehicleRegistration?.isNotEmpty ?? false)
          'vehicle_registration': _sanitizeInput(visitor.vehicleRegistration),
        if (visitor.visitType != null) ...{
          'visit_type': _sanitizeInput(visitor.visitType),
          if (visitor.visitType == 'staff' && visitor.host != null) ...{
            'host': _sanitizeInput(visitor.host!['name']),
            'host_phone':
                visitor.host!['phone']?.trim().replaceFirst(
                  RegExp(r'^\+254'),
                  '',
                ) ??
                '',
            'host_email':
                visitor.host!['email']?.isNotEmpty == true
                    ? _sanitizeInput(visitor.host!['email'])
                    : null,
            'host_department':
                visitor.host!['department']?.isNotEmpty == true
                    ? _sanitizeInput(visitor.host!['department'])
                    : null,
            'host_position':
                visitor.host!['position']?.isNotEmpty == true
                    ? _sanitizeInput(visitor.host!['position'])
                    : null,
          },
          if (visitor.visitType == 'office') ...{
            'office_name': _sanitizeInput(visitor.officeName),
            'office_phone':
                visitor.officePhone?.trim().replaceFirst(
                  RegExp(r'^\+254'),
                  '',
                ) ??
                '',
            'office_email':
                visitor.officeEmail?.isNotEmpty == true
                    ? _sanitizeInput(visitor.officeEmail)
                    : null,
            'office_department':
                visitor.officeDepartment?.isNotEmpty == true
                    ? _sanitizeInput(visitor.officeDepartment)
                    : null,
            'office_contact_person': _sanitizeInput(
              visitor.officeContactPerson,
            ),
          },
        },
      }..removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );

      debugPrint(
        '📤 Sending payload to /api/visitors-store: ${jsonEncode(payload)}',
      );

      final response = await _retryApiCall(
        () => http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/visitors-store'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        ),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      final data = jsonDecode(response.body);
      debugPrint('📝 Raw visitor map: ${jsonEncode(data['visitor'])}');

      if (response.statusCode == 201) {
        if (data['visitor'] == null) {
          debugPrint('❌ Invalid response: Missing visitor data');
          throw VisitorValidationException(
            'Invalid response: Missing visitor data',
          );
        }
        final visitorMap = Map<String, dynamic>.from(data['visitor']);
        debugPrint('📝 Original visitor map: ${jsonEncode(visitorMap)}');

        try {
          visitorMap['id'] =
              Visitor.parseInt(visitorMap['id'], 'id') ??
              (throw VisitorValidationException(
                'Invalid visitor id: ${visitorMap['id']}',
              ));
          if (visitorMap['visitor_tag_id'] != null) {
            visitorMap['visitor_tag_id'] = Visitor.parseInt(
              visitorMap['visitor_tag_id'],
              'visitor_tag_id',
            );
          }
          if (visitorMap['destination_id'] != null) {
            visitorMap['destination_id'] = Visitor.parseInt(
              visitorMap['destination_id'],
              'destination_id',
            );
          }
          if (visitorMap['gate_id'] != null) {
            visitorMap['gate_id'] = Visitor.parseInt(
              visitorMap['gate_id'],
              'gate_id',
            );
          }
          debugPrint('📝 Preprocessed visitor map: ${jsonEncode(visitorMap)}');
        } catch (e) {
          debugPrint('❌ Error preprocessing visitor map: $e');
          throw VisitorValidationException(
            'Failed to preprocess visitor map: $e',
          );
        }

        try {
          final newVisitor = Visitor.fromMap(visitorMap);
          _visitors.add(newVisitor);
          debugPrint('✅ Visitor registered successfully: ${newVisitor.name}');
        } catch (e) {
          debugPrint('❌ Error creating Visitor object: $e');
          throw VisitorValidationException(
            'Failed to create Visitor object: $e',
          );
        }
      } else {
        if (response.statusCode == 422) {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message']?.toString() ??
              errorData['error']?.toString() ??
              'Validation failed';
          final validationErrors =
              errorData['details'] != null
                  ? (errorData['details'] as Map<String, dynamic>).entries
                      .map((e) => '${e.key}: ${e.value.join(', ')}')
                      .join('; ')
                  : 'No specific error details provided';
          debugPrint('❌ Validation error: $errorMessage - $validationErrors');
          throw VisitorValidationException('$errorMessage - $validationErrors');
        } else if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        debugPrint('❌ API error: ${response.statusCode} - ${response.body}');
        throw VisitorNetworkException(
          'Failed to register visitor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    if (_isDisposed) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final token = await _getTokenFromPreferences();
      if (token != null && token.isNotEmpty) {
        final response = await _retryApiCall(
          () => http.post(
            Uri.parse('${AppStrings.apiBaseUrl}/api/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

        if (response.statusCode != 200 && response.statusCode != 401) {
          _handleApiError(response, 'Logout failed');
        }
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    } finally {
      await _clearAuthenticationState();
      await _clearStoredData();
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Clears authentication state
  Future<void> _clearAuthenticationState() async {
    _token = null;
    _deviceGate = null;
    _gateId = null;
    _userRole = null;
    _userPosition = null;
    _userName = null;
    _userEmail = null;
    _userPhone = null;
    _userAvatarUrl = null;
    _visitors = [];
    _destinations = [];
    _visitorTags = [];
    _gates = [];
    _gateMap = null;
    _checkedInCount = 0;
    _checkedOutCount = 0;
    _todaysTotalCount = 0;
    await _saveCachedData();
    debugPrint('✅ Cleared authentication state');
  }

  /// Clears stored data from SharedPreferences
  Future<void> _clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ Cleared SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error clearing stored data: $e');
      throw VisitorAuthException('Failed to clear stored data: $e');
    }
  }

  Future<void> loadCheckedInVisitors() async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    final deviceGate =
        (await SharedPreferences.getInstance()).getString('device_gate') ??
        'Gate A';
    if (token == null || gateId == null) {
      debugPrint(
        '⚠️ Cannot load checked-in visitors: No authentication token or gate ID found',
      );
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;
    _deviceGate = deviceGate;

    _isLoading = true;
    _safeNotifyListeners();
    try {
      debugPrint(
        '🔑 Using token: ${token.substring(0, 10)}... for loading checked-in visitors',
      );
      final uri = Uri.parse(
        '${AppStrings.apiBaseUrl}/api/visitors/checked-in',
      ).replace(queryParameters: {'gate_id': gateId});
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      debugPrint('📡 Sending request to $uri with headers: $headers');
      final response = await _retryApiCall(
        () => http.get(uri, headers: headers),
      );

      debugPrint(
        '📋 Checked-in visitors response: status=${response.statusCode}, body=${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final visitorList = data['visitors'] ?? [];
        if (visitorList is! List || visitorList.isEmpty) {
          _visitors = [];
          _checkedInCount = 0;
          debugPrint('⚠️ No checked-in visitors found in response');
        } else {
          _visitors =
              visitorList.map((v) {
                final visitorMap = Map<String, dynamic>.from(
                  v['visitor'] ?? {},
                )..addAll({
                  'id': v['id']?.toString() ?? '',
                  'gate_id': gateId,
                  'gate': deviceGate,
                  'visitor_tag_id': v['visitor_tag_id']?.toString(),
                  'tag_number': v['visitor_tag_number']?.toString(),
                  'destination_id': v['visitor_destination_id']?.toString(),
                  'destination': v['visitor_destination_name']?.toString(),
                  'visit_type': v['host_type']?.toString(),
                  'check_in_time': v['check_in_time']?.toString(),
                  'check_out_time': v['check_out_time']?.toString(),
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
                  'office_name': v['office_name']?.toString(),
                  'office_phone': v['office_phone']?.toString(),
                  'office_email': v['office_email']?.toString(),
                  'office_department': v['office_department']?.toString(),
                  'office_contact_person':
                      v['office_contact_person']?.toString(),
                  'had_appointment':
                      v['had_appointment'], // Boolean as per server
                  'appointment_details': v['appointment_details']?.toString(),
                  'remarks': v['remarks']?.toString(),
                  'vehicle_type': v['vehicle_type']?.toString(),
                  'vehicle_registration': v['vehicle_registration']?.toString(),
                  'gender': v['visitor']['gender']?.toString(), // Add gender
                });
                return Visitor.fromMap(visitorMap);
              }).toList();
          _checkedInCount = _visitors.length;
          debugPrint(
            '👥 Loaded ${_visitors.length} checked-in visitors for gate \'$deviceGate\' (ID: $gateId)',
          );
        }
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to load checked-in visitors');
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        throw VisitorNetworkException(
          'Failed to load checked-in visitors: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading checked-in visitors: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Loads visit count for the specified time range
  Future<void> logVisitCount({String timeRange = 'Today'}) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint(
        '⚠️ Cannot load visit count: No authentication token or gate ID found',
      );
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;

    _isLoading = true;
    _safeNotifyListeners();
    try {
      final uri = Uri.parse(
        '${AppStrings.apiBaseUrl}/api/visit-count',
      ).replace(queryParameters: {'gate_id': gateId, 'time_range': timeRange});
      final response = await _retryApiCall(
        () => http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint(
        '📥 Visit count response: ${response.statusCode}, ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw VisitorNetworkException(
            'Failed to load visit count: ${data['message'] ?? 'Unknown error'}',
          );
        }
        _checkedInCount = data['checked_in_count']?.toInt() ?? 0;
        _checkedOutCount = data['checked_out_count']?.toInt() ?? 0;
        _todaysTotalCount = data['todays_total_count']?.toInt() ?? 0;
        await _saveCachedData();
        debugPrint(
          '✅ Visit counts loaded: checked_in=$_checkedInCount, checked_out=$_checkedOutCount, total_today=$_todaysTotalCount, time_range=$timeRange',
        );
      } else {
        _handleApiError(response, 'Failed to load visit count');
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        throw VisitorNetworkException(
          'Failed to load visit count: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading visit count: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Gets an available visitor tag ID
 /// Gets an available visitor tag ID
Future<int?> getAvailableVisitorTagId({String? gateId}) async {
  try {
    final token = await _getTokenFromPreferences();
    final currentGateId = gateId ?? _gateId;
    
    debugPrint('🔍 Fetching available tag - Token: ${token != null ? "Present" : "NULL"}, GateId: $currentGateId');
    
    if (token == null || currentGateId == null) {
      debugPrint('⚠️ Cannot fetch tags: Missing token or gate ID');
      throw VisitorValidationException('Missing authentication or gate information');
    }

    final uri = Uri.parse(
      '${AppStrings.apiBaseUrl}/api/visitor-tags',
    ).replace(
      queryParameters: {
        'unassigned': 'true',
        'gate_id': currentGateId,
      },
    );
    
    debugPrint('📡 Fetching tags from: $uri');
    
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    
    debugPrint('📥 Available tags response: ${response.statusCode}');
    debugPrint('📥 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Handle different response structures
      List<dynamic> tagsList = [];
      if (data['tags'] != null && data['tags'] is List) {
        tagsList = data['tags'];
        debugPrint('📋 Found tags in "tags" field: ${tagsList.length}');
      } else if (data['data'] != null && data['data'] is List) {
        tagsList = data['data'];
        debugPrint('📋 Found tags in "data" field: ${tagsList.length}');
      } else if (data is List) {
        tagsList = data;
        debugPrint('📋 Response is a list: ${tagsList.length}');
      } else if (data['visitor_tags'] != null && data['visitor_tags'] is List) {
        tagsList = data['visitor_tags'];
        debugPrint('📋 Found tags in "visitor_tags" field: ${tagsList.length}');
      }
      
      // Filter for unassigned tags
      final unassignedTags = tagsList.where((tag) {
        final isAssigned = tag['is_assigned'];
        return isAssigned == false || 
               isAssigned == 'false' || 
               isAssigned == 0 ||
               isAssigned == null;
      }).toList();
      
      debugPrint('✅ Found ${unassignedTags.length} unassigned tags out of ${tagsList.length} total');
      
      if (unassignedTags.isNotEmpty) {
        final tagId = unassignedTags.first['id'];
        final tagNumber = unassignedTags.first['tag_number'] ?? 'Unknown';
        debugPrint('🎫 Selected tag ID: $tagId, Number: $tagNumber');
        return tagId is int ? tagId : int.tryParse(tagId.toString());
      }
      
      debugPrint('⚠️ No unassigned visitor tags available for gate $currentGateId');
      throw VisitorValidationException('No unassigned visitor tags available');
    } else if (response.statusCode == 401) {
      debugPrint('🔐 Authentication failed when fetching tags');
      throw VisitorAuthException('Session expired. Please login again.');
    } else {
      debugPrint('❌ Failed to fetch tags: ${response.statusCode}');
      throw VisitorNetworkException('Failed to fetch available tags: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Error fetching available tags: $e');
    if (e is VisitorValidationException || e is VisitorAuthException || e is VisitorNetworkException) {
      rethrow;
    }
    throw VisitorValidationException('Failed to fetch available tags: ${e.toString()}');
  }
}

  

  /// Checks out a visitor
  Future<void> checkOutVisitor(Visitor visitor) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    if (token == null) {
      debugPrint('⚠️ Cannot check out visitor: No authentication token found');
      throw VisitorAuthException('No authentication token found');
    }

    if (visitor.id == null) {
      throw VisitorValidationException('Visitor ID is required for checkout');
    }

    _token = token;

    _isLoading = true;
    _safeNotifyListeners();
    try {
      final uri = Uri.parse(
        '${AppStrings.apiBaseUrl}/api/visitors/${visitor.id}/checkout',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final updatedVisitorData = jsonDecode(response.body);
        if (!updatedVisitorData['success']) {
          throw VisitorValidationException(updatedVisitorData['message']);
        }
        final updatedVisitor = Visitor.fromMap(
          updatedVisitorData['visitor'] ?? updatedVisitorData,
        );
        _visitors =
            _visitors
                .map((v) => v.id == visitor.id ? updatedVisitor : v)
                .toList();
        _checkedInCount--;
        _checkedOutCount++;
        await _saveCachedData();
      } else {
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        throw VisitorNetworkException(
          'Failed to check out visitor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking out visitor: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Updates a visitor's status
  Future<void> updateVisitorStatus(String visitorId, String status) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    if (token == null) {
      debugPrint(
        '⚠️ Cannot update visitor status: No authentication token found',
      );
      throw VisitorAuthException('No authentication token found');
    }

    if (!_validateInput(visitorId) || !_validateInput(status)) {
      throw VisitorValidationException('Visitor ID and status are required');
    }

    _token = token;

    _isLoading = true;
    _safeNotifyListeners();
    try {
      final uri = Uri.parse(
        '${AppStrings.apiBaseUrl}/api/visitors/$visitorId/status',
      );
      final response = await _retryApiCall(
        () => http.put(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'status': status}),
        ),
      );

      if (response.statusCode == 200) {
        final updatedVisitorData = jsonDecode(response.body);
        final updatedVisitor = Visitor.fromMap(
          updatedVisitorData['visitor'] ?? updatedVisitorData,
        );
        _visitors =
            _visitors
                .map((v) => v.id == visitorId ? updatedVisitor : v)
                .toList();
        await _saveCachedData();
      } else {
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token',
          );
        }
        throw VisitorNetworkException(
          'Failed to update visitor status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating visitor status: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Verifies identity using student ID, username, or staff number
  Future<Map<String, dynamic>> verifyIdentity({
    String? studentId,
    String? username,
    String? staffNo,
  }) async {
    if (_isDisposed) {
      return {'success': false, 'message': 'Provider disposed'};
    }

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot verify identity: Not authenticated');
      throw VisitorAuthException('Not authenticated');
    }

    _token = token;
    _gateId = gateId;

    final providedParams = [
      if (studentId != null) 'studentId',
      if (username != null) 'username',
      if (staffNo != null) 'staffNo',
    ];
    if (providedParams.length != 1) {
      throw VisitorValidationException('Exactly one identifier required');
    }

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final response = await _retryApiCall(
        () => http.post(
          Uri.parse('${AppStrings.apiBaseUrl}/api/verify'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            if (studentId != null) 'student_id': _sanitizeInput(studentId),
            if (username != null) 'username': _sanitizeInput(username),
            if (staffNo != null) 'staff_no': _sanitizeInput(staffNo),
            'gate_id': gateId,
          }),
        ),
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
          return {
            'success': false,
            'message': data['message'] ?? 'Verification failed',
          };
        }
      } else {
        _handleApiError(response, 'Failed to verify identity');
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException('Authentication failed');
        }
        throw VisitorNetworkException(
          'Failed to verify identity: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error verifying identity: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Saves cached data to SharedPreferences
  Future<void> _saveCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visitorsJson = jsonEncode(_visitors.map((v) => v.toMap()).toList());
      final destinationsJson = jsonEncode(_destinations);
      final tagsJson = jsonEncode(_visitorTags);
      final gatesJson = jsonEncode(_gates);
      final countsJson = jsonEncode({
        'checked_in_count': _checkedInCount,
        'checked_out_count': _checkedOutCount,
        'todays_total_count': _todaysTotalCount,
      });

      await prefs.setString('token', _token ?? '');
      await prefs.setString('gate_id', _gateId ?? '');
      await prefs.setString('device_gate', _deviceGate ?? '');
      await prefs.setString('userName', _userName ?? '');
      await prefs.setString('userEmail', _userEmail ?? '');
      await prefs.setString('userPhone', _userPhone ?? '');
      await prefs.setString('userRole', _userRole ?? '');
      await prefs.setString('userPosition', _userPosition ?? '');
      if (_userAvatarUrl != null) {
        await prefs.setString('userAvatarUrl', _userAvatarUrl!);
      } else {
        await prefs.remove('userAvatarUrl');
      }
      await prefs.setString('visitors', visitorsJson);
      await prefs.setString('destinations', destinationsJson);
      await prefs.setString('visitor_tags', tagsJson);
      await prefs.setString('gates', gatesJson);
      await prefs.setString('visit_counts', countsJson);
      debugPrint('✅ Saved cached data to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error saving cached data: $e');
      throw VisitorAuthException('Failed to save cached data: $e');
    }
  }

  /// Loads cached data from SharedPreferences
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = await _getTokenFromPreferences();
      _gateId =
          prefs.getString('gate_id')?.isNotEmpty == true
              ? prefs.getString('gate_id')
              : null;
      _deviceGate =
          prefs.getString('device_gate')?.isNotEmpty == true
              ? prefs.getString('device_gate')
              : null;
      _userName =
          prefs.getString('userName')?.isNotEmpty == true
              ? prefs.getString('userName')
              : null;
      _userEmail =
          prefs.getString('userEmail')?.isNotEmpty == true
              ? prefs.getString('userEmail')
              : null;
      _userPhone =
          prefs.getString('userPhone')?.isNotEmpty == true
              ? prefs.getString('userPhone')
              : null;
      _userRole =
          prefs.getString('userRole')?.isNotEmpty == true
              ? prefs.getString('userRole')
              : null;
      _userPosition =
          prefs.getString('userPosition')?.isNotEmpty == true
              ? prefs.getString('userPosition')
              : null;
      _userAvatarUrl = prefs.getString('userAvatarUrl');

      try {
        final cachedVisitors = prefs.getString('visitors');
        if (cachedVisitors != null && cachedVisitors.isNotEmpty) {
          _visitors =
              (jsonDecode(cachedVisitors) as List)
                  .map((v) => Visitor.fromMap(Map<String, dynamic>.from(v)))
                  .toList();
        } else {
          _visitors = [];
        }
      } catch (e) {
        debugPrint('❌ Error loading cached visitors: $e');
        _visitors = [];
      }

      try {
        final cachedDestinations = prefs.getString('destinations');
        if (cachedDestinations != null && cachedDestinations.isNotEmpty) {
          _destinations =
              (jsonDecode(cachedDestinations) as List)
                  .cast<Map<String, dynamic>>();
        } else {
          _destinations = [
            {'id': '1', 'name': 'Default Destination'},
          ];
        }
      } catch (e) {
        debugPrint('❌ Error loading cached destinations: $e');
        _destinations = [
          {'id': '1', 'name': 'Default Destination'},
        ];
      }

      try {
        final cachedTags = prefs.getString('visitor_tags');
        if (cachedTags != null && cachedTags.isNotEmpty) {
          _visitorTags =
              (jsonDecode(cachedTags) as List).cast<Map<String, dynamic>>();
        } else {
          _visitorTags = [];
        }
      } catch (e) {
        debugPrint('❌ Error loading cached visitor tags: $e');
        _visitorTags = [];
      }

      try {
        final cachedGates = prefs.getString('gates');
        if (cachedGates != null && cachedGates.isNotEmpty) {
          final decodedGates = jsonDecode(cachedGates) as List;
          _gates =
              decodedGates
                  .map(
                    (gate) => ({
                      'id': gate['id']?.toString() ?? '',
                      'name': gate['name']?.toString() ?? 'Unknown Gate',
                    }),
                  )
                  .toList();
          _gateMap = {for (var g in _gates) g['name']!: g['id']!};
        } else {
          _gates = [
            {'id': '1', 'name': 'Default Gate'},
          ];
          _gateMap = {'Default Gate': '1'};
        }
      } catch (e) {
        debugPrint('❌ Error loading cached gates: $e');
        _gates = [
          {'id': '1', 'name': 'Default Gate'},
        ];
        _gateMap = {'Default Gate': '1'};
      }

      try {
        final cachedCounts = prefs.getString('visit_counts');
        if (cachedCounts != null && cachedCounts.isNotEmpty) {
          final counts = jsonDecode(cachedCounts) as Map<String, dynamic>;
          _checkedInCount = counts['checked_in_count']?.toInt() ?? 0;
          _checkedOutCount = counts['checked_out_count']?.toInt() ?? 0;
          _todaysTotalCount = counts['todays_total_count']?.toInt() ?? 0;
        } else {
          _checkedInCount = 0;
          _checkedOutCount = 0;
          _todaysTotalCount = 0;
        }
      } catch (e) {
        debugPrint('❌ Error loading cached visit counts: $e');
        _checkedInCount = 0;
        _checkedOutCount = 0;
        _todaysTotalCount = 0;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
      throw VisitorAuthException('Failed to load cached data: $e');
    }
  }

  /// Retries API calls with exponential backoff
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
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else {
          error = VisitorNetworkException(
            'Request failed: Status ${response.statusCode}',
          );
          _handleApiError(response, 'API call failed');
          if (attempt == maxRetries || response.statusCode == 401) {
            return response;
          }
        }
      } catch (e) {
        error = e;
        if (attempt == maxRetries) throw error;
        await Future.delayed(Duration(milliseconds: 1000 * (1 << attempt)));
      }
    }
    throw error;
  }

  /// Validates input strings
  bool _validateInput(String? input) {
    return input != null && input.trim().isNotEmpty;
  }

  /// Sanitizes input strings
  String _sanitizeInput(String? input) {
    if (input == null) return '';
    return input.trim().replaceAll(RegExp(r'[<>]'), '');
  }

  /// Validates ID numbers based on type
  String? validateIdNumber(String idNumber, String? idType) {
    if (idNumber.isEmpty) return 'ID number is required';
    if (idType == 'national_id') {
      if (!RegExp(r'^\d+$').hasMatch(idNumber)) {
        return 'National ID should only contain digits';
      }
      if (idNumber.length < 6) {
        return 'National ID must be at least 6 digits';
      }
    }
    if (idType == 'driving_licence' &&
        !RegExp(r'^[A-Za-z0-9]{8,12}$').hasMatch(idNumber)) {
      return 'Driving licence must be 8-12 alphanumeric characters';
    }
    return null;
  }

  /// Parses error messages for user-friendly display
  String _parseErrorMessage(String error) {
    if (error.contains('Failed to connect') ||
        error.contains('SocketException')) {
      return 'Network error: Unable to connect to the server';
    } else if (error.contains('TimeoutException')) {
      return 'Request timed out. Please try again later';
    } else if (error.contains('Invalid response format')) {
      return 'Invalid response from server';
    } else if (error.contains('401')) {
      return 'Authentication failed. Please log in again';
    } else {
      return 'An unexpected error occurred: $error';
    }
  }

  /// Handles API errors
  void _handleApiError(http.Response response, String context) {
    debugPrint(
      '❌ API Error: $context - Status: ${response.statusCode}, Body: ${response.body}',
    );
  }

  /// Updates user profile information
  Future<void> updateUserProfile(Map<String, String> profileData) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    if (token == null) {
      debugPrint('⚠️ Cannot update profile: Not authenticated');
      throw VisitorAuthException('Not authenticated');
    }

    _token = token;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final payload = {
        'name': _sanitizeInput(profileData['name']),
        'email': _sanitizeInput(profileData['email']),
        'position': _sanitizeInput(profileData['position']),
        'role': _sanitizeInput(profileData['role']),
      }..removeWhere((key, value) => value == null || value.isEmpty);

      final response = await _retryApiCall(
        () => http.put(
          Uri.parse('${AppStrings.apiBaseUrl}/api/user/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(payload),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userName = data['name']?.toString() ?? _userName;
        _userRole = data['role']?.toString() ?? _userRole;
        _userPosition = data['position']?.toString() ?? _userPosition;
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to update profile');
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException('Authentication failed');
        }
        throw VisitorNetworkException(
          'Failed to update profile: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      throw VisitorNetworkException(_parseErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Sets authentication data
  void setAuthData(String token, String gateId, String deviceGate) {
    if (_isDisposed) return;

    _token = token.isNotEmpty ? token : null;
    _gateId = gateId.isNotEmpty ? gateId : null;
    _deviceGate = deviceGate.isNotEmpty ? deviceGate : null;
    _safeNotifyListeners();
  }

  /// Refreshes all data
  Future<void> refreshData() async {
    if (_isRefreshing || _isDisposed) {
      debugPrint('⚠️ Refresh skipped: Already refreshing or disposed');
      return;
    }

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot refresh data: Not authenticated');
      throw VisitorAuthException('Not authenticated');
    }

    _token = token;
    _gateId = gateId;

    _isRefreshing = true;
    _isLoading = true;
    _safeNotifyListeners();

    try {
      debugPrint('🔄 Refreshing provider data...');
      final results = await Future.wait([
        loadCheckedInVisitors().then((_) => true).catchError((e) {
          debugPrint('❌ Error in loadCheckedInVisitors: $e');
          return false;
        }),
        loadDestinations().then((_) => true).catchError((e) {
          debugPrint('❌ Error loading destinations: $e');
          return false;
        }),
        loadGates().then((_) => true).catchError((e) {
          debugPrint('❌ Error loading gates: $e');
          return false;
        }),
        logVisitCount().then((_) => true).catchError((e) {
          debugPrint('❌ Error loading visit count: $e');
          return false;
        }),
      ], eagerError: false);

      debugPrint('✅ Data refresh completed: $results');
      await _saveCachedData();
    } catch (e) {
      debugPrint('❌ Error refreshing data: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Loads visitors from cache (not used in current implementation)
  Future<void> loadVisitors() async {
    try {
      _isLoading = true;
      _safeNotifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final visitorsJson = prefs.getString('visitors');
      if (visitorsJson != null && visitorsJson.isNotEmpty) {
        final List<dynamic> visitorMaps = jsonDecode(visitorsJson);
        debugPrint('📝 Loading cached visitors: ${visitorMaps.length}');
        _visitors.clear();
        for (var map in visitorMaps) {
          try {
            final visitorMap = Map<String, dynamic>.from(map);
            visitorMap['id'] = int.parse(visitorMap['id'].toString());
            if (visitorMap['visitor_tag_id'] != null) {
              visitorMap['visitor_tag_id'] = int.parse(
                visitorMap['visitor_tag_id'].toString(),
              );
            }
            if (visitorMap['destination_id'] != null) {
              visitorMap['destination_id'] = int.parse(
                visitorMap['destination_id'].toString(),
              );
            }
            if (visitorMap['gate_id'] != null) {
              visitorMap['gate_id'] = int.parse(
                visitorMap['gate_id'].toString(),
              );
            }
            if (visitorMap['floor_id'] != null) {
              visitorMap['floor_id'] = int.parse(
                visitorMap['floor_id'].toString(),
              );
            }
            debugPrint(
              '📝 Processing cached visitor map: ${jsonEncode(visitorMap)}',
            );
            final visitor = Visitor.fromMap(visitorMap);
            _visitors.add(visitor);
          } catch (e) {
            debugPrint('❌ Error parsing cached visitor: $e');
            continue;
          }
        }
        debugPrint('✅ Loaded ${_visitors.length} cached visitors');
      } else {
        debugPrint('⚠️ No cached visitors found');
      }
    } catch (e) {
      debugPrint('❌ Error loading cached visitors: $e');
      throw VisitorNetworkException('Failed to load cached visitors: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
}
