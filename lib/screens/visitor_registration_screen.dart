import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../components/custom_app_bar.dart';
import '../models/visitor.dart';
import '../models/host.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'package:flutter/scheduler.dart';

class VisitorRegistrationScreen extends StatefulWidget {
  @override
  _VisitorRegistrationScreenState createState() => _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen> {
  final _idFormKey = GlobalKey<FormState>(); // Form key for Step 1
  final _personalFormKey = GlobalKey<FormState>(); // Form key for Step 2
  final _entryFormKey = GlobalKey<FormState>(); // Form key for Step 3
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
  final _appointmentController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleRegController = TextEditingController();

  Host? _selectedHost;
  String _selectedIdType = 'national_id';
  String _visitType = 'staff';
  String _phoneCountryCode = '+254';
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isMinor = false;
  bool _showManualHostEntry = true;
  String? _selectedDestinationId;
  String? _selectedVisitorTagId;
  String? _selectedGate;
  String? _idValidationError;
  Timer? _debounceTimer;

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

  @override
  void initState() {
    super.initState();
    _idNumberController.addListener(_debouncedCheckExistingVisitor);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
    });
    try {
      await Future.wait([
        visitorProvider.loadHosts(),
        visitorProvider.loadDestinations(),
        visitorProvider.loadVisitorTags(),
        visitorProvider.loadGates(),
      ]);
      setState(() {
        _showManualHostEntry = true; // Always manual entry
        _selectedDestinationId = visitorProvider.destinations.isNotEmpty ? visitorProvider.destinations.first['id'].toString() : null;
        _selectedVisitorTagId = visitorProvider.visitorTags.isNotEmpty ? visitorProvider.visitorTags.first['id'].toString() : null;
        _selectedGate = visitorProvider.gates.isNotEmpty ? visitorProvider.gates.first : null;
      });
    } catch (e) {
      _showErrorDialog('Failed to load initial data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _debouncedCheckExistingVisitor() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      _checkExistingVisitor();
    });
  }

  Future<void> _checkExistingVisitor() async {
    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty) return;

    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final validationError = visitorProvider.validateIdNumber(idNumber, _selectedIdType);
    setState(() {
      _idValidationError = validationError;
    });

    if (validationError == null) {
      try {
        final response = await visitorProvider.checkVisitor(_selectedIdType, idNumber).timeout(Duration(seconds: 5));
        if (response != null && mounted) {
          _showExistingVisitorDialog(response);
        }
      } catch (e) {
        print('Error checking visitor: $e');
      }
    }
  }

  void _showExistingVisitorDialog(Map<String, dynamic> existingVisitor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Visitor Already Exists',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.error,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A visitor with the provided ID number already exists.',
              style: GoogleFonts.lexend(color: Colors.grey.shade600, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text('Name: ${existingVisitor['name'] ?? '—'}'),
            Text('Phone: ${existingVisitor['phone_number'] ?? '—'}'),
            if (existingVisitor['is_minor'] == true)
              Text('Guardian Phone: ${existingVisitor['guardian_phone'] ?? '—'}'),
            Text('Country: ${existingVisitor['country'] ?? '—'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lexend(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              _useExistingVisitorData(existingVisitor);
              Navigator.pop(context);
              _handleNext();
            },
            child: Text(
              'Use Existing',
              style: GoogleFonts.lexend(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Enter New Details',
              style: GoogleFonts.lexend(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _useExistingVisitorData(Map<String, dynamic> visitor) {
    setState(() {
      _nameController.text = visitor['name'] ?? '';
      _phoneController.text = visitor['phone_number']?.replaceFirst(_phoneCountryCode, '') ?? '';
      _guardianPhoneController.text = visitor['guardian_phone']?.replaceFirst(_phoneCountryCode, '') ?? '';
      _countryController.text = visitor['country'] ?? 'Kenya';
      _appointmentController.text = visitor['appointment_details'] ?? '';
      _vehicleTypeController.text = visitor['vehicle_type'] ?? '';
      _vehicleRegController.text = visitor['vehicle_registration'] ?? '';
      _isMinor = visitor['is_minor'] == true;
      if (visitor['host'] != null) {
        final host = visitor['host'] is String ? jsonDecode(visitor['host']) : visitor['host'];
        _hostNameController.text = host['name'] ?? '';
        _hostPhoneController.text = host['phone']?.replaceFirst(_phoneCountryCode, '') ?? '';
        _hostEmailController.text = host['email'] ?? '';
        _hostDepartmentController.text = host['department'] ?? '';
        _hostPositionController.text = host['position'] ?? '';
        _visitType = 'staff';
        _showManualHostEntry = true;
      } else if (visitor['office'] != null) {
        final office = visitor['office'] is String ? jsonDecode(visitor['office']) : visitor['office'];
        _officeNameController.text = office['name'] ?? '';
        _officePhoneController.text = office['phone']?.replaceFirst(_phoneCountryCode, '') ?? '';
        _officeEmailController.text = office['email'] ?? '';
        _officeDepartmentController.text = office['department'] ?? '';
        _officeContactPersonController.text = office['contact_person'] ?? '';
        _visitType = 'office';
      }
      _selectedDestinationId = visitor['destination_id']?.toString();
      _selectedVisitorTagId = visitor['visitor_tag_id']?.toString();
      _selectedGate = visitor['visitor_gate_id']?.toString() ?? visitor['gate_id']?.toString();
    });
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Error',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w600, color: AppColors.error),
        ),
        content: Text(
          message,
          style: GoogleFonts.lexend(color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.lexend(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    _appointmentController.dispose();
    _vehicleTypeController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  void _handleNext() {
    FormState? currentForm;
    if (_currentStep == 0) {
      currentForm = _idFormKey.currentState;
    } else if (_currentStep == 1) {
      currentForm = _personalFormKey.currentState;
    } else if (_currentStep == 2) {
      currentForm = _entryFormKey.currentState;
    }

    if (currentForm != null && currentForm.validate()) {
      print('Validation passed for step $_currentStep');
      if (_currentStep < 2) {
        setState(() {
          _currentStep += 1;
        });
      } else {
        _submitForm();
      }
    } else {
      print('Validation failed for step $_currentStep');
      print('ID Type: $_selectedIdType, ID Number: ${_idNumberController.text}, Validation Error: $_idValidationError');
      if (_currentStep == 0) {
        print('ID Form Validation: ${_idFormKey.currentState?.validate()}');
      }
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitForm() async {
    if (_entryFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        final visitor = Visitor(
          id: '',
          idType: _selectedIdType,
          idNumber: _idNumberController.text.trim(),
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.isNotEmpty ? '$_phoneCountryCode${_phoneController.text.trim()}' : null,
          guardianPhone: _isMinor && _guardianPhoneController.text.isNotEmpty ? '$_phoneCountryCode${_guardianPhoneController.text.trim()}' : null,
          country: _countryController.text.trim(),
          visitType: _visitType,
          host: _visitType == 'staff' && _hostNameController.text.isNotEmpty
              ? {
                  'name': _hostNameController.text.trim(),
                  'phone': _hostPhoneController.text.isNotEmpty ? '$_phoneCountryCode${_hostPhoneController.text.trim()}' : null,
                  'email': _hostEmailController.text.trim().isNotEmpty ? _hostEmailController.text.trim() : null,
                  'department': _hostDepartmentController.text.trim().isNotEmpty ? _hostDepartmentController.text.trim() : null,
                  'position': _hostPositionController.text.trim().isNotEmpty ? _hostPositionController.text.trim() : null,
                }
              : null,
          office: _visitType == 'office' && _officeNameController.text.isNotEmpty
              ? {
                  'name': _officeNameController.text.trim(),
                  'phone': _officePhoneController.text.isNotEmpty ? '$_phoneCountryCode${_officePhoneController.text.trim()}' : null,
                  'email': _officeEmailController.text.trim().isNotEmpty ? _officeEmailController.text.trim() : null,
                  'department': _officeDepartmentController.text.trim().isNotEmpty ? _officeDepartmentController.text.trim() : null,
                  'contact_person': _officeContactPersonController.text.trim().isNotEmpty ? _officeContactPersonController.text.trim() : null,
                }
              : null,
          appointmentDetails: _appointmentController.text.trim().isNotEmpty ? _appointmentController.text.trim() : null,
          destinationId: _selectedDestinationId,
          visitorTagId: _selectedVisitorTagId,
          visitorGateId: _selectedGate,
          vehicleType: _vehicleTypeController.text.trim().isNotEmpty ? _vehicleTypeController.text.trim() : null,
          vehicleRegistration: _vehicleRegController.text.trim().isNotEmpty ? _vehicleRegController.text.trim() : null,
          isMinor: _isMinor,
          action: 'register',
          gate: _selectedGate,
          time: DateTime.now(),
          createdAt: DateTime.now(),
        );

        await visitorProvider.registerVisitor(visitor);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visitor registered successfully')),
        );
      } catch (e) {
        _showErrorDialog('Failed to register visitor: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lexend(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
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
      errorText: _idValidationError,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 24),
        SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildIdentificationStep() {
    return Form(
      key: _idFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Step 1: Identification', Icons.credit_card),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedIdType,
                  decoration: _buildInputDecoration('Identification Type', Icons.credit_card),
                  items: _idTypeOptions
                      .map((option) => DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['label']!, style: GoogleFonts.lexend()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedIdType = value!;
                      _isMinor = value == 'birth_certificate_number';
                      _idNumberController.clear();
                      _idValidationError = null;
                    });
                  },
                  validator: (value) {
                    print('Dropdown validator: value=$value');
                    return value == null ? 'Please select an identification type' : null;
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _idNumberController,
                  decoration: _buildInputDecoration('ID Number', Icons.numbers),
                  validator: (value) {
                    print('ID Number validator: value=$value, idType=$_selectedIdType');
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an ID number';
                    }
                    String? error = Provider.of<VisitorProvider>(context, listen: false).validateIdNumber(value.trim(), _selectedIdType);
                    print('ID Number validation result: $error');
                    return error;
                  },
                  keyboardType: TextInputType.text,
                  onChanged: (value) {
                    setState(() {
                      _idValidationError = Provider.of<VisitorProvider>(context, listen: false).validateIdNumber(value.trim(), _selectedIdType);
                    });
                  },
                ),
              ),
            ],
          ),
          if (_idValidationError != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                _idValidationError!,
                style: GoogleFonts.lexend(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Step 2: Personal & Visit Details', Icons.person),
          SizedBox(height: 16),
          if (_isLoading)
            Center(child: CircularProgressIndicator()),
          TextFormField(
            controller: _nameController,
            decoration: _buildInputDecoration('Full Name', Icons.person),
            validator: Validators.validateName,
            keyboardType: TextInputType.name,
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 100,
                child: TextFormField(
                  decoration: _buildInputDecoration('Code', Icons.phone),
                  controller: TextEditingController(text: _phoneCountryCode),
                  readOnly: true,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: _buildInputDecoration('Phone Number', Icons.phone),
                  validator: Validators.validatePhoneNumber,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          if (_isMinor) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  child: TextFormField(
                    decoration: _buildInputDecoration('Code', Icons.phone),
                    controller: TextEditingController(text: _phoneCountryCode),
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _guardianPhoneController,
                    decoration: _buildInputDecoration('Guardian Phone Number', Icons.phone),
                    validator: Validators.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: _buildInputDecoration('Country', Icons.public),
            validator: Validators.validateCountry,
            keyboardType: TextInputType.text,
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _visitType,
            decoration: _buildInputDecoration('Visit Type', Icons.work),
            items: _visitTypeOptions
                .map((option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(option['label']!, style: GoogleFonts.lexend()),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _visitType = value!;
                _selectedHost = null;
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
              });
            },
            validator: (value) => value == null ? 'Please select a visit type' : null,
          ),
          SizedBox(height: 16),
          if (_visitType == 'staff') ...[
            TextFormField(
              controller: _hostNameController,
              decoration: _buildInputDecoration('Host Name', Icons.person),
              validator: Validators.validateName,
              keyboardType: TextInputType.name,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  child: TextFormField(
                    decoration: _buildInputDecoration('Code', Icons.phone),
                    controller: TextEditingController(text: _phoneCountryCode),
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _hostPhoneController,
                    decoration: _buildInputDecoration('Host Phone Number', Icons.phone),
                    validator: Validators.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hostEmailController,
              decoration: _buildInputDecoration('Host Email', Icons.email),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hostDepartmentController,
              decoration: _buildInputDecoration('Host Department', Icons.business),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hostPositionController,
              decoration: _buildInputDecoration('Host Position', Icons.work),
              keyboardType: TextInputType.text,
            ),
            if (visitorProvider.hosts.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'No hosts available. Please enter host details manually.',
                  style: GoogleFonts.lexend(color: Colors.grey.shade600),
                ),
              ),
          ],
          if (_visitType == 'office') ...[
            TextFormField(
              controller: _officeNameController,
              decoration: _buildInputDecoration('Office Name', Icons.business),
              validator: Validators.validateRequired,
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  child: TextFormField(
                    decoration: _buildInputDecoration('Code', Icons.phone),
                    controller: TextEditingController(text: _phoneCountryCode),
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _officePhoneController,
                    decoration: _buildInputDecoration('Office Phone Number', Icons.phone),
                    validator: Validators.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _officeEmailController,
              decoration: _buildInputDecoration('Office Email', Icons.email),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _officeDepartmentController,
              decoration: _buildInputDecoration('Office Department', Icons.business),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _officeContactPersonController,
              decoration: _buildInputDecoration('Contact Person', Icons.person),
              validator: Validators.validateName,
              keyboardType: TextInputType.name,
            ),
          ],
          SizedBox(height: 16),
          TextFormField(
            controller: _appointmentController,
            decoration: _buildInputDecoration('Appointment Details', Icons.event),
            keyboardType: TextInputType.text,
          ),
        ],
      ),
    );
  }

  Widget _buildEntryDetailsStep() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    return Form(
      key: _entryFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Step 3: Entry Details', Icons.directions),
          SizedBox(height: 16),
          if (_isLoading)
            Center(child: CircularProgressIndicator()),
          DropdownButtonFormField<String>(
            value: _selectedDestinationId,
            decoration: _buildInputDecoration('Destination', Icons.location_on),
            items: visitorProvider.destinations.isNotEmpty
                ? visitorProvider.destinations
                    .map((dest) => DropdownMenuItem(
                          value: dest['id'].toString(),
                          child: Text(dest['name'] ?? 'Unknown', style: GoogleFonts.lexend()),
                        ))
                    .toList()
                : [
                    DropdownMenuItem(
                      value: null,
                      child: Text('No destinations available', style: GoogleFonts.lexend()),
                    ),
                  ],
            onChanged: visitorProvider.destinations.isNotEmpty
                ? (value) {
                    setState(() {
                      _selectedDestinationId = value;
                    });
                  }
                : null,
            validator: (value) => visitorProvider.destinations.isEmpty ? 'No destinations available' : (value == null ? 'Please select a destination' : null),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedVisitorTagId,
            decoration: _buildInputDecoration('Visitor Tag', Icons.tag),
            items: visitorProvider.visitorTags.isNotEmpty
                ? visitorProvider.visitorTags
                    .map((tag) => DropdownMenuItem(
                          value: tag['id'].toString(),
                          child: Text(tag['tag_number'] ?? 'Tag ${tag['id']}', style: GoogleFonts.lexend()),
                        ))
                    .toList()
                : [
                    DropdownMenuItem(
                      value: null,
                      child: Text('No tags available', style: GoogleFonts.lexend()),
                    ),
                  ],
            onChanged: visitorProvider.visitorTags.isNotEmpty
                ? (value) {
                    setState(() {
                      _selectedVisitorTagId = value;
                    });
                  }
                : null,
            validator: (value) => visitorProvider.visitorTags.isEmpty ? 'No visitor tags available' : (value == null ? 'Please select a visitor tag' : null),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGate,
            decoration: _buildInputDecoration('Visitor Gate', Icons.door_front_door),
            items: visitorProvider.gates.isNotEmpty
                ? visitorProvider.gates
                    .map((gate) => DropdownMenuItem(
                          value: gate,
                          child: Text(gate, style: GoogleFonts.lexend()),
                        ))
                    .toList()
                : [
                    DropdownMenuItem(
                      value: null,
                      child: Text('No gates available', style: GoogleFonts.lexend()),
                    ),
                  ],
            onChanged: visitorProvider.gates.isNotEmpty
                ? (value) {
                    setState(() {
                      _selectedGate = value;
                    });
                  }
                : null,
            validator: (value) => visitorProvider.gates.isEmpty ? 'No gates available' : (value == null ? 'Please select a visitor gate' : null),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _vehicleTypeController.text.isNotEmpty ? _vehicleTypeController.text : null,
            decoration: _buildInputDecoration('Vehicle Type', Icons.directions_car),
            items: _vehicleTypeOptions
                .map((option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(option['label']!, style: GoogleFonts.lexend()),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _vehicleTypeController.text = value!;
              });
            },
            validator: (value) => null,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _vehicleRegController,
            decoration: _buildInputDecoration('Vehicle Registration', Icons.directions_car),
            keyboardType: TextInputType.text,
            validator: (value) => null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Visitor Registration',
        backgroundColor: AppColors.primaryBlue,
        color: Colors.white,
        showBackButton: true,
        showNotifications: false,
        showAccount: false,
        showLogout: false,
        onBack: _handleBack,
      ),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _handleNext,
          onStepCancel: _handleBack,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    ElevatedButton(
                      onPressed: details.onStepCancel,
                      child: Text(
                        'Back',
                        style: GoogleFonts.lexend(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    child: Text(
                      _currentStep == 2 ? (_isLoading ? 'Registering...' : 'Register Visitor') : 'Continue',
                      style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: Text('Identification', style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
              content: _buildIdentificationStep(),
              isActive: _currentStep == 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('Personal & Visit Details', style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
              content: _buildPersonalDetailsStep(),
              isActive: _currentStep == 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text('Entry Details', style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
              content: _buildEntryDetailsStep(),
              isActive: _currentStep == 2,
              state: _currentStep == 2 ? StepState.indexed : StepState.disabled,
            ),
          ],
        ),
      ),
    );
  }
}