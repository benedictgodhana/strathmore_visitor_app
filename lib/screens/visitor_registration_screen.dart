import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

// Custom exceptions for better error handling
class VisitorAuthException implements Exception {
  final String message;
  VisitorAuthException(this.message);
}

class VisitorNetworkException implements Exception {
  final String message;
  VisitorNetworkException(this.message);
}

class VisitorValidationException implements Exception {
  final String message;
  VisitorValidationException(this.message);
}

class VisitorRegistrationScreen extends StatefulWidget {
  const VisitorRegistrationScreen({super.key});

  @override
  _VisitorRegistrationScreenState createState() => _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen> {
  // Form keys and controllers
  final _idFormKey = GlobalKey<FormState>();
  final _personalFormKey = GlobalKey<FormState>();
  final _entryFormKey = GlobalKey<FormState>();
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

  // State variables
  List<Map<String, dynamic>> _availableTags = [];
  String? _authToken;
  String? gateId;
  String? deviceGate;
  bool _isRefreshing = false;
  String? _token;
  String _selectedIdType = 'national_id';
  String _visitType = 'staff';
  String _phoneCountryCode = '+254';
  int _currentStep = 0;
  bool _isLoading = false;
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
  bool _showVisitDetails = false; // Controls only staff/office visit details

  // Options for dropdowns
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

  @override
  void initState() {
    super.initState();
    _idNumberController.addListener(_debouncedCheckExistingVisitor);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
    _updateFormProgress();
  }

  @override
  void dispose() {
    _idNumberController.removeListener(_debouncedCheckExistingVisitor);
    _idNumberController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _guardianPhoneController.dispose();
    _countryController.dispose();
    _hostNameController.dispose();
    _hostPhoneController.dispose();
    _hostEmailController.dispose();
    _hostDepartmentController.dispose();
    _hostPositionController.dispose();
    _officeNameController.dispose();
    _officePhoneController.dispose();
    _officeEmailController.dispose();
    _officeDepartmentController.dispose();
    _officeContactPersonController.dispose();
    _appointmentDetailsController.dispose();
    _vehicleTypeController.dispose();
    _vehicleRegController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _updateFormProgress() {
    int totalFields = 11; // Adjusted for required fields
    int filledFields = 0;

    if (_idNumberController.text.isNotEmpty) filledFields++;
    if (_nameController.text.isNotEmpty) filledFields++;
    if (_phoneController.text.isNotEmpty) filledFields++;
    if (_selectedGender != null) filledFields++;
    if (_countryController.text.isNotEmpty) filledFields++;
    if (_selectedDestinationId != null) filledFields++;
    if (_selectedVisitorTagId != null) filledFields++;
    if (_selectedGate != null) filledFields++;
    // Vehicle fields are optional, so they don't contribute to required fields
    if (_showVisitDetails && _hadAppointment != null) filledFields++;
    if (_showVisitDetails && _visitType == 'staff' && _hostNameController.text.isNotEmpty) filledFields++;
    else if (_showVisitDetails && _visitType == 'office' && _officeNameController.text.isNotEmpty) filledFields++;

    setState(() {
      _formProgress = filledFields / totalFields;
    });
  }

  void _debouncedCheckExistingVisitor() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _checkExistingVisitor();
      }
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadTokenFromPreferences();
      await _fetchAvailableTags();
      final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
      await visitorProvider.loadDestinations();
      await visitorProvider.loadVisitorTags();
      await visitorProvider.loadCheckedInVisitors();
    } catch (e) {
      _showErrorDialog('Failed to load initial data: $e');
      debugPrint('❌ Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _token = null;
      _authToken = null;
      gateId = null;
      deviceGate = null;
    });
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
      if (_token == null || gateId == null) {
        await _clearPreferences();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      debugPrint(_token != null ? '✅ Loaded auth token: ${_token!.substring(0, 10)}...' : '⚠️ No auth token found');
      debugPrint(gateId != null ? '✅ Loaded gateId: $gateId' : '⚠️ No gateId found');
      debugPrint('📴 Loaded cached gate: $deviceGate');
      if (_token != null && gateId != null && deviceGate != null) {
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        visitorProvider.setAuthData(_token!, gateId!, deviceGate!);
      }
    } catch (e) {
      debugPrint('❌ Error loading token from SharedPreferences: $e');
      await _clearPreferences();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _checkExistingVisitor() async {
    if (!mounted) return;
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final idNumber = _idNumberController.text.trim();
    debugPrint('Checking visitor ID: $idNumber, Type: $_selectedIdType');
    if (idNumber.isEmpty) {
      if (mounted) {
        setState(() => _idValidationError = null);
      }
      debugPrint('ID is empty, skipping check');
      return;
    }
    final error = visitorProvider.validateIdNumber(idNumber, _selectedIdType);
    if (error != null) {
      if (mounted) {
        setState(() => _idValidationError = error);
      }
      debugPrint('Validation error: $error');
      return;
    }

    try {
      setState(() => _isLoading = true);
      final response = await visitorProvider.checkExistingVisitor(idNumber, _selectedIdType);
      debugPrint('Check visitor response: ${jsonEncode(response)}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response != null && (response['exists'] == true || response['exists'] == 'true') && response['visitor'] != null) {
            final visitorData = response['visitor'] as Map<String, dynamic>;
            final visitorStatus = response['visitorStatus']?.toString() ?? 'unknown';
            debugPrint('Visitor status: isCheckedIn=${response['alreadyCheckedIn']}, visitorStatus=$visitorStatus');
            if (response['alreadyCheckedIn'] == true) {
              _idValidationError = 'Visitor is currently active at this gate';
              _showExistingVisitorDialog(visitorData, visitorStatus: visitorStatus);
            } else {
              _idValidationError = null;
              _showExistingVisitorDialog(visitorData, visitorStatus: visitorStatus);
            }
          } else {
            _idValidationError = null;
            debugPrint('No existing visitor found for ID $idNumber');
            if (_idFormKey.currentState?.validate() ?? false) {
              _currentStep += 1;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking existing visitor: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString().contains('404')) {
            _idValidationError = null;
            debugPrint('No visitor found for ID $idNumber');
            if (_idFormKey.currentState?.validate() ?? false) {
              _currentStep += 1;
            }
          } else if (e.toString().contains('401')) {
            _idValidationError = 'Session expired. Please log in again.';
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          } else if (e.toString().contains('422')) {
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) _checkExistingVisitor();
            });
            _idValidationError = 'Validation error, retrying...';
          } else {
            _idValidationError = 'Error checking ID: $e';
          }
        });
      }
    }
  }

  Future<void> _fetchAvailableTags() async {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    try {
      final token = _authToken ?? visitorProvider.token;
      if (token == null || gateId == null) {
        debugPrint('⚠️ Cannot fetch tags: No token or gate ID');
        throw VisitorAuthException('No authentication token or gate ID');
      }
      debugPrint('📥 Fetch tags with token: ${token.substring(0, 10)}...');
      final response = await http.get(
        Uri.parse('${AppStrings.apiBaseUrl}/api/visitor-tags?unassigned=true&gate_id=$gateId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      debugPrint('📥 Fetch tags response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _availableTags = List<Map<String, dynamic>>.from(data['tags'])
                .where((tag) => tag['is_assigned'] == false)
                .map((tag) {
                  if (tag['tag_number'] == null || tag['tag_number'].toString().isEmpty) {
                    tag['tag_number'] = 'Tag ${tag['id'] ?? 'Unknown'}';
                  }
                  return tag;
                }).toList();
            _selectedVisitorTagId = _availableTags.isNotEmpty ? _availableTags.first['id']?.toString() : null;
          });
        }
      } else if (response.statusCode == 401) {
        _showErrorDialog('Session expired. Please log in again.');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        throw VisitorNetworkException('Failed to load tags: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching tags: $e');
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) _fetchAvailableTags();
      });
      _showErrorDialog('Error fetching tags, retrying...');
    }
  }

  Future<void> _refreshData() async {
    if (_token == null || gateId == null) {
      debugPrint('⚠️ token or gateId is null, cannot refresh data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication token or gate information missing'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        if (_token == null) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      }
      return;
    }

    if (!mounted) return;

    setState(() => _isRefreshing = true);
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    try {
      await Future.wait([
        _fetchAvailableTags(),
        visitorProvider.loadDestinations(),
        visitorProvider.loadVisitorTags(),
        visitorProvider.loadCheckedInVisitors(),
        visitorProvider.logVisitCount(),
      ]);

      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _showErrorDialog('Failed to refresh data: $e');
        debugPrint('❌ Error refreshing data: $e');
      }
    }
  }

  Future<void> _scanID() async {
    try {
      setState(() => _isScanning = true);
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        if (mounted) {
          setState(() => _isScanning = false);
          _showErrorDialog('No image captured.');
        }
        return;
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      String extractedText = recognizedText.text;
      await textRecognizer.close();

      debugPrint('📷 Extracted text: $extractedText');

      String? idNumber;
      String? name;
      String? gender;
      String? country;

      const countryNames = [
        'Kenya', 'United States', 'United Kingdom', 'Canada', 'Australia', 'India',
        'Germany', 'France', 'Brazil', 'China', 'Japan', 'South Africa', 'Nigeria',
        'Ghana', 'Ethiopia',
      ];

      Map<String, Map<String, String>> idTypePatterns = {
        'national_id': {
          'label': r'^(ID Number|National ID|Identity Number|1D Number)\b',
          'value': r'^\d{7,9}$',
        },
        'passport_number': {
          'label': r'^(Passport Number|Passport No\.?|Passport)\b',
          'value': r'^[A-Za-z0-9]{6,12}$',
        },
        'driving_licence': {
          'label': r'^(DL Number|Driving Licence No\.?|Driving License Number|Licence No)\b',
          'value': r'^[A-Za-z0-9-]{6,}$',
        },
        'birth_certificate_number': {
          'label': r'^(Birth Certificate Number|Certificate No\.?|Birth Cert No)\b',
          'value': r'^[A-Za-z0-9-]{6,}$',
        },
      };

      final idPatterns = idTypePatterns[_selectedIdType] ?? idTypePatterns['national_id']!;
      final lines = extractedText.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

      bool isNameField = false;
      bool isSexField = false;
      bool isIdField = false;

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].toLowerCase();

        if (RegExp(idPatterns['label']!, caseSensitive: false).hasMatch(line)) {
          isIdField = true;
          if (i + 1 < lines.length) {
            var potentialId = lines[i + 1].trim();
            if (RegExp(idPatterns['value']!).hasMatch(potentialId)) {
              idNumber = potentialId;
            }
          }
          continue;
        } else if (_selectedIdType != 'national_id' && idNumber == null && RegExp(idPatterns['value']!).hasMatch(line)) {
          idNumber = line;
        }

        if (_selectedIdType == 'national_id' && RegExp(r'^(id number|id no\.?)\b', caseSensitive: false).hasMatch(line)) {
          isIdField = false;
          continue;
        }

        if (RegExp(r'^(name|names|full name|full names|surname|given name(s)?)\b', caseSensitive: false).hasMatch(line)) {
          isNameField = true;
          if (i + 1 < lines.length) {
            name = lines[i + 1].trim();
            if (!RegExp(r"^[A-Za-z\s-']+$").hasMatch(name) || name.split(' ').length < 2) {
              name = null;
            }
          }
          continue;
        } else if (name == null && RegExp(r"^[A-Za-z\s-']+$").hasMatch(line) && line.split(' ').length >= 2) {
          name = line;
        }

        if (RegExp(r'^(sex|gender)\b', caseSensitive: false).hasMatch(line)) {
          isSexField = true;
          if (i + 1 < lines.length) {
            var sexValue = lines[i + 1].trim().toUpperCase();
            if (sexValue.contains('M') || sexValue.contains('MALE')) {
              gender = 'Male';
            } else if (sexValue.contains('F') || sexValue.contains('FEMALE')) {
              gender = 'Female';
            } else {
              gender = 'Other';
            }
          }
          continue;
        } else if (gender == null && RegExp(r'^(MALE|FEMALE|M|F|OTHER)$', caseSensitive: false).hasMatch(line)) {
          var sexValue = line.toUpperCase();
          if (sexValue.contains('M') || sexValue.contains('MALE')) {
            gender = 'Male';
          } else if (sexValue.contains('F') || sexValue.contains('FEMALE')) {
            gender = 'Female';
          } else {
            gender = 'Other';
          }
        }

        if (country == null) {
          for (var countryName in countryNames) {
            if (line.contains(countryName.toLowerCase()) || _isFuzzyMatch(line, countryName.toLowerCase())) {
              country = countryName;
              break;
            }
          }
          if (line.contains('jamhuri ya kenya') || line.contains('republic of kenya')) {
            country = 'Kenya';
          }
        }

        if (isNameField || isSexField || isIdField) {
          isNameField = false;
          isSexField = false;
          isIdField = false;
        }
      }

      if (name != null) {
        name = name.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ').trim();
        final nameValidationResult = Validators.validateName(name);
        if (nameValidationResult != null && nameValidationResult.isNotEmpty) {
          name = null;
        }
      }

      if (idNumber != null) {
        final idValidationResult = Provider.of<VisitorProvider>(context, listen: false).validateIdNumber(idNumber, _selectedIdType);
        if (idValidationResult != null) {
          idNumber = null;
        }
      }

      if (idNumber == null) {
        if (mounted) {
          setState(() => _isScanning = false);
          _showErrorDialog('Could not extract ID number. Please verify the image or enter manually.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _idNumberController.text = idNumber ?? '';
          if (name != null) _nameController.text = name;
          if (country != null) _countryController.text = country;
          if (gender != null) _selectedGender = gender;
          _isMinor = _selectedIdType == 'birth_certificate_number';
          _isScanning = false;
        });
        _updateFormProgress();
      }

      final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
      final response = await visitorProvider.checkExistingVisitor(idNumber, _selectedIdType);
      if (response != null && (response['exists'] == true || response['exists'] == 'true') && response['visitor'] != null && mounted) {
        final existingVisitor = response['visitor'] as Map<String, dynamic>;
        final visitorStatus = response['visitorStatus']?.toString() ?? 'unknown';
        _showExistingVisitorDialog(existingVisitor, visitorStatus: visitorStatus);
      } else if (name != null && gender != null && country != null) {
        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Extracted Data', style: GoogleFonts.afacad(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID Number: $idNumber', style: GoogleFonts.afacad()),
                  Text('Full Name: $name', style: GoogleFonts.afacad()),
                  Text('Gender: $gender', style: GoogleFonts.afacad()),
                  Text('Country: $country', style: GoogleFonts.afacad()),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Edit', style: GoogleFonts.afacad()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Confirm', style: GoogleFonts.afacad()),
              ),
            ],
          ),
        );

        if (confirmed != true && mounted) {
          setState(() {
            _idNumberController.clear();
            _nameController.clear();
            _countryController.text = 'Kenya';
            _selectedGender = null;
            _idValidationError = null;
          });
          _updateFormProgress();
        } else if (mounted && _idFormKey.currentState != null && _idFormKey.currentState!.validate()) {
          setState(() => _currentStep += 1);
        }
      } else {
        final missingFields = [if (name == null) 'full name', if (gender == null) 'gender', if (country == null) 'country'].join(', ');
        if (mounted) {
          _showErrorDialog('Could not extract $missingFields. Please verify the image or enter manually.');
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showErrorDialog('Scanning failed: $e');
      }
      debugPrint('❌ Error during scanning: $e\n$stackTrace');
    }
  }

  bool _isFuzzyMatch(String input, String pattern) {
    input = input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    pattern = pattern.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    int differences = 0;
    if (input.length < pattern.length || input.length > pattern.length + 3) {
      return false;
    }
    for (int i = 0; i < input.length && i < pattern.length; i++) {
      if (input[i] != pattern[i]) differences++;
      if (differences > 2) return false;
    }
    return true;
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error', style: GoogleFonts.afacad(fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.afacad()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: GoogleFonts.afacad()),
            ),
          ],
        ),
      );
    }
  }

  void _showExistingVisitorDialog(Map<String, dynamic> visitorData, {required String visitorStatus}) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Existing Visitor Found', style: GoogleFonts.afacad(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${visitorData['identification_number']?.toString() ?? 'Unknown'}', style: GoogleFonts.afacad()),
                Text('Name: ${visitorData['name']?.toString() ?? 'Not provided'}', style: GoogleFonts.afacad()),
                Text('Phone: ${visitorData['phone_number']?.toString() ?? 'Not provided'}', style: GoogleFonts.afacad()),
                Text(
                  'Status: ${visitorStatus == 'active' ? 'Active (Checked In)' : visitorStatus == 'completed' ? 'Completed (Checked Out)' : 'Unknown'}',
                  style: GoogleFonts.afacad(),
                ),
                if (visitorData['tag'] != null)
                  Text(
                    'Tag: ${(visitorData['tag']['tag_number']?.toString().isNotEmpty ?? false) ? visitorData['tag']['tag_number'] : 'Tag ${visitorData['tag']['id'] ?? 'Unknown'}'}',
                    style: GoogleFonts.afacad(),
                  ),
                Text(
                  visitorStatus == 'active'
                      ? 'This visitor is currently active at this gate.'
                      : 'This visitor has been registered before. Would you like to create a new visit or start a new registration?',
                  style: GoogleFonts.afacad(),
                ),
              ],
            ),
          ),
          actions: [
            if (visitorStatus != 'active') ...[
              TextButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _nameController.text = visitorData['name']?.toString() ?? '';
                      _phoneController.text = visitorData['phone_number']?.toString().replaceFirst('+254', '') ?? '';
                      _countryController.text = visitorData['country']?.toString() ?? 'Kenya';
                      _selectedGender = visitorData['gender']?.toString();
                      _isMinor = visitorData['is_minor'] == true;
                      if (_isMinor) {
                        _guardianPhoneController.text = visitorData['guardian_phone']?.toString().replaceFirst('+254', '') ?? '';
                      }
                      _idValidationError = null;
                      _currentStep = 1; // Move to personal details step
                    });
                    _updateFormProgress();
                    Navigator.of(context).pop();
                  }
                },
                child: Text('Create New Visit', style: GoogleFonts.afacad()),
              ),
              TextButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _idValidationError = null;
                      _nameController.clear();
                      _phoneController.clear();
                      _guardianPhoneController.clear();
                      _countryController.text = 'Kenya';
                      _selectedGender = null;
                      _isMinor = false;
                      _idNumberController.clear();
                      _selectedIdType = 'national_id';
                    });
                    Navigator.of(context).pop();
                  }
                },
                child: Text('Register New', style: GoogleFonts.afacad()),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.afacad()),
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isRequired = true, bool solo = false}) {
    return InputDecoration(
      labelText: '$label${isRequired ? ' *' : ''}',
      labelStyle: GoogleFonts.afacad(color: isRequired ? AppColors.primaryBlue : Colors.grey.shade600),
      hintText: 'Enter $label',
      hintStyle: GoogleFonts.afacad(color: Colors.grey.shade400),
      prefixIcon: solo ? null : Icon(icon, color: AppColors.primaryBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      errorStyle: GoogleFonts.afacad(color: AppColors.error, fontSize: 12),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {bool showScanButton = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.afacad(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const Spacer(),
          if (showScanButton)
            ZoomIn(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scanID,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: Text('Scan ID', style: GoogleFonts.afacad(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentificationStep() {
    return Form(
      key: _idFormKey,
      child: FadeInUp(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Identification Details', Icons.credit_card, showScanButton: _idNumberController.text.isEmpty),
                const SizedBox(height: 20),
                if (_isScanning)
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text('Scanning ID...', style: GoogleFonts.afacad()),
                      ],
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    decoration: _buildInputDecoration('ID Type', Icons.credit_card, solo: true),
                    items: _idTypeOptions.map((option) => DropdownMenuItem(value: option['value'], child: Text(option['label']!, style: GoogleFonts.afacad()))).toList(),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _selectedIdType = value!;
                          _isMinor = value == 'birth_certificate_number';
                          _idNumberController.clear();
                          _nameController.clear();
                          _countryController.text = 'Kenya';
                          _selectedGender = null;
                          _idValidationError = null;
                        });
                        _updateFormProgress();
                      }
                    },
                    validator: (value) => value == null ? 'Please select an ID type' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _idNumberController,
                    decoration: _buildInputDecoration('ID Number', Icons.numbers, solo: true).copyWith(
                      suffixIcon: IconButton(icon: const Icon(Icons.camera_alt), onPressed: _isScanning ? null : _scanID, tooltip: 'Scan ID'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an ID number';
                      }
                      return Provider.of<VisitorProvider>(context, listen: false).validateIdNumber(value.trim(), _selectedIdType);
                    },
                    keyboardType: _selectedIdType == 'national_id' ? TextInputType.number : TextInputType.text,
                    inputFormatters: [
                      if (_selectedIdType == 'national_id') FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) => _updateFormProgress(),
                    autofocus: true,
                  ),
                  if (_idValidationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_idValidationError!, style: GoogleFonts.afacad(color: AppColors.error, fontSize: 12)),
                    ),
                  const SizedBox(height: 16),
                  Text('Fields marked with * are mandatory', style: GoogleFonts.afacad(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    return Form(
      key: _personalFormKey,
      child: FadeInUp(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Personal Details', Icons.person),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Full Name', Icons.person_outline, solo: true),
                  validator: Validators.validateName,
                  keyboardType: TextInputType.name,
                  onChanged: (value) => _updateFormProgress(),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _buildInputDecoration('Gender', Icons.person, solo: true),
                  items: _genderOptions.map((option) => DropdownMenuItem(value: option['value'], child: Text(option['label']!, style: GoogleFonts.afacad()))).toList(),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _selectedGender = value);
                      _updateFormProgress();
                    }
                  },
                  validator: (value) => value == null ? 'Please select a gender' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined, solo: true).copyWith(
                    prefixText: '$_phoneCountryCode ',
                    prefixStyle: GoogleFonts.afacad(color: Colors.black),
                  ),
                  validator: (value) => Validators.validatePhoneNumber(value?.trim()),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _updateFormProgress(),
                ),
                if (_isMinor) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _guardianPhoneController,
                    decoration: _buildInputDecoration('Guardian Phone', Icons.phone_outlined, solo: true).copyWith(
                      prefixText: '$_phoneCountryCode ',
                      prefixStyle: GoogleFonts.afacad(color: Colors.black),
                    ),
                    validator: Validators.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _updateFormProgress(),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _countryController,
                  decoration: _buildInputDecoration('Country', Icons.public, solo: true),
                  validator: Validators.validateCountry,
                  keyboardType: TextInputType.text,
                  onChanged: (value) => _updateFormProgress(),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Visit Details', Icons.work_outline),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _showVisitDetails,
                  onChanged: (value) {
                    setState(() {
                      _showVisitDetails = value ?? false;
                      if (!_showVisitDetails) {
                        _visitType = 'staff';
                        _hostNameController.clear();
                        _hostPhoneController.clear();
                        _hostEmailController.clear();
                        _hostDepartmentController.clear();
                        _hostPositionController.clear();
                        _officeNameController.clear();
                        _officePhoneController.clear();
                        _officeEmailController.clear();
                        _officeDepartmentController.clear();
                        _officeContactPersonController.clear();
                        _hadAppointment = null;
                        _appointmentDetailsController.clear();
                      }
                      _updateFormProgress();
                    });
                  },
                  title: Text('Provide Visit Details', style: GoogleFonts.afacad()),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_showVisitDetails) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _visitType,
                    decoration: _buildInputDecoration('Visit Type', Icons.work_outline, solo: true, isRequired: false),
                    items: _visitTypeOptions.map((option) => DropdownMenuItem(value: option['value'], child: Text(option['label']!, style: GoogleFonts.afacad()))).toList(),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _visitType = value!;
                          _hostNameController.clear();
                          _hostPhoneController.clear();
                          _hostEmailController.clear();
                          _hostDepartmentController.clear();
                          _hostPositionController.clear();
                          _officeNameController.clear();
                          _officePhoneController.clear();
                          _officeEmailController.clear();
                          _officeDepartmentController.clear();
                          _officeContactPersonController.clear();
                          _hadAppointment = null;
                          _appointmentDetailsController.clear();
                        });
                        _updateFormProgress();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_visitType == 'staff') ...[
                    TextFormField(
                      controller: _hostNameController,
                      decoration: _buildInputDecoration('Host Name', Icons.person_outline, isRequired: false, solo: true),
                      validator: _showVisitDetails && _hostNameController.text.isNotEmpty ? Validators.validateName : null,
                      keyboardType: TextInputType.name,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostPhoneController,
                      decoration: _buildInputDecoration('Host Phone', Icons.phone_outlined, isRequired: false, solo: true).copyWith(
                        prefixText: '$_phoneCountryCode ',
                        prefixStyle: GoogleFonts.afacad(color: Colors.black),
                      ),
                      validator: _showVisitDetails && _hostPhoneController.text.isNotEmpty ? Validators.validatePhoneNumber : null,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostEmailController,
                      decoration: _buildInputDecoration('Host Email', Icons.email_outlined, isRequired: false, solo: true),
                      validator: _showVisitDetails && _hostEmailController.text.isNotEmpty ? Validators.validateEmail : null,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostDepartmentController,
                      decoration: _buildInputDecoration('Host Department', Icons.business_outlined, isRequired: false, solo: true),
                      keyboardType: TextInputType.text,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hostPositionController,
                      decoration: _buildInputDecoration('Host Position', Icons.work_outline, isRequired: false, solo: true),
                      keyboardType: TextInputType.text,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                  ],
                  if (_visitType == 'office') ...[
                    TextFormField(
                      controller: _officeNameController,
                      decoration: _buildInputDecoration('Office Name', Icons.business_outlined, isRequired: false, solo: true),
                      validator: _showVisitDetails && _officeNameController.text.isNotEmpty ? Validators.validateRequired : null,
                      keyboardType: TextInputType.text,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _officePhoneController,
                      decoration: _buildInputDecoration('Office Phone', Icons.phone_outlined, isRequired: false, solo: true).copyWith(
                        prefixText: '$_phoneCountryCode ',
                        prefixStyle: GoogleFonts.afacad(color: Colors.black),
                      ),
                      validator: _showVisitDetails && _officePhoneController.text.isNotEmpty ? Validators.validatePhoneNumber : null,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _officeEmailController,
                      decoration: _buildInputDecoration('Office Email', Icons.email_outlined, isRequired: false, solo: true),
                      validator: _showVisitDetails && _officeEmailController.text.isNotEmpty ? Validators.validateEmail : null,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _officeDepartmentController,
                      decoration: _buildInputDecoration('Office Department', Icons.business_outlined, isRequired: false, solo: true),
                      keyboardType: TextInputType.text,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _officeContactPersonController,
                      decoration: _buildInputDecoration('Contact Person', Icons.person_outline, isRequired: false, solo: true),
                      validator: _showVisitDetails && _officeContactPersonController.text.isNotEmpty ? Validators.validateName : null,
                      keyboardType: TextInputType.name,
                      onChanged: (value) => _updateFormProgress(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _hadAppointment == null ? null : (_hadAppointment! ? 'true' : 'false'),
                    decoration: _buildInputDecoration('Had Appointment', Icons.event_outlined, isRequired: false, solo: true),
                    items: [
                      DropdownMenuItem(value: 'true', child: Text('Yes', style: GoogleFonts.afacad())),
                      DropdownMenuItem(value: 'false', child: Text('No', style: GoogleFonts.afacad())),
                    ],
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _hadAppointment = value == 'true';
                          if (!_hadAppointment!) {
                            _appointmentDetailsController.clear();
                          }
                          _updateFormProgress();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _appointmentDetailsController,
                    decoration: _buildInputDecoration('Appointment Details', Icons.event_note_outlined, isRequired: false, solo: true),
                    keyboardType: TextInputType.text,
                    maxLines: 2,
                    enabled: _hadAppointment == true,
                    onChanged: (value) => _updateFormProgress(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryDetailsStep() {
    final visitorProvider = Provider.of<VisitorProvider>(context);
    return Form(
      key: _entryFormKey,
      child: FadeInUp(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Entry Details', Icons.directions),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedDestinationId,
                  decoration: _buildInputDecoration('Destination', Icons.place, solo: true),
                  items: visitorProvider.destinations.isNotEmpty
                      ? visitorProvider.destinations
                          .map((dest) => DropdownMenuItem(
                                value: dest['id']?.toString(),
                                child: Text(dest['name']?.toString() ?? 'Destination ${dest['id']}', style: GoogleFonts.afacad()),
                              ))
                          .toList()
                      : [const DropdownMenuItem(value: null, child: Text('No destinations available', style: TextStyle(fontFamily: 'afacad')))],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _selectedDestinationId = value);
                      _updateFormProgress();
                    }
                  },
                  validator: (value) => value == null ? 'Please select a destination' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedVisitorTagId,
                  decoration: _buildInputDecoration('Visitor Tag', Icons.tag, solo: true),
                  items: _availableTags.isNotEmpty
                      ? _availableTags
                          .map((tag) => DropdownMenuItem(
                                value: tag['id']?.toString(),
                                child: Text(tag['tag_number']?.toString() ?? 'Tag ${tag['id']}', style: GoogleFonts.afacad()),
                              ))
                          .toList()
                      : [const DropdownMenuItem(value: null, child: Text('No tags available', style: TextStyle(fontFamily: 'afacad')))],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _selectedVisitorTagId = value);
                      _updateFormProgress();
                    }
                  },
                  validator: (value) => value == null ? 'Please select a visitor tag' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGate,
                  decoration: _buildInputDecoration('Gate', Icons.door_front_door, solo: true),
                  items: visitorProvider.gateId != null
                      ? [
                          DropdownMenuItem(
                            value: visitorProvider.gateId.toString(),
                            child: Text(visitorProvider.deviceGate ?? 'Gate ${visitorProvider.gateId}', style: GoogleFonts.afacad()),
                          )
                        ]
                      : [const DropdownMenuItem(value: null, child: Text('No gates available', style: TextStyle(fontFamily: 'afacad')))],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _selectedGate = value);
                      _updateFormProgress();
                    }
                  },
                  validator: (value) => value == null ? 'Please select a gate' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
                  decoration: _buildInputDecoration('Vehicle Type', Icons.directions_car, isRequired: false, solo: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontFamily: 'afacad'))),
                    ..._vehicleTypeOptions
                        .map((option) => DropdownMenuItem(value: option['value'], child: Text(option['label']!, style: GoogleFonts.afacad())))
                        .toList(),
                  ],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _vehicleTypeController.text = value ?? '';
                        if (value == null) _vehicleRegController.clear();
                        _updateFormProgress();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleRegController,
                  decoration: _buildInputDecoration('Vehicle Registration', Icons.directions_car, isRequired: false, solo: true),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value.trim())) {
                      return 'Invalid vehicle registration format';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.text,
                  onChanged: (value) => _updateFormProgress(),
                  enabled: _vehicleTypeController.text.isNotEmpty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBack() {
    if (_currentStep > 0) {
      if (mounted) {
        setState(() => _currentStep -= 1);
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNext() async {
    FormState? currentFormKey;
    if (_currentStep == 0) {
      currentFormKey = _idFormKey.currentState;
      if (currentFormKey?.validate() ?? false) {
        await _checkExistingVisitor();
        if (_idValidationError != null) {
          _showErrorDialog(_idValidationError!);
          return;
        }
      } else {
        return;
      }
    } else if (_currentStep == 1) {
      currentFormKey = _personalFormKey.currentState;
      if (currentFormKey?.validate() ?? false) {
        if (_phoneController.text.trim().isEmpty) {
          _showErrorDialog('Phone number is required.');
          return;
        }
        if (_showVisitDetails) {
          if (_visitType == 'staff') {
            if (_hostNameController.text.trim().isNotEmpty && Validators.validateName(_hostNameController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid host name.');
              return;
            }
            if (_hostPhoneController.text.trim().isNotEmpty && Validators.validatePhoneNumber(_hostPhoneController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid host phone number.');
              return;
            }
            if (_hostEmailController.text.trim().isNotEmpty && Validators.validateEmail(_hostEmailController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid host email.');
              return;
            }
          } else if (_visitType == 'office') {
            if (_officeNameController.text.trim().isNotEmpty && Validators.validateRequired(_officeNameController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid office name.');
              return;
            }
            if (_officePhoneController.text.trim().isNotEmpty && Validators.validatePhoneNumber(_officePhoneController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid office phone number.');
              return;
            }
            if (_officeEmailController.text.trim().isNotEmpty && Validators.validateEmail(_officeEmailController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid office email.');
              return;
            }
            if (_officeContactPersonController.text.trim().isNotEmpty && Validators.validateName(_officeContactPersonController.text.trim()) != null) {
              _showErrorDialog('Please enter a valid office contact person name.');
              return;
            }
          }
        }
      } else {
        return;
      }
    } else if (_currentStep == 2) {
      currentFormKey = _entryFormKey.currentState;
      if (currentFormKey?.validate() ?? false) {
        if (_authToken == null || gateId == null) {
          await _loadTokenFromPreferences();
          if (_authToken == null || gateId == null) {
            _showErrorDialog('No authentication token or gate ID found. Please log in again.');
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            return;
          }
        }
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        if (visitorProvider.destinations.isEmpty) {
          await visitorProvider.loadDestinations();
          if (visitorProvider.destinations.isEmpty) {
            _showErrorDialog('No destinations available. Please contact the administrator.');
            return;
          }
        }
        if (_selectedVisitorTagId == null) {
          await _fetchAvailableTags();
          if (_availableTags.isEmpty) {
            _showErrorDialog('No unassigned visitor tags available. Please contact the administrator.');
            return;
          }
          if (mounted) {
            setState(() => _selectedVisitorTagId = _availableTags.first['id'].toString());
          }
        }
        if (_selectedDestinationId == null) {
          _showErrorDialog('Please select a valid destination.');
          return;
        }
        if (_selectedGate == null || _selectedGate != visitorProvider.gateId?.toString()) {
          _showErrorDialog('Invalid or missing gate selection. Please select the correct gate.');
          return;
        }

        // Validate vehicle registration if provided
        if (_vehicleRegController.text.isNotEmpty && !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(_vehicleRegController.text.trim())) {
          _showErrorDialog('Invalid vehicle registration format.');
          return;
        }

        // Check if visitor exists
        final response = await visitorProvider.checkExistingVisitor(_idNumberController.text.trim(), _selectedIdType);
        bool isExistingVisitor = response != null && (response['exists'] == true || response['exists'] == 'true') && response['visitor'] != null;
        bool isCheckedIn = response != null && response['alreadyCheckedIn'] == true;

        // Show confirmation dialog
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isExistingVisitor ? 'Confirm New Visit' : 'Confirm Registration', style: GoogleFonts.afacad(fontWeight: FontWeight.bold)),
            content: Text(
              isExistingVisitor ? 'Create a new visit for this existing visitor?' : 'Are you sure you want to register this visitor?',
              style: GoogleFonts.afacad(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.afacad()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Confirm', style: GoogleFonts.afacad()),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        if (mounted) {
          setState(() => _isLoading = true);
        }

        try {
          // Parse IDs
          final destinationId = int.tryParse(_selectedDestinationId ?? '');
          final visitorTagId = int.tryParse(_selectedVisitorTagId ?? '');
          final gateIdParsed = int.tryParse(_selectedGate ?? '');

          if (destinationId == null || visitorTagId == null || gateIdParsed == null) {
            throw VisitorNetworkException('Invalid ID format: destinationId=$destinationId, visitorTagId=$visitorTagId, gateId=$gateIdParsed');
          }

          if (isExistingVisitor && !isCheckedIn) {
            // Create visit for existing visitor
            final visitorId = int.tryParse(response['visitor']['id'].toString());
            if (visitorId == null) {
              throw VisitorValidationException('Invalid visitor ID for existing visitor');
            }

            final visit = {
              'visitor_id': visitorId,
              'visit_type': _showVisitDetails ? _visitType : null,
              'visitor_destination_id': destinationId,
              'visitor_tag_id': visitorTagId,
              'gate_id': gateIdParsed,
              'had_appointment': _showVisitDetails ? _hadAppointment : null,
              'appointment_details': _showVisitDetails && _appointmentDetailsController.text.isNotEmpty ? _appointmentDetailsController.text.trim() : null,
              'vehicle_type': _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
              'vehicle_registration': _vehicleRegController.text.isNotEmpty ? _vehicleRegController.text.trim() : null,
              if (_showVisitDetails && _visitType == 'staff') ...{
                'host': _hostNameController.text.isNotEmpty ? _hostNameController.text.trim() : null,
                'host_phone': _hostPhoneController.text.isNotEmpty ? _phoneCountryCode + _hostPhoneController.text.trim() : null,
                'host_email': _hostEmailController.text.isNotEmpty ? _hostEmailController.text.trim() : null,
                'host_department': _hostDepartmentController.text.isNotEmpty ? _hostDepartmentController.text.trim() : null,
                'host_position': _hostPositionController.text.isNotEmpty ? _hostPositionController.text.trim() : null,
              },
              if (_showVisitDetails && _visitType == 'office') ...{
                'office_name': _officeNameController.text.isNotEmpty ? _officeNameController.text.trim() : null,
                'office_phone': _officePhoneController.text.isNotEmpty ? _phoneCountryCode + _officePhoneController.text.trim() : null,
                'office_email': _officeEmailController.text.isNotEmpty ? _officeEmailController.text.trim() : null,
                'office_department': _officeDepartmentController.text.isNotEmpty ? _officeDepartmentController.text.trim() : null,
                'office_contact_person': _officeContactPersonController.text.isNotEmpty ? _officeContactPersonController.text.trim() : null,
              },
            };

            debugPrint('📤 Creating visit for existing visitor with payload: ${jsonEncode(visit)}');
            await visitorProvider.createVisitForExistingVisitor(visit);

            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Visit created successfully for existing visitor!', style: GoogleFonts.afacad()),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              Navigator.of(context).pop();
            }
          } else if (isExistingVisitor && isCheckedIn) {
            throw VisitorValidationException('Visitor is currently active. Cannot create a new visit until checked out.');
          } else {
            // Register new visitor
            final visitor = Visitor(
              id: 0,
              identificationType: _selectedIdType,
              identificationNumber: _idNumberController.text.trim(),
              name: _nameController.text.trim(),
              phoneNumber: _phoneCountryCode + _phoneController.text.trim(),
              guardianPhone: _isMinor ? _phoneCountryCode + _guardianPhoneController.text.trim() : null,
              visitType: _showVisitDetails ? _visitType : null,
              host: _showVisitDetails && _visitType == 'staff' && _hostNameController.text.isNotEmpty
                  ? {
                      'name': _hostNameController.text.trim(),
                      'phone': _phoneCountryCode + _hostPhoneController.text.trim(),
                      'email': _hostEmailController.text.isNotEmpty ? _hostEmailController.text.trim() : '',
                      'department': _hostDepartmentController.text.isNotEmpty ? _hostDepartmentController.text.trim() : '',
                      'position': _hostPositionController.text.isNotEmpty ? _hostPositionController.text.trim() : '',
                      'id': '',
                      'createdAt': DateTime.now().toIso8601String(),
                    }
                  : null,
              officeName: _showVisitDetails && _visitType == 'office' && _officeNameController.text.isNotEmpty ? _officeNameController.text.trim() : null,
              officePhone: _showVisitDetails && _visitType == 'office' && _officePhoneController.text.isNotEmpty ? _phoneCountryCode + _officePhoneController.text.trim() : null,
              officeEmail: _showVisitDetails && _visitType == 'office' && _officeEmailController.text.isNotEmpty ? _officeEmailController.text.trim() : null,
              officeDepartment: _showVisitDetails && _visitType == 'office' && _officeDepartmentController.text.isNotEmpty ? _officeDepartmentController.text.trim() : null,
              officeContactPerson: _showVisitDetails && _visitType == 'office' && _officeContactPersonController.text.isNotEmpty ? _officeContactPersonController.text.trim() : null,
              hadAppointment: _showVisitDetails ? _hadAppointment ?? false : null,
              appointmentDetails: _showVisitDetails && _appointmentDetailsController.text.isNotEmpty ? _appointmentDetailsController.text.trim() : null,
              vehicleType: _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
              vehicleRegistration: _vehicleRegController.text.isNotEmpty ? _vehicleRegController.text.trim() : null,
              destinationId: destinationId,
              visitorTagId: visitorTagId,
              gateId: gateIdParsed,
              isMinor: _isMinor,
              phoneCountryCode: _phoneCountryCode,
              country: _countryController.text.trim(),
              gender: _selectedGender,
            );

            debugPrint('📤 Registering new visitor with payload: ${jsonEncode(visitor.toMap())}');
            await visitorProvider.registerVisitor(visitor);

            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Visitor registered successfully!', style: GoogleFonts.afacad()),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
              Navigator.of(context).pop();
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            debugPrint('Registration error: $e');
            if (e is VisitorAuthException) {
              _showErrorDialog('Session expired. Please log in again.');
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            } else if (e is VisitorNetworkException || e is VisitorValidationException) {
              String errorMessage = e.toString();
              if (errorMessage.contains('422')) {
                try {
                  final errorBody = jsonDecode(errorMessage.split(' - ').last);
                  errorMessage = errorBody['message'] ?? 'Validation error occurred';
                } catch (_) {
                  errorMessage = 'Validation error: ${errorMessage.split(':').last.trim()}';
                }
                if (errorMessage.contains('visitor tag is already assigned')) {
                  await _fetchAvailableTags();
                  if (_availableTags.isEmpty) {
                    _showErrorDialog('No unassigned visitor tags available. Please contact the administrator.');
                  } else {
                    if (mounted) {
                      setState(() => _selectedVisitorTagId = _availableTags.first['id'].toString());
                      _showErrorDialog('Visitor tag is already assigned. A new tag has been selected. Please try again.');
                    }
                  }
                } else if (errorMessage.contains('visitor_destination_id')) {
                  _showErrorDialog('Invalid destination selected. Please try again.');
                  await visitorProvider.loadDestinations();
                } else if (errorMessage.contains('gate_id') || errorMessage.contains('visitor_gates')) {
                  _showErrorDialog('Invalid gate configuration. Please contact the administrator or try again.');
                  await _loadInitialData();
                } else {
                  _showErrorDialog(errorMessage);
                }
              } else if (errorMessage.contains('500')) {
                _showErrorDialog('Server error occurred. Please contact the administrator.');
              } else {
                _showErrorDialog('Registration failed: $e');
              }
            } else {
              _showErrorDialog('Registration failed: $e');
            }
          }
          return;
        }
      }
    }

    if (mounted && _currentStep < 2) {
      setState(() => _currentStep += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorProvider = Provider.of<VisitorProvider>(context);
    final canRegister = visitorProvider.gateId != null &&
        visitorProvider.deviceGate != null &&
        visitorProvider.visitorTags.any((tag) => tag['visitor_gate_id']?.toString() == visitorProvider.gateId?.toString() && tag['is_assigned'] == false);

    final steps = [
      _buildIdentificationStep(),
      _buildPersonalDetailsStep(),
      _buildEntryDetailsStep(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
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
        child: _isLoading || _isRefreshing
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: AppColors.primaryBlue,
                child: canRegister
                    ? Column(
                        children: [
                          // Progress Indicator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: LinearProgressIndicator(
                              value: _formProgress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Form Progress: ${(_formProgress * 100).toInt()}%',
                              style: GoogleFonts.afacad(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Stepper
                          IconStepper(
                            icons: const [
                              Icon(Icons.credit_card, color: Colors.white),
                              Icon(Icons.person, color: Colors.white),
                              Icon(Icons.directions, color: Colors.white),
                            ],
                            activeStep: _currentStep,
                            stepColor: Colors.grey.shade300,
                            activeStepColor: AppColors.primaryBlue,
                            activeStepBorderColor: AppColors.primaryBlue,
                            lineColor: Colors.grey.shade400,
                            lineLength: 60,
                            onStepReached: (index) {
                              if (mounted) {
                                setState(() => _currentStep = index);
                              }
                            },
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: steps[_currentStep],
                              ),
                            ),
                          ),
                          // Navigation Buttons
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_currentStep > 0)
                                  ZoomIn(
                                    child: OutlinedButton(
                                      onPressed: _isLoading || _isScanning ? null : _handleBack,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primaryBlue,
                                        side: const BorderSide(color: AppColors.primaryBlue),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      child: Text('BACK', style: GoogleFonts.afacad(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ),
                                  ),
                                ZoomIn(
                                  child: ElevatedButton(
                                    onPressed: _isLoading || _isScanning ? null : _handleNext,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryBlue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                    child: Text(
                                      _currentStep == 2 ? (_isLoading ? 'REGISTERING...' : 'REGISTER') : 'NEXT',
                                      style: GoogleFonts.afacad(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: FadeInUp(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                              const SizedBox(height: 20),
                              Text('Registration Unavailable', style: GoogleFonts.afacad(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.error)),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'No unassigned visitor tags or gate assignment available. Please contact the administrator.',
                                  style: GoogleFonts.afacad(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ZoomIn(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  child: Text('RETURN HOME', style: GoogleFonts.afacad(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}