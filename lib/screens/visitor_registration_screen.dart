import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:im_stepper/stepper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import '../components/custom_app_bar.dart';
import '../models/visitor.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'package:flutter/scheduler.dart';

class VisitorRegistrationScreen extends StatefulWidget {
  const VisitorRegistrationScreen({super.key});

  @override
  _VisitorRegistrationScreenState createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState
    extends State<VisitorRegistrationScreen> {
  // ─── Form keys ────────────────────────────────────────────────────────────
  final _idFormKey = GlobalKey<FormState>();
  final _personalFormKey = GlobalKey<FormState>();
  final _entryFormKey = GlobalKey<FormState>();

  // ─── Controllers ──────────────────────────────────────────────────────────
  final _idNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _countryController = TextEditingController(text: 'Kenya');
  final _hostNameController = TextEditingController();
  final _hostPhoneController = TextEditingController();
  final _hostEmailController = TextEditingController();
  final _hostDepartmentController = TextEditingController();
  final _hostPositionController = TextEditingController();
  final _officeNameController = TextEditingController();
  final _officePhoneController = TextEditingController();
  final _officeEmailController = TextEditingController();
  final _officeDepartmentController = TextEditingController();
  final _officeContactPersonController = TextEditingController();
  final _appointmentDetailsController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleRegController = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _availableTags = [];
  String? _authToken;
  String? gateId;
  String? deviceGate;
  String? _token;
  String _selectedIdType = 'national_id';
  String _visitType = 'staff';
  String _phoneCountryCode = '+254';
  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isBackgroundChecking = false;
  bool _isBackgroundFetching = false;
  bool _isMinor = false;
  bool _isScanning = false;
  String? _selectedDestinationId;
  String? _selectedVisitorTagId;
  String? _selectedGate;
  String? _idValidationError;
  String? _selectedGender;
  bool? _hadAppointment;
  Timer? _debounceTimer;
  double _formProgress = 0.0;
  bool _showVisitDetails = false;

  // Helper to get the current ID field label
  String get _idFieldLabel {
    switch (_selectedIdType) {
      case 'national_id':
        return 'National ID Number';
      case 'passport_number':
        return 'Passport Number';
      case 'driving_licence':
        return 'Driving Licence Number';
      case 'birth_certificate_number':
        return 'Birth Certificate Number';
      default:
        return 'ID Number';
    }
  }

  // Helper to get the current ID field icon
  IconData get _idFieldIcon {
    switch (_selectedIdType) {
      case 'national_id':
        return Icons.numbers;
      case 'passport_number':
        return Icons.credit_card;
      case 'driving_licence':
        return Icons.drive_eta;
      case 'birth_certificate_number':
        return Icons.description;
      default:
        return Icons.credit_card;
    }
  }

  // Helper to get keyboard type based on ID type
  TextInputType get _idKeyboardType {
    switch (_selectedIdType) {
      case 'national_id':
        return TextInputType.number;
      case 'passport_number':
        return TextInputType.text;
      case 'driving_licence':
        return TextInputType.text;
      case 'birth_certificate_number':
        return TextInputType.text;
      default:
        return TextInputType.text;
    }
  }

  // Helper to get input formatters based on ID type
  List<TextInputFormatter>? get _idInputFormatters {
    switch (_selectedIdType) {
      case 'national_id':
        return [FilteringTextInputFormatter.digitsOnly];
      case 'passport_number':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(20),
        ];
      case 'driving_licence':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(15),
        ];
      case 'birth_certificate_number':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          LengthLimitingTextInputFormatter(20),
        ];
      default:
        return null;
    }
  }

  // ─── Drop-down options ────────────────────────────────────────────────────
  final List<Map<String, String>> _idTypeOptions = [
    {'value': 'national_id', 'label': 'National ID'},
    {'value': 'passport_number', 'label': 'Passport Number'},
    {'value': 'birth_certificate_number', 'label': 'Birth Certificate'},
    {'value': 'driving_licence', 'label': 'Driving Licence'},
  ];
  final List<Map<String, String>> _visitTypeOptions = [
    {'value': 'staff', 'label': 'Visiting Staff Member'},
    {'value': 'office', 'label': 'Visiting Office'},
  ];
  final List<Map<String, String>> _vehicleTypeOptions = [
    {'value': 'Car', 'label': 'Car'},
    {'value': 'Motorcycle', 'label': 'Motorcycle'},
    {'value': 'Truck', 'label': 'Truck'},
    {'value': 'Bus', 'label': 'Bus'},
    {'value': 'Bicycle', 'label': 'Bicycle'},
    {'value': 'Other', 'label': 'Other'},
  ];
  final List<Map<String, String>> _genderOptions = [
    {'value': 'Male', 'label': 'Male'},
    {'value': 'Female', 'label': 'Female'},
    {'value': 'Other', 'label': 'Other'},
  ];

  // ─── Step meta ────────────────────────────────────────────────────────────
  static const _stepTitles = ['Identification', 'Personal Details', 'Entry Details'];
  static const _stepIcons = [Icons.credit_card_rounded, Icons.person_rounded, Icons.login_rounded];

  // =========================================================================
  // Life-cycle
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _idNumberController.addListener(_debouncedCheckExistingVisitor);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadInitialDataInBackground();
    });
    _updateFormProgress();
  }

  @override
  void dispose() {
    _idNumberController.removeListener(_debouncedCheckExistingVisitor);
    for (final c in [
      _idNumberController, _nameController, _phoneController,
      _guardianPhoneController, _countryController, _hostNameController,
      _hostPhoneController, _hostEmailController, _hostDepartmentController,
      _hostPositionController, _officeNameController, _officePhoneController,
      _officeEmailController, _officeDepartmentController,
      _officeContactPersonController, _appointmentDetailsController,
      _vehicleTypeController, _vehicleRegController,
    ]) {
      c.dispose();
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // Progress
  // =========================================================================

  void _updateFormProgress() {
    const total = 11;
    int filled = 0;
    if (_idNumberController.text.isNotEmpty) filled++;
    if (_nameController.text.isNotEmpty) filled++;
    if (_phoneController.text.isNotEmpty) filled++;
    if (_selectedGender != null) filled++;
    if (_countryController.text.isNotEmpty) filled++;
    if (_selectedDestinationId != null) filled++;
    if (_selectedVisitorTagId != null) filled++;
    if (_selectedGate != null) filled++;
    if (_showVisitDetails && _hadAppointment != null) filled++;
    if (_showVisitDetails && _visitType == 'staff' && _hostNameController.text.isNotEmpty) filled++;
    else if (_showVisitDetails && _visitType == 'office' && _officeNameController.text.isNotEmpty) filled++;
    if (mounted) setState(() => _formProgress = filled / total);
  }

  // =========================================================================
  // Data loading
  // =========================================================================

  Future<void> _loadInitialDataInBackground() async {
    if (!mounted) return;
    debugPrint('🔄 _loadInitialDataInBackground STARTED');
    
    try {
      final vp = Provider.of<VisitorProvider>(context, listen: false);

      await _loadTokenFromPreferences();
      debugPrint('✅ Token loaded, gateId: $gateId');

      await Future.wait([
        vp.loadDestinations(),
        vp.loadVisitorTags(),
        vp.loadCheckedInVisitors(),
      ]);

      await _fetchAvailableTagsInBackground();

      // Set default entry gate if not already set
      if (_selectedGate == null) {
        final defaultGate = gateId ?? vp.gateId?.toString();
        if (defaultGate != null) {
          setState(() => _selectedGate = defaultGate);
        }
      }

      debugPrint('✅ All background data loaded, tags count: ${_availableTags.length}');
    } catch (e) {
      debugPrint('⚠️ Background load failed: $e');
    }
  }

  Future<void> _loadTokenFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _token = prefs.getString('token');
        gateId = prefs.getString('gate_id');
        deviceGate = prefs.getString('device_gate') ?? 'Gate A';
        _authToken = _token;
      });
      debugPrint('📱 Token loaded: ${_token != null ? "Yes (${_token!.substring(0, 20)}...)" : "No"}');
      debugPrint('📱 Gate ID: $gateId');
      
      if (_token == null || gateId == null) {
        await _clearPreferences();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        return;
      }
      if (_token != null && gateId != null && deviceGate != null && mounted) {
        Provider.of<VisitorProvider>(context, listen: false)
            .setAuthData(_token!, gateId!, deviceGate!);
      }
    } catch (e) {
      debugPrint('❌ Error loading token: $e');
      await _clearPreferences();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) setState(() {
      _token = null;
      _authToken = null;
      gateId = null;
      deviceGate = null;
    });
  }

  // =========================================================================
  // Visitor lookup
  // =========================================================================

  void _debouncedCheckExistingVisitor() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_idNumberController.text.trim().isNotEmpty && mounted) {
        _checkExistingVisitorInBackground();
      }
    });
  }

  Future<void> _checkExistingVisitorInBackground() async {
    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty) return;
    final vp = Provider.of<VisitorProvider>(context, listen: false);
    final error = vp.validateIdNumber(idNumber, _selectedIdType);
    if (error != null) {
      if (mounted) setState(() => _idValidationError = error);
      return;
    }
    if (mounted) setState(() => _isBackgroundChecking = true);
    try {
      final response = await vp.checkExistingVisitor(idNumber, _selectedIdType);
      if (!mounted) return;
      setState(() => _isBackgroundChecking = false);
      if (response != null &&
          (response['exists'] == true || response['exists'] == 'true') &&
          response['visitor'] != null) {
        _autoFillVisitorData(response['visitor']);
        _showSubtleNotification('Returning Visitor', 'Information auto-filled');
      } else {
        setState(() => _idValidationError = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackgroundChecking = false);
        if (!e.toString().contains('404')) {
          _showSubtleNotification('Check Failed', 'Will retry automatically', isError: true);
        } else {
          setState(() => _idValidationError = null);
        }
      }
    }
  }

  void _autoFillVisitorData(Map<String, dynamic> d) {
    if (!mounted) return;
    setState(() {
      if (d['name'] != null && _nameController.text.isEmpty) _nameController.text = d['name'].toString();
      if (d['phone_number'] != null && _phoneController.text.isEmpty) _phoneController.text = d['phone_number'].toString().replaceFirst('+254', '');
      if (d['gender'] != null && _selectedGender == null) _selectedGender = d['gender'].toString();
      if (d['country'] != null && _countryController.text == 'Kenya') _countryController.text = d['country'].toString();
      if (d['is_minor'] != null) _isMinor = d['is_minor'] == true;
      if (d['guardian_phone'] != null && _isMinor) _guardianPhoneController.text = d['guardian_phone'].toString().replaceFirst('+254', '');
    });
    _updateFormProgress();
  }

  // =========================================================================
  // Tags
  // =========================================================================

  Future<void> _fetchAvailableTagsInBackground() async {
    debugPrint('🔍 ===== FETCHING AVAILABLE TAGS =====');
    
    final vp = Provider.of<VisitorProvider>(context, listen: false);
    
    try {
      final token = _authToken ?? vp.token;
      final currentGateId = gateId ?? vp.gateId;
      
      debugPrint('🔍 Token: ${token != null ? "Present (${token.substring(0, 20)}...)" : "NULL"}');
      debugPrint('🔍 Current GateId: $currentGateId');
      
      if (token == null || currentGateId == null) {
        debugPrint('⚠️ Cannot fetch tags - missing token or gateId');
        if (mounted) {
          _showSubtleNotification('Error', 'Missing authentication', isError: true);
        }
        return;
      }
      
      final url = '${AppStrings.apiBaseUrl}/api/visitor-tags?unassigned=true&gate_id=$currentGateId';
      debugPrint('📡 Making API call to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        
        List<dynamic> tagsList = [];
        if (data['tags'] != null && data['tags'] is List) {
          tagsList = data['tags'];
          debugPrint('✅ Found tags in "tags" field: ${tagsList.length}');
        } else if (data['data'] != null && data['data'] is List) {
          tagsList = data['data'];
          debugPrint('✅ Found tags in "data" field: ${tagsList.length}');
        } else if (data is List) {
          tagsList = data;
          debugPrint('✅ Response is a list: ${tagsList.length}');
        }
        
        final unassignedTags = tagsList
            .where((t) => t['is_assigned'] == false || t['is_assigned'] == 'false')
            .map((t) {
              if (t['tag_number'] == null || t['tag_number'].toString().isEmpty) {
                t['tag_number'] = 'Tag ${t['id'] ?? 'Unknown'}';
              }
              return Map<String, dynamic>.from(t);
            }).toList();
        
        debugPrint('🎫 Found ${unassignedTags.length} unassigned tags');
        
        setState(() {
          _availableTags = unassignedTags;
          if (_availableTags.isNotEmpty && _selectedVisitorTagId == null) {
            _selectedVisitorTagId = _availableTags.first['id']?.toString();
            debugPrint('🎫 Auto-selected tag ID: $_selectedVisitorTagId');
          }
        });
        
        if (unassignedTags.isEmpty && mounted) {
          _showSubtleNotification('No Tags', 'No unassigned tags available', isError: true);
        } else if (unassignedTags.isNotEmpty && mounted) {
          _showSubtleNotification('Tags Loaded', 'Found ${unassignedTags.length} tags');
        }
      } else if (response.statusCode == 401 && mounted) {
        debugPrint('🔐 Authentication failed');
        _showSubtleNotification('Session Expired', 'Please login again', isError: true);
      } else if (mounted) {
        debugPrint('❌ Failed to fetch tags: ${response.statusCode}');
        _showSubtleNotification('Error', 'Failed to load tags', isError: true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching tags: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        _showSubtleNotification('Error', 'Failed to load tags: $e', isError: true);
      }
    }
    
    debugPrint('🔍 ===== TAG FETCH COMPLETED =====');
  }

  Future<void> _silentRefresh() async {
    if (_token == null || gateId == null || !mounted) return;
    setState(() => _isBackgroundFetching = true);
    final vp = Provider.of<VisitorProvider>(context, listen: false);
    try {
      await Future.wait([
        _fetchAvailableTagsInBackground(),
        vp.loadDestinations(),
        vp.loadVisitorTags(),
        vp.loadCheckedInVisitors(),
      ]);
      if (mounted) {
        setState(() => _isBackgroundFetching = false);
        _showSubtleNotification('Refreshed', 'Latest data loaded');
      }
    } catch (e) {
      if (mounted) setState(() => _isBackgroundFetching = false);
    }
  }

  // =========================================================================
  // ID scanning
  // =========================================================================

  Future<void> _scanID() async {
    try {
      setState(() => _isScanning = true);
      final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) {
        if (mounted) {
          setState(() => _isScanning = false);
          _showSubtleNotification('Cancelled', 'No image captured', isError: true);
        }
        return;
      }
      _showSubtleNotification('Processing', 'Scanning ID document…');
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(InputImage.fromFilePath(image.path));
      await recognizer.close();
      final extracted = _extractIdData(recognized.text);
      if (mounted) {
        setState(() {
          _isScanning = false;
          if (extracted['idNumber']?.isNotEmpty ?? false) {
            _idNumberController.text = extracted['idNumber']!;
            if (extracted['name']?.isNotEmpty ?? false) _nameController.text = extracted['name']!;
            if (extracted['gender'] != null) _selectedGender = extracted['gender'];
            if (extracted['country']?.isNotEmpty ?? false) _countryController.text = extracted['country']!;
          }
        });
        _updateFormProgress();
        if (extracted['idNumber']?.isNotEmpty ?? false) {
          _showSubtleNotification('Success', 'ID scanned successfully');
          _checkExistingVisitorInBackground();
        } else {
          _showSubtleNotification('Scan Failed', 'Could not extract ID number', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showSubtleNotification('Error', 'Scanning failed: $e', isError: true);
      }
    }
  }

  Map<String, String?> _extractIdData(String text) {
    String? idNumber, name, gender, country;
    const countries = ['Kenya', 'United States', 'United Kingdom', 'Canada', 'Australia', 'India', 'Germany', 'France', 'Brazil', 'China', 'Japan', 'South Africa', 'Nigeria', 'Ghana', 'Ethiopia'];
    final patterns = {
      'national_id': {'label': r'^(ID NUMBER|National ID|Identity Number|ID Number)\b', 'value': r'^\d{7,9}$'},
      'passport_number': {'label': r'^(Passport Number|Passport No\.?|Passport)\b', 'value': r'^[A-Za-z0-9]{6,12}$'},
      'driving_licence': {'label': r'^(DL Number|Driving Licence No\.?|Driving License Number|Licence No)\b', 'value': r'^[A-Za-z0-9-]{6,}$'},
      'birth_certificate_number': {'label': r'^(Birth Certificate Number|Certificate No\.?|Birth Cert No)\b', 'value': r'^[A-Za-z0-9-]{6,}$'},
    };
    final p = patterns[_selectedIdType] ?? patterns['national_id']!;
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(p['label']!, caseSensitive: false).hasMatch(line)) {
        if (i + 1 < lines.length && RegExp(p['value']!).hasMatch(lines[i + 1].trim())) idNumber = lines[i + 1].trim();
        continue;
      } else if (idNumber == null && RegExp(p['value']!).hasMatch(line)) {
        idNumber = line;
      }
      if (RegExp(r'^(name|names|full name|full names|surname|given name(s)?)\b', caseSensitive: false).hasMatch(line)) {
        if (i + 1 < lines.length) {
          final n = lines[i + 1].trim();
          if (RegExp(r"^[A-Za-z\s-']+$").hasMatch(n) && n.split(' ').length >= 2) name = n;
        }
        continue;
      } else if (name == null && RegExp(r"^[A-Za-z\s-']+$").hasMatch(line) && line.split(' ').length >= 2) {
        name = line;
      }
      if (RegExp(r'^(sex|gender)\b', caseSensitive: false).hasMatch(line)) {
        if (i + 1 < lines.length) {
          final s = lines[i + 1].trim().toUpperCase();
          gender = s.contains('F') ? 'Female' : s.contains('M') ? 'Male' : 'Other';
        }
        continue;
      } else if (gender == null && RegExp(r'^(MALE|FEMALE|M|F|OTHER)$', caseSensitive: false).hasMatch(line)) {
        final s = line.toUpperCase();
        gender = s.contains('F') ? 'Female' : s.contains('M') ? 'Male' : 'Other';
      }
      if (country == null) {
        for (final c in countries) {
          if (line.toLowerCase().contains(c.toLowerCase())) {
            country = c;
            break;
          }
        }
        if (line.toLowerCase().contains('jamhuri ya kenya') || line.toLowerCase().contains('republic of kenya')) country = 'Kenya';
      }
    }
    return {'idNumber': idNumber, 'name': name, 'gender': gender, 'country': country};
  }

  // =========================================================================
  // Notification
  // =========================================================================

  void _showSubtleNotification(String title, String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'BrandonGrotesque')),
              Text(message, style: const TextStyle(fontSize: 12, fontFamily: 'BrandonGrotesque')),
            ],
          )),
        ],
      ),
      backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  // =========================================================================
  // UI Helpers (Square borders - BorderRadius.zero)
  // =========================================================================

  Widget _sectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.primaryBlue.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.zero, // Square corners
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'BrandonGrotesque',
              color: AppColors.primaryBlue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool required = true}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontSize: 14,
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      hintText: 'Enter $label',
      hintStyle: TextStyle(
        fontFamily: 'BrandonGrotesque',
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue, size: 22),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  Widget _spacer([double h = 12]) => SizedBox(height: h);

  // =========================================================================
  // Step 1 – Identification
  // =========================================================================

  Widget _buildIdentificationStep() => FadeInUp(
    duration: const Duration(milliseconds: 350),
    child: Form(
      key: _idFormKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Identification', Icons.credit_card),
            _spacer(),
            DropdownButtonFormField<String>(
              value: _selectedIdType,
              decoration: _inputDecoration('ID Type', Icons.badge),
              items: _idTypeOptions.map((o) => DropdownMenuItem(
                value: o['value'],
                child: Text(o['label']!, style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)),
              )).toList(),
              onChanged: (v) {
                if (mounted) setState(() {
                  _selectedIdType = v!;
                  _isMinor = v == 'birth_certificate_number';
                  _idNumberController.clear();
                  _nameController.clear();
                  _countryController.text = 'Kenya';
                  _selectedGender = null;
                  _idValidationError = null;
                });
                _updateFormProgress();
              },
              validator: (v) => v == null ? 'Please select an ID type' : null,
            ),
            _spacer(),
            TextFormField(
              controller: _idNumberController,
              decoration: _inputDecoration(_idFieldLabel, _idFieldIcon).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(Icons.camera_alt, color: AppColors.primaryBlue),
                  onPressed: _isScanning ? null : _scanID,
                  tooltip: 'Scan ID',
                ),
              ),
              style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
              validator: (v) {
                final value = v?.replaceAll(' ', '').trim() ?? '';
                if (value.isEmpty) {
                  return 'Please enter your $_idFieldLabel';
                }
                return Provider.of<VisitorProvider>(context, listen: false)
                    .validateIdNumber(value, _selectedIdType);
              },
              keyboardType: _idKeyboardType,
              inputFormatters: _idInputFormatters,
              onChanged: (_) => _updateFormProgress(),
            ),
            if (_idValidationError != null) ...[
              _spacer(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _idValidationError!,
                        style: TextStyle(fontFamily: 'BrandonGrotesque', color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _spacer(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fields marked with * are mandatory',
                      style: TextStyle(
                        fontFamily: 'BrandonGrotesque',
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // =========================================================================
  // Step 2 – Personal Details
  // =========================================================================

  Widget _buildPersonalDetailsStep() => FadeInUp(
    duration: const Duration(milliseconds: 350),
    child: Form(
      key: _personalFormKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Personal Details', Icons.person),
            _spacer(),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Full Name', Icons.person_outline),
              style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
              validator: Validators.validateName,
              keyboardType: TextInputType.name,
              onChanged: (_) => _updateFormProgress(),
            ),
            _spacer(),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: _inputDecoration('Gender', Icons.wc),
              items: _genderOptions.map((o) => DropdownMenuItem(
                value: o['value'],
                child: Text(o['label']!, style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)),
              )).toList(),
              onChanged: (v) {
                if (mounted) {
                  setState(() => _selectedGender = v);
                  _updateFormProgress();
                }
              },
              validator: (v) => v == null ? 'Please select a gender' : null,
            ),
            _spacer(),
            TextFormField(
              controller: _phoneController,
              decoration: _inputDecoration('Phone Number', Icons.phone).copyWith(
                prefixText: '$_phoneCountryCode ',
                prefixStyle: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16, color: Colors.black87),
              ),
              style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
              validator: (v) => Validators.validatePhoneNumber(v?.trim()),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _updateFormProgress(),
            ),
            if (_isMinor) ...[
              _spacer(),
              TextFormField(
                controller: _guardianPhoneController,
                decoration: _inputDecoration('Guardian Phone', Icons.supervisor_account).copyWith(
                  prefixText: '$_phoneCountryCode ',
                  prefixStyle: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16, color: Colors.black87),
                ),
                style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
                validator: Validators.validatePhoneNumber,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _updateFormProgress(),
              ),
            ],
            _spacer(),
            TextFormField(
              controller: _countryController,
              decoration: _inputDecoration('Country', Icons.public),
              style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
              validator: Validators.validateCountry,
              onChanged: (_) => _updateFormProgress(),
            ),
            _spacer(24),
            _sectionHeader('Visit Details', Icons.business_center),
            _spacer(),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _showVisitDetails ? AppColors.primaryBlue : Colors.grey.shade300),
                borderRadius: BorderRadius.zero,
              ),
              child: SwitchListTile(
                value: _showVisitDetails,
                onChanged: (v) {
                  setState(() {
                    _showVisitDetails = v;
                    if (!v) {
                      _visitType = 'staff';
                      for (final c in [
                        _hostNameController, _hostPhoneController, _hostEmailController,
                        _hostDepartmentController, _hostPositionController, _officeNameController,
                        _officePhoneController, _officeEmailController, _officeDepartmentController,
                        _officeContactPersonController, _appointmentDetailsController
                      ]) {
                        c.clear();
                      }
                      _hadAppointment = null;
                    }
                    _updateFormProgress();
                  });
                },
                title: Text(
                  'Provide Visit Details',
                  style: TextStyle(
                    fontFamily: 'BrandonGrotesque',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  _showVisitDetails ? 'Host/office information included' : 'Optional — tap to add',
                  style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 12, color: Colors.grey.shade500),
                ),
                activeColor: AppColors.primaryBlue,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            if (_showVisitDetails) ...[
              _spacer(16),
              DropdownButtonFormField<String>(
                value: _visitType,
                decoration: _inputDecoration('Visit Type', Icons.category, required: false),
                items: _visitTypeOptions.map((o) => DropdownMenuItem(
                  value: o['value'],
                  child: Text(o['label']!, style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)),
                )).toList(),
                onChanged: (v) {
                  if (mounted) setState(() {
                    _visitType = v!;
                    for (final c in [
                      _hostNameController, _hostPhoneController, _hostEmailController,
                      _hostDepartmentController, _hostPositionController, _officeNameController,
                      _officePhoneController, _officeEmailController, _officeDepartmentController,
                      _officeContactPersonController, _appointmentDetailsController
                    ]) {
                      c.clear();
                    }
                    _hadAppointment = null;
                  });
                  _updateFormProgress();
                },
              ),
              _spacer(),
              if (_visitType == 'staff') ..._buildStaffFields(),
              if (_visitType == 'office') ..._buildOfficeFields(),
              _spacer(),
              DropdownButtonFormField<String>(
                value: _hadAppointment == null ? null : (_hadAppointment! ? 'true' : 'false'),
                decoration: _inputDecoration('Had Appointment?', Icons.event_available, required: false),
                items: const [
                  DropdownMenuItem(value: 'true', child: Text('Yes', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14))),
                  DropdownMenuItem(value: 'false', child: Text('No', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14))),
                ],
                onChanged: (v) {
                  if (mounted) setState(() {
                    _hadAppointment = v == 'true';
                    if (!(_hadAppointment ?? true)) _appointmentDetailsController.clear();
                    _updateFormProgress();
                  });
                },
              ),
              _spacer(),
              TextFormField(
                controller: _appointmentDetailsController,
                decoration: _inputDecoration('Appointment Details', Icons.event_note, required: false),
                style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
                maxLines: 2,
                enabled: _hadAppointment == true,
                onChanged: (_) => _updateFormProgress(),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  List<Widget> _buildStaffFields() => [
    TextFormField(
      controller: _hostNameController,
      decoration: _inputDecoration('Host Name', Icons.person_outline, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.name,
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _hostPhoneController,
      decoration: _inputDecoration('Host Phone', Icons.phone, required: false).copyWith(
        prefixText: '$_phoneCountryCode ',
        prefixStyle: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16, color: Colors.black87),
      ),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _hostEmailController,
      decoration: _inputDecoration('Host Email', Icons.email, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _hostDepartmentController,
      decoration: _inputDecoration('Host Department', Icons.business, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _hostPositionController,
      decoration: _inputDecoration('Host Position', Icons.work_outline, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      onChanged: (_) => _updateFormProgress(),
    ),
  ];

  List<Widget> _buildOfficeFields() => [
    TextFormField(
      controller: _officeNameController,
      decoration: _inputDecoration('Office Name', Icons.business, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _officePhoneController,
      decoration: _inputDecoration('Office Phone', Icons.phone, required: false).copyWith(
        prefixText: '$_phoneCountryCode ',
        prefixStyle: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16, color: Colors.black87),
      ),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.phone,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _officeEmailController,
      decoration: _inputDecoration('Office Email', Icons.email, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _officeDepartmentController,
      decoration: _inputDecoration('Office Department', Icons.domain, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      onChanged: (_) => _updateFormProgress(),
    ),
    _spacer(),
    TextFormField(
      controller: _officeContactPersonController,
      decoration: _inputDecoration('Contact Person', Icons.contact_phone, required: false),
      style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
      keyboardType: TextInputType.name,
      onChanged: (_) => _updateFormProgress(),
    ),
  ];

  // =========================================================================
  // Step 3 – Entry Details
  // =========================================================================

  Widget _buildEntryDetailsStep() {
    final vp = Provider.of<VisitorProvider>(context);
    return FadeInUp(
      duration: const Duration(milliseconds: 350),
      child: Form(
        key: _entryFormKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    _showSubtleNotification('Fetching', 'Loading tags...');
                    await _fetchAvailableTagsInBackground();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text('Refresh Tags (${_availableTags.length} available)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
              _sectionHeader('Entry Details', Icons.login),
              _spacer(),
              DropdownButtonFormField<String>(
                value: _selectedDestinationId,
                decoration: _inputDecoration('Destination', Icons.place),
                items: vp.destinations.isNotEmpty
                    ? vp.destinations.map((d) => DropdownMenuItem(
                        value: d['id']?.toString(),
                        child: Text(
                          d['name']?.toString() ?? 'Destination ${d['id']}',
                          style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14),
                        ),
                      )).toList()
                    : [const DropdownMenuItem(value: null, child: Text('No destinations available', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)))],
                onChanged: (v) {
                  if (mounted) {
                    setState(() => _selectedDestinationId = v);
                    _updateFormProgress();
                  }
                },
                validator: (v) => v == null ? 'Please select a destination' : null,
              ),
              _spacer(),
              DropdownButtonFormField<String>(
                value: _selectedVisitorTagId,
                decoration: _inputDecoration('Visitor Tag', Icons.local_offer),
                items: _availableTags.isNotEmpty
                    ? _availableTags.map((t) => DropdownMenuItem(
                        value: t['id']?.toString(),
                        child: Row(
                          children: [
                            Icon(Icons.tag, size: 16, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text(
                              t['tag_number']?.toString() ?? 'Tag ${t['id']}',
                              style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14),
                            ),
                          ],
                        ),
                      )).toList()
                    : [const DropdownMenuItem(value: null, child: Text('No tags available - tap refresh above', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)))],
                onChanged: (v) {
                  if (mounted) {
                    setState(() => _selectedVisitorTagId = v);
                    _updateFormProgress();
                  }
                },
                validator: (v) => v == null ? 'Please select a visitor tag' : null,
              ),
              _spacer(),
              DropdownButtonFormField<String>(
                value: _selectedGate,
                decoration: _inputDecoration('Entry Gate', Icons.sensor_door),
                items: vp.gateId != null
                    ? [DropdownMenuItem(value: vp.gateId.toString(), child: Text(vp.deviceGate ?? 'Gate ${vp.gateId}', style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)))]
                    : [const DropdownMenuItem(value: null, child: Text('No gates available', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)))],
                onChanged: (v) {
                  if (mounted) {
                    setState(() => _selectedGate = v);
                    _updateFormProgress();
                  }
                },
                validator: (v) => v == null ? 'Please select a gate' : null,
              ),
              _spacer(24),
              _sectionHeader('Vehicle (Optional)', Icons.directions_car),
              _spacer(),
              DropdownButtonFormField<String>(
                value: _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
                decoration: _inputDecoration('Vehicle Type', Icons.directions_car, required: false),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14))),
                  ..._vehicleTypeOptions.map((o) => DropdownMenuItem(
                    value: o['value'],
                    child: Text(o['label']!, style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 14)),
                  )),
                ],
                onChanged: (v) {
                  if (mounted) setState(() {
                    _vehicleTypeController.text = v ?? '';
                    if (v == null) _vehicleRegController.clear();
                    _updateFormProgress();
                  });
                },
              ),
              _spacer(),
              TextFormField(
                controller: _vehicleRegController,
                decoration: _inputDecoration('Registration Number', Icons.pin, required: false),
                style: const TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 16),
                validator: (v) {
                  if (v != null && v.isNotEmpty && !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(v.trim())) {
                    return 'Invalid vehicle registration format';
                  }
                  return null;
                },
                keyboardType: TextInputType.text,
                enabled: _vehicleTypeController.text.isNotEmpty,
                onChanged: (_) => _updateFormProgress(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Navigation & Registration
  // =========================================================================

  void _handleBack() {
    if (_currentStep > 0) {
      if (mounted) setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep < 2) {
      if (_validateCurrentStep()) {
        if (mounted) setState(() => _currentStep++);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await _registerVisitor();
      if (mounted) {
        _showSubtleNotification('Success', 'Visitor registered successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSubtleNotification('Error', e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (!(_idFormKey.currentState?.validate() ?? false)) return false;
      if (_idValidationError != null) {
        _showSubtleNotification('Validation Error', _idValidationError!, isError: true);
        return false;
      }
      return true;
    }
    if (_currentStep == 1) {
      if (!(_personalFormKey.currentState?.validate() ?? false)) return false;
      if (_phoneController.text.trim().isEmpty) {
        _showSubtleNotification('Error', 'Phone number is required', isError: true);
        return false;
      }
      return true;
    }
    return true;
  }

  // Keep your existing _registerVisitor method here
  Future<void> _registerVisitor() async {
    final vp = Provider.of<VisitorProvider>(context, listen: false);
    
    debugPrint('🚀 Starting visitor registration...');
    
    if (_authToken == null || gateId == null) {
      await _loadTokenFromPreferences();
      if (_authToken == null || gateId == null) {
        throw Exception('No authentication token or gate ID found');
      }
    }
    
    if (vp.destinations.isEmpty) {
      await vp.loadDestinations();
      if (vp.destinations.isEmpty) {
        throw Exception('No destinations available');
      }
    }
    
    if (_selectedVisitorTagId == null) {
      await _fetchAvailableTagsInBackground();
      if (_availableTags.isEmpty) {
        throw Exception('No unassigned visitor tags available');
      }
      if (mounted) {
        setState(() => _selectedVisitorTagId = _availableTags.first['id'].toString());
      }
    }
    
    Map<String, dynamic>? response;
    try {
      response = await vp.checkExistingVisitor(
        _idNumberController.text.trim(), 
        _selectedIdType
      );
      debugPrint('📥 Check existing visitor response: $response');
    } catch (e) {
      debugPrint('⚠️ Error checking existing visitor: $e');
      if (!e.toString().contains('404')) {
        rethrow;
      }
    }
    
    bool isExisting = response != null && 
        (response['exists'] == true || response['exists'] == 'true') && 
        response['visitor'] != null;
    bool isCheckedIn = response != null && response['alreadyCheckedIn'] == true;
    
    debugPrint('📊 isExisting: $isExisting, isCheckedIn: $isCheckedIn');
    
    if (isExisting && isCheckedIn) {
      _showSubtleNotification(
        'Visitor Still Checked In',
        'This visitor is currently active and has not checked out. Please check them out before registering a new visit.',
        isError: true,
      );
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }
    
    final destId = int.tryParse(_selectedDestinationId ?? '');
    final tagId = int.tryParse(_selectedVisitorTagId ?? '');
    final gId = int.tryParse(_selectedGate ?? '');
    
    if (destId == null || tagId == null || gId == null) {
      throw Exception('Invalid ID format: destId=$destId, tagId=$tagId, gId=$gId');
    }
    
    String cleanPhone(String? phone) {
      if (phone == null || phone.isEmpty) return '';
      String cleaned = phone.trim();
      if (cleaned.startsWith('+254')) {
        cleaned = cleaned.substring(4);
      }
      return cleaned;
    }
    
    if (isExisting && !isCheckedIn) {
      final visitorId = int.tryParse(response!['visitor']['id'].toString());
      if (visitorId == null) {
        throw Exception('Invalid visitor ID');
      }
      
      final Map<String, dynamic> visitPayload = {
        'visitor_id': visitorId,
        'visitor_tag_id': tagId,
        'visitor_destination_id': destId,
        'gate_id': gId,
      };
      
      if (_showVisitDetails && _visitType.isNotEmpty) {
        visitPayload['visit_type'] = _visitType;
      }
      
      if (_showVisitDetails && _hadAppointment != null) {
        visitPayload['had_appointment'] = _hadAppointment;
      }
      
      if (_showVisitDetails && _appointmentDetailsController.text.isNotEmpty) {
        visitPayload['appointment_details'] = _appointmentDetailsController.text.trim();
      }
      
      if (_vehicleTypeController.text.isNotEmpty) {
        visitPayload['vehicle_type'] = _vehicleTypeController.text;
      }
      
      if (_vehicleRegController.text.isNotEmpty) {
        visitPayload['vehicle_registration'] = _vehicleRegController.text.trim();
      }
      
      if (_showVisitDetails && _visitType == 'staff') {
        if (_hostNameController.text.isNotEmpty) {
          visitPayload['host'] = _hostNameController.text.trim();
        }
        if (_hostPhoneController.text.isNotEmpty) {
          visitPayload['host_phone'] = cleanPhone(_hostPhoneController.text);
        }
        if (_hostEmailController.text.isNotEmpty) {
          visitPayload['host_email'] = _hostEmailController.text.trim();
        }
        if (_hostDepartmentController.text.isNotEmpty) {
          visitPayload['host_department'] = _hostDepartmentController.text.trim();
        }
        if (_hostPositionController.text.isNotEmpty) {
          visitPayload['host_position'] = _hostPositionController.text.trim();
        }
      }
      
      if (_showVisitDetails && _visitType == 'office') {
        if (_officeNameController.text.isNotEmpty) {
          visitPayload['office_name'] = _officeNameController.text.trim();
        }
        if (_officePhoneController.text.isNotEmpty) {
          visitPayload['office_phone'] = cleanPhone(_officePhoneController.text);
        }
        if (_officeEmailController.text.isNotEmpty) {
          visitPayload['office_email'] = _officeEmailController.text.trim();
        }
        if (_officeDepartmentController.text.isNotEmpty) {
          visitPayload['office_department'] = _officeDepartmentController.text.trim();
        }
        if (_officeContactPersonController.text.isNotEmpty) {
          visitPayload['office_contact_person'] = _officeContactPersonController.text.trim();
        }
      }
      
      debugPrint('📤 Creating visit for existing visitor: ${jsonEncode(visitPayload)}');
      await vp.createVisitForExistingVisitor(visitPayload);
      
    } else {
      final Map<String, dynamic> visitorPayload = {
        'name': _nameController.text.trim(),
        'phone_number': cleanPhone(_phoneController.text),
        'phone_country_code': _phoneCountryCode,
        'identification_type': _selectedIdType,
        'identification_number': _idNumberController.text.trim(),
        'visitor_tag_id': tagId,
        'visitor_destination_id': destId,
        'visitor_gate_id': gId,
      };
      
      if (_countryController.text.isNotEmpty && _countryController.text != 'Kenya') {
        visitorPayload['country'] = _countryController.text.trim();
      }
      
      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        visitorPayload['gender'] = _selectedGender;
      }
      
      if (_isMinor) {
        visitorPayload['is_minor'] = true;
        if (_guardianPhoneController.text.isNotEmpty) {
          visitorPayload['guardian_phone'] = cleanPhone(_guardianPhoneController.text);
        }
      } else {
        visitorPayload['is_minor'] = false;
      }
      
      if (_showVisitDetails && _visitType.isNotEmpty) {
        visitorPayload['visit_type'] = _visitType;
      }
      
      if (_showVisitDetails && _hadAppointment != null) {
        visitorPayload['had_appointment'] = _hadAppointment;
      }
      
      if (_showVisitDetails && _appointmentDetailsController.text.isNotEmpty) {
        visitorPayload['appointment_details'] = _appointmentDetailsController.text.trim();
      }
      
      if (_vehicleTypeController.text.isNotEmpty) {
        visitorPayload['vehicle_type'] = _vehicleTypeController.text;
      }
      
      if (_vehicleRegController.text.isNotEmpty) {
        visitorPayload['vehicle_registration'] = _vehicleRegController.text.trim();
      }
      
      if (_showVisitDetails && _visitType == 'staff') {
        if (_hostNameController.text.isNotEmpty) {
          visitorPayload['host'] = _hostNameController.text.trim();
        }
        if (_hostPhoneController.text.isNotEmpty) {
          visitorPayload['host_phone'] = cleanPhone(_hostPhoneController.text);
        }
        if (_hostEmailController.text.isNotEmpty) {
          visitorPayload['host_email'] = _hostEmailController.text.trim();
        }
        if (_hostDepartmentController.text.isNotEmpty) {
          visitorPayload['host_department'] = _hostDepartmentController.text.trim();
        }
        if (_hostPositionController.text.isNotEmpty) {
          visitorPayload['host_position'] = _hostPositionController.text.trim();
        }
      }
      
      if (_showVisitDetails && _visitType == 'office') {
        if (_officeNameController.text.isNotEmpty) {
          visitorPayload['office_name'] = _officeNameController.text.trim();
        }
        if (_officePhoneController.text.isNotEmpty) {
          visitorPayload['office_phone'] = cleanPhone(_officePhoneController.text);
        }
        if (_officeEmailController.text.isNotEmpty) {
          visitorPayload['office_email'] = _officeEmailController.text.trim();
        }
        if (_officeDepartmentController.text.isNotEmpty) {
          visitorPayload['office_department'] = _officeDepartmentController.text.trim();
        }
        if (_officeContactPersonController.text.isNotEmpty) {
          visitorPayload['office_contact_person'] = _officeContactPersonController.text.trim();
        }
      }
      
      visitorPayload.removeWhere((key, value) => 
          value == null || (value is String && value.isEmpty));
      
      debugPrint('📤 Registering new visitor with payload: ${jsonEncode(visitorPayload)}');
      
      final visitor = Visitor(
        id: 0,
        identificationType: _selectedIdType,
        identificationNumber: _idNumberController.text.trim(),
        name: _nameController.text.trim(),
        phoneNumber: _phoneCountryCode + _phoneController.text.trim(),
        guardianPhone: _isMinor && _guardianPhoneController.text.isNotEmpty 
            ? _phoneCountryCode + _guardianPhoneController.text.trim() 
            : null,
        visitType: _showVisitDetails ? _visitType : null,
        host: _showVisitDetails && _visitType == 'staff' && _hostNameController.text.isNotEmpty ? {
          'name': _hostNameController.text.trim(),
          'phone': _phoneCountryCode + _hostPhoneController.text.trim(),
          'email': _hostEmailController.text.isNotEmpty ? _hostEmailController.text.trim() : '',
          'department': _hostDepartmentController.text.isNotEmpty ? _hostDepartmentController.text.trim() : '',
          'position': _hostPositionController.text.isNotEmpty ? _hostPositionController.text.trim() : '',
          'id': '',
          'createdAt': DateTime.now().toIso8601String(),
        } : null,
        officeName: _showVisitDetails && _visitType == 'office' && _officeNameController.text.isNotEmpty 
            ? _officeNameController.text.trim() 
            : null,
        officePhone: _showVisitDetails && _visitType == 'office' && _officePhoneController.text.isNotEmpty 
            ? _phoneCountryCode + _officePhoneController.text.trim() 
            : null,
        officeEmail: _showVisitDetails && _visitType == 'office' && _officeEmailController.text.isNotEmpty 
            ? _officeEmailController.text.trim() 
            : null,
        officeDepartment: _showVisitDetails && _visitType == 'office' && _officeDepartmentController.text.isNotEmpty 
            ? _officeDepartmentController.text.trim() 
            : null,
        officeContactPerson: _showVisitDetails && _visitType == 'office' && _officeContactPersonController.text.isNotEmpty 
            ? _officeContactPersonController.text.trim() 
            : null,
        hadAppointment: _showVisitDetails ? _hadAppointment ?? false : null,
        appointmentDetails: _showVisitDetails && _appointmentDetailsController.text.isNotEmpty 
            ? _appointmentDetailsController.text.trim() 
            : null,
        vehicleType: _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
        vehicleRegistration: _vehicleRegController.text.isNotEmpty ? _vehicleRegController.text.trim() : null,
        destinationId: destId,
        visitorTagId: tagId,
        gateId: gId,
        isMinor: _isMinor,
        phoneCountryCode: _phoneCountryCode,
        country: _countryController.text.trim(),
        gender: _selectedGender,
      );
      
      await vp.registerVisitor(visitor);
    }
    
    debugPrint('✅ Registration completed successfully!');
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final vp = Provider.of<VisitorProvider>(context);
    final canRegister = vp.gateId != null &&
        vp.deviceGate != null &&
        vp.visitorTags.any((t) =>
            t['visitor_gate_id']?.toString() == vp.gateId?.toString() &&
            t['is_assigned'] == false);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: CustomAppBar(
        title: 'Visitor Registration',
        isDarkMode: false,
        backgroundColor: AppColors.primaryBlue,
        color: Colors.white,
        showBackButton: true,
        showNotifications: false,
        showAccount: false,
        showLogout: false,
        onBack: _handleBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: (_isBackgroundChecking || _isBackgroundFetching) ? 3 : 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue.withOpacity(0.7)),
                minHeight: 3,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(
                    'Step ${_currentStep + 1} of 3 — ${_stepTitles[_currentStep]}',
                    style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(_formProgress * 100).toInt()}% complete',
                    style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w700),
                  ),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _formProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    minHeight: 6,
                  ),
                ),
              ]),
            ),
            IconStepper(
              icons: _stepIcons.map((i) => Icon(i, color: Colors.white, size: 18)).toList(),
              activeStep: _currentStep,
              stepColor: Colors.grey.shade300,
              activeStepColor: AppColors.primaryBlue,
              activeStepBorderColor: AppColors.primaryBlue,
              lineColor: Colors.grey.shade300,
              lineLength: 56,
              onStepReached: (i) {
                if (mounted) setState(() => _currentStep = i);
              },
            ),
            Expanded(
              child: canRegister
                  ? IndexedStack(
                      index: _currentStep,
                      children: [
                        SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildIdentificationStep(),
                        ),
                        SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildPersonalDetailsStep(),
                        ),
                        SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildEntryDetailsStep(),
                        ),
                      ],
                    )
                  : _buildUnavailableState(),
            ),
            if (canRegister)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom * 0.5),
                child: Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isSubmitting || _isScanning) ? null : _handleBack,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('BACK', style: TextStyle(fontFamily: 'BrandonGrotesque', fontWeight: FontWeight.w700, fontSize: 14)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                            side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: (_isSubmitting || _isScanning) ? null : _handleNext,
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_currentStep == 2 ? Icons.how_to_reg_rounded : Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          _isSubmitting ? 'Registering…' : (_currentStep == 2 ? 'REGISTER' : 'NEXT'),
                          style: const TextStyle(fontFamily: 'BrandonGrotesque', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor: AppColors.primaryBlue.withOpacity(0.5),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Unavailable state
  // =========================================================================

  Widget _buildUnavailableState() => FadeInUp(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          const Text('Registration Unavailable',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'BrandonGrotesque', color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'No unassigned visitor tags or gate assignment found.\nPlease contact the administrator.',
            style: TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.grey.shade600, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: _silentRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry', style: TextStyle(fontFamily: 'BrandonGrotesque', fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Go Home', style: TextStyle(fontFamily: 'BrandonGrotesque', fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}