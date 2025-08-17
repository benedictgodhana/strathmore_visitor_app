import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

class VisitorAuthException implements Exception {
  final String message;
  VisitorAuthException(this.message);
  @override
  String toString() => message;
}

class VisitorValidationException implements Exception {
  final String message;
  VisitorValidationException(this.message);
  @override
  String toString() => message;
}

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
  String? _userEmail;
  String? _userPhone;
  String? _userAvatarUrl;
  bool _isActive = true;
  bool _isDisposed = false;
  bool _isRefreshing = false;

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
  String? get userEmail => _userEmail;
  String? get userPhone => _userPhone;
  String? get userAvatarUrl => _userAvatarUrl;

  get user => {
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

  Future<String?> _getTokenFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        debugPrint(
          '✅ Retrieved auth token from SharedPreferences: ${token.substring(0, 10)}...',
        );
        return token;
      } else {
        debugPrint('⚠️ No valid auth token found in SharedPreferences');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error retrieving token from SharedPreferences: $e');
      return null;
    }
  }

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
      throw Exception('Failed to load authentication data');
    }
  }

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
      return false;
    }
  }
Future<Map<String, dynamic>?> checkExistingVisitor(String idNumber, String idType) async {
    try {
      final token = await _getTokenFromPreferences();
      final prefs = await SharedPreferences.getInstance();
      final gateId = prefs.getString('gate_id');
      if (token == null || gateId == null) {
        debugPrint('⚠️ No authentication token or gate ID found for checking visitor');
        throw Exception('No authentication token or gate ID found');
      }

      // Validate gateId format
      if (!RegExp(r'^\d+$').hasMatch(gateId)) {
        debugPrint('⚠️ Invalid gate ID format: $gateId');
        throw Exception('Invalid gate ID format');
      }

      // Validate idNumber and idType
      final validationError = validateIdNumber(idNumber, idType);
      if (validationError != null) {
        debugPrint('⚠️ Validation error for ID $idNumber ($idType): $validationError');
        throw Exception(validationError);
      }

      debugPrint('📤 Sending check visitor request with token: ${token.substring(0, 10)}..., gate_id: $gateId, idNumber: $idNumber, idType: $idType');

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

      debugPrint('📥 Check visitor response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['visitor'] != null) {
          final visitor = data['visitor'] as Map<String, dynamic>;
          // Determine status: 'active' if checked in, 'completed' if checked out
          final isCheckedIn = data['alreadyCheckedIn'] == true ||
              (visitor['status'] != null && visitor['status'] == 'checked_in');
          final isCheckedOut = visitor['status'] == 'checked_out' || visitor['check_out_time'] != null;
          final visitorStatus = isCheckedIn ? 'active' : (isCheckedOut ? 'completed' : 'unknown');
          
          // Update response data with computed status
          data['alreadyCheckedIn'] = isCheckedIn;
          data['visitorStatus'] = visitorStatus;

          debugPrint('Visitor status: ID=$idNumber, exists=${data['exists']}, alreadyCheckedIn=$isCheckedIn, status=${visitor['status']}, check_out_time=${visitor['check_out_time']}, computedStatus=$visitorStatus');

          // Check for empty tag_number in visitor data
          if (visitor['tag'] != null) {
            final tag = visitor['tag'] as Map<String, dynamic>;
            final tagNumber = tag['tag_number']?.toString();
            if (tagNumber == null || tagNumber.isEmpty) {
              debugPrint('⚠️ Visitor tag has empty tag_number: $tag, using fallback Tag ${tag['id']}');
              tag['tag_number'] = 'Tag ${tag['id'] ?? 'Unknown'}';
            } else {
              debugPrint('ℹ️ Visitor tag: $tagNumber');
            }
          } else {
            debugPrint('⚠️ No tag associated with visitor: $visitor');
          }
        } else {
          debugPrint('ℹ️ No visitor data returned for ID $idNumber');
        }
        return data;
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No visitor found for ID $idNumber');
        return {'exists': false, 'visitor': null, 'message': 'No visitor found', 'visitorStatus': 'none'};
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed: Invalid or expired token');
        await _clearAuthenticationState();
        throw Exception('Authentication failed: Invalid or expired token.');
      } else if (response.statusCode == 419) {
        debugPrint('❌ CSRF token mismatch');
        throw Exception('CSRF token mismatch. Please contact the administrator.');
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Validation failed';
        final details = errorData['details']?.toString() ?? 'No details provided';
        debugPrint('❌ Validation error: $errorMessage, Details: $details');
        throw Exception('$errorMessage: $details');
      }
      throw Exception('Failed to check visitor: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('❌ Error checking existing visitor: $e');
      rethrow;
    }
  }



  Future<void> createVisitForExistingVisitor(Map<String, dynamic> visit) async {
    if (_token == null || _gateId == null) {
      debugPrint('⚠️ Cannot create visit: No token or gate ID');
      throw Exception('Authentication token or gate ID missing');
    }
    try {
      final response = await http.post(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visits'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(visit),
      );
      debugPrint('📤 Create visit response: ${response.statusCode}, ${response.body}');
      if (response.statusCode == 201) {
        await loadVisitorTags();
        await loadCheckedInVisitors();
        notifyListeners();
      } else {
        throw Exception('Failed to create visit: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error creating visit for existing visitor: $e');
      throw e;
    }
  }
  Future<void> init(String token, String gateId, String deviceGate) async {
    if (_isDisposed) return;

    _token = token.isNotEmpty ? token : null;
    _gateId = gateId.isNotEmpty ? gateId : null;
    _deviceGate = deviceGate.isNotEmpty ? deviceGate : null;

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
        if (e.toString().contains(
              'Authentication token is missing or invalid',
            ) ||
            e.toString().contains('401')) {
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

  Future<void> login(
    String username,
    String password,
    String gateId,
    String deviceGate,
  ) async {
    if (_isDisposed) return;

    if (!_validateInput(username) || !_validateInput(password)) {
      throw Exception('Invalid username or password');
    }

    _isLoading = true;
    _safeNotifyListeners();

    try {
      int parsedGateId;
      try {
        parsedGateId = int.parse(gateId);
      } catch (e) {
        throw Exception('Invalid gate ID format');
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
          throw Exception(
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
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw Exception(_parseErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

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

  Future<void> loadDestinations() async {
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
      debugPrint('⚠️ Cannot load destinations: Not authenticated or disposed');
      return;
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
          throw Exception('Invalid destinations data format');
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

  Future<void> loadVisitorTags() async {
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
      debugPrint('⚠️ Cannot load visitor tags: Not authenticated or disposed');
      return;
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
          throw Exception('Invalid visitor tags data format');
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

  Future<Map<String, dynamic>?> checkVisitor(
    String idType,
    String idNumber,
  ) async {
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
      debugPrint('⚠️ Cannot check visitor: Not authenticated or disposed');
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
        return null; // No visitor found
      } else if (response.statusCode == 401) {
        throw VisitorAuthException(
          'Authentication failed: Invalid or expired token.',
        );
      }
      throw VisitorValidationException(
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
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
      debugPrint(
        '⚠️ Cannot register visitor: No authentication token or gate ID found',
      );
      throw VisitorAuthException('No authentication token or gate ID found');
    }

    _token = token;
    _gateId = gateId;

    // Validate token
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

    // Check for existing visitor
    try {
      final existingVisitor = await checkExistingVisitor(
        visitor.identificationNumber ?? '',
        visitor.identificationType ?? '',
      );
      if (existingVisitor != null) {
        debugPrint(
          '⚠️ Visitor with ID ${visitor.identificationNumber} already exists: $existingVisitor',
        );
        throw VisitorValidationException(
          'Visitor with ID ${visitor.identificationNumber} already exists',
        );
      }
    } catch (e) {
      if (e is! VisitorAuthException) {
        // Rethrow non-auth exceptions to handle in UI
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
      throw Exception('Unable to register visitor: No available tags: $e');
    }

    try {
      final payload = {
        'name': _sanitizeInput(visitor.name),
        'phone_number':
            visitor.phoneNumber?.trim().replaceFirst(RegExp(r'^\+254'), '') ??
            '',
        'phone_country_code': '+254',
        'is_minor': visitor.isMinor ?? false,
        'guardian_phone':
            visitor.isMinor == true && visitor.guardianPhone != null
                ? visitor.guardianPhone!.trim().replaceFirst(
                  RegExp(r'^\+254'),
                  '',
                )
                : null,
        'visitor_tag_id': visitorTagId,
        'destination_id': (visitor.destinationId ?? '').toString(),
        'identification_type': visitor.identificationType ?? '',
        'identification_number': _sanitizeInput(visitor.identificationNumber),
        'visitor_gate_id': visitor.gateId ?? gateId,
        'had_appointment': visitor.hadAppointment ?? false,
        'vehicle_type': visitor.vehicleType,
        'vehicle_registration': visitor.vehicleRegistration,
        'visit_type': visitor.visitType ?? '',
        'host_type': visitor.visitType ?? '',
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
                  ? visitor.host!['email']
                  : null,
          'host_department':
              visitor.host!['department']?.isNotEmpty == true
                  ? visitor.host!['department']
                  : null,
          'host_position':
              visitor.host!['position']?.isNotEmpty == true
                  ? visitor.host!['position']
                  : null,
        },
        if (visitor.visitType == 'office') ...{
          'office_name': _sanitizeInput(visitor.officeName),
          'office_phone':
              visitor.officePhone?.trim().replaceFirst(RegExp(r'^\+254'), '') ??
              '',
          'office_email':
              visitor.officeEmail?.isNotEmpty == true
                  ? visitor.officeEmail
                  : null,
          'office_department':
              visitor.officeDepartment?.isNotEmpty == true
                  ? visitor.officeDepartment
                  : null,
          'office_contact_person': _sanitizeInput(visitor.officeContactPerson),
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

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['visitor'] == null) {
          debugPrint('❌ Invalid response: Missing visitor data');
          throw Exception('Invalid response: Missing visitor data');
        }
        final newVisitor = Visitor.fromMap(data['visitor']);
        _visitors.add(newVisitor);
        await _saveCachedData();
        debugPrint('✅ Visitor registered successfully: ${newVisitor.name}');
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
            'Authentication failed: Invalid or expired token.',
          );
        }
        debugPrint('❌ API error: ${response.statusCode} - ${response.body}');
        throw Exception(
          'Failed to register visitor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      throw e; // Preserve original exception type
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

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
    _totalVisitCount = 0;
    _todaysVisitCount = 0;
    _checkedInCount = 0;
    _checkedOutCount = 0;
    await _saveCachedData();
    debugPrint('✅ Cleared authentication state');
  }

  Future<void> _clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ Cleared SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error clearing stored data: $e');
    }
  }

  Future<void> loadVisitors({int page = 1, int limit = 50}) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot load visitors: Not authenticated');
      return;
    }

    _token = token;
    _gateId = gateId;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      final response = await _retryApiCall(
        () => http.get(
          Uri.parse(
            '${AppStrings.apiBaseUrl}/api/visitors?gate_id=$gateId&page=$page&limit=$limit',
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
                      'gate_id': gateId,
                      'visitor_tag_id': v['visitor_tag']?['id']?.toString(),
                      'tag_number': v['visitor_tag']?['tag_number']?.toString(),
                      'destination_id':
                          v['visitor_destination']?['id']?.toString(),
                      'check_in_time':
                          v['check_in_time'] != null &&
                                  v['check_in_time'].isNotEmpty
                              ? DateTime.tryParse(
                                    v['check_in_time'],
                                  )?.toIso8601String() ??
                                  ''
                              : '',
                      'check_out_time':
                          v['check_out_time'] != null &&
                                  v['check_out_time'].isNotEmpty
                              ? DateTime.tryParse(
                                    v['check_out_time'],
                                  )?.toIso8601String() ??
                                  ''
                              : '',
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
          await _saveCachedData();
        } else {
          throw Exception('Invalid visitors data format');
        }
      } else {
        _handleApiError(response, 'Failed to load visitors');
        if (response.statusCode == 401) {
          await _clearAuthenticationState();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading visitors: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
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
                  'had_appointment': v['had_appointment']?.toString(),
                  'vehicle_type': v['vehicle_type']?.toString(),
                  'vehicle_registration': v['vehicle_registration']?.toString(),
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
            'Authentication failed: Invalid or expired token.',
          );
        }
        throw Exception(
          'Failed to load checked-in visitors: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading checked-in visitors: $e');
      throw e;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> logVisitCount() async {
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
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
        '${AppStrings.apiBaseUrl}/api/visitors/visit-count',
      ).replace(queryParameters: {'gate_id': gateId});
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _todaysVisitCount = data['todays_count']?.toInt() ?? 0;
        _totalVisitCount = data['total_count']?.toInt() ?? 0;
        _checkedOutCount = data['checked_out_count']?.toInt() ?? 0;
        await _saveCachedData();
      } else {
        _handleApiError(response, 'Failed to load visit count');
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token.',
          );
        }
        throw Exception(
          'Failed to load visit count: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading visit count: $e');
      throw e;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<int?> getAvailableVisitorTagId({String? gateId}) async {
    try {
      final uri = Uri.parse(
        '${AppStrings.apiBaseUrl}/api/visitor-tags',
      ).replace(
        queryParameters: {
          'unassigned': 'true',
          if (gateId != null) 'gate_id': gateId,
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );
      debugPrint(
        '📥 Available tags response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['tags']?.isNotEmpty == true) {
          return data['tags'][0]['id'];
        }
        throw Exception('No unassigned visitor tags available.');
      }
      throw Exception('Failed to fetch available tags: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Error fetching available tags: $e');
      throw Exception('Failed to fetch available tags: $e');
    }
  }

  Future<void> checkOutVisitor(Visitor visitor) async {
    if (_isDisposed) return;

    final token = await _getTokenFromPreferences();
    if (token == null) {
      debugPrint('⚠️ Cannot check out visitor: No authentication token found');
      throw VisitorAuthException('No authentication token found');
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
          throw Exception(updatedVisitorData['message']);
        }
        final updatedVisitor = Visitor.fromMap(
          updatedVisitorData['visitor'] ?? updatedVisitorData,
        );
        _visitors =
            _visitors
                .map((v) => v.id == visitor.id ? updatedVisitor : v)
                .toList();
      } else {
        if (response.statusCode == 401) {
          debugPrint('⚠️ 401 Unauthorized: Token may be invalid or expired');
          throw VisitorAuthException(
            'Authentication failed: Invalid or expired token.',
          );
        }
        throw Exception(
          'Failed to check out visitor: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking out visitor: $e');
      throw e;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyIdentity({
    String? studentId,
    String? username,
    String? staffNo,
  }) async {
    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null || _isDisposed) {
      debugPrint('⚠️ Cannot verify identity: Not authenticated or disposed');
      return {'success': false, 'message': 'Not authenticated'};
    }

    _token = token;
    _gateId = gateId;

    final providedParams = [
      if (studentId != null) 'studentId',
      if (username != null) 'username',
      if (staffNo != null) 'staffNo',
    ];
    if (providedParams.length != 1) {
      return {'success': false, 'message': 'Exactly one identifier required'};
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
          return {'success': false, 'message': 'Authentication failed'};
        }
        return {'success': false, 'message': 'Failed to verify identity'};
      }
    } catch (e) {
      debugPrint('❌ Error verifying identity: $e');
      return {'success': false, 'message': _parseErrorMessage(e.toString())};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _saveCachedData() async {
    try {
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
      await debugSharedPreferences();
    } catch (e) {
      debugPrint('❌ Error saving cached data: $e');
    }
  }

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
          _totalVisitCount = counts['total_visit_count']?.toInt() ?? 0;
          _todaysVisitCount = counts['todays_visit_count']?.toInt() ?? 0;
          _checkedInCount = counts['checked_in_count']?.toInt() ?? 0;
          _checkedOutCount = counts['checked_out_count']?.toInt() ?? 0;
        } else {
          _totalVisitCount = 0;
          _todaysVisitCount = 0;
          _checkedInCount = 0;
          _checkedOutCount = 0;
        }
      } catch (e) {
        debugPrint('❌ Error loading cached visit counts: $e');
        _totalVisitCount = 0;
        _todaysVisitCount = 0;
        _checkedInCount = 0;
        _checkedOutCount = 0;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached data: $e');
    }
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
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else {
          error = Exception('Request failed: Status ${response.statusCode}');
          _handleApiError(response, 'API call failed');
          if (attempt == maxRetries || response.statusCode == 401) {
            return response;
          }
        }
      } catch (e) {
        error = e;
        if (attempt == maxRetries) throw error;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
    throw error;
  }

  bool _validateInput(String? input) {
    return input != null && input.trim().isNotEmpty;
  }

  String _sanitizeInput(String? input) {
    if (input == null) return '';
    return input.trim();
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
    } else if (error.contains('401')) {
      return 'Authentication failed. Please log in again.';
    } else {
      return 'An unexpected error occurred: $error';
    }
  }

  void _handleApiError(http.Response response, String context) {
    debugPrint(
      '❌ API Error: $context - Status: ${response.statusCode}, Body: ${response.body}',
    );
  }

  Future<void> updateUserProfile(Map<String, String> profileData) async {
    final token = await _getTokenFromPreferences();
    if (token == null || _isDisposed) {
      debugPrint('⚠️ Cannot update profile: Not authenticated or disposed');
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
          throw VisitorAuthException('Authentication failed.');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      throw Exception(_parseErrorMessage(e.toString()));
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  void setAuthData(String token, String gateId, String deviceGate) {
    if (_isDisposed) return;

    _token = token.isNotEmpty ? token : null;
    _gateId = gateId.isNotEmpty ? gateId : null;
    _deviceGate = deviceGate.isNotEmpty ? deviceGate : null;
    _safeNotifyListeners();
  }

  Future<void> refreshData() async {
    if (_isRefreshing || _isDisposed) {
      debugPrint('⚠️ Refresh skipped: Already refreshing or disposed');
      return;
    }

    final token = await _getTokenFromPreferences();
    final gateId = (await SharedPreferences.getInstance()).getString('gate_id');
    if (token == null || gateId == null) {
      debugPrint('⚠️ Cannot refresh data: Not authenticated');
      return;
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
        loadVisitors().then((_) => true).catchError((e) {
          debugPrint('❌ Error loading visitors: $e');
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
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
}
