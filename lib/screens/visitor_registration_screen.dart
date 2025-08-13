import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../components/custom_app_bar.dart';
import '../models/visitor.dart';
import '../models/host.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'package:flutter/scheduler.dart';

class VisitorRegistrationScreen extends StatefulWidget {
  @override
  _VisitorRegistrationScreenState createState() =>
      _VisitorRegistrationScreenState();
}

class _VisitorRegistrationScreenState extends State<VisitorRegistrationScreen> {
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
  bool _isScanning = false;

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

  void _debouncedCheckExistingVisitor() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkExistingVisitor();
    });
  }

  Future<void> _loadInitialData() async {
    // TODO: Implement any initial data loading logic here if needed.
    // For example, you might want to fetch destinations, visitor tags, etc.
    // If not needed, you can leave this method empty.
  }

  // Checks if a visitor with the entered ID already exists and sets validation error if needed.
  void _checkExistingVisitor() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final idNumber = _idNumberController.text.trim();
    if (idNumber.isEmpty) {
      setState(() {
        _idValidationError = null;
      });
      return;
    }
    final error = visitorProvider.validateIdNumber(idNumber, _selectedIdType);
    setState(() {
      _idValidationError = error;
    });
  }

  // ... [Keep all your existing methods like _refreshVisitorTags, _loadInitialData, etc.] ...

  Future<void> _scanID() async {
    try {
      setState(() {
        _isScanning = true;
      });
      
      // Simulate scanning - replace with actual barcode scanning logic
      await Future.delayed(Duration(seconds: 1));
      
      // For demo purposes, we'll just generate a random ID number
      final randomId = _selectedIdType == 'national_id' 
          ? '3${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 7)}'
          : 'A${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 7)}';
      
      setState(() {
        _idNumberController.text = randomId;
        _isScanning = false;
      });
      
      // Auto-validate after scan
      _checkExistingVisitor();
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showErrorDialog('Scanning failed: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error', style: GoogleFonts.lexend(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.lexend()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.lexend()),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isRequired = true}) {
    return InputDecoration(
      labelText: '$label${isRequired ? ' *' : ''}',
      labelStyle: GoogleFonts.lexend(
        color: isRequired ? AppColors.primaryBlue : Colors.grey.shade600,
      ),
      hintText: 'Enter $label',
      hintStyle: GoogleFonts.lexend(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      errorStyle: GoogleFonts.lexend(color: AppColors.error, fontSize: 12),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 22),
          SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          Spacer(),
          if (_currentStep == 0 && _idNumberController.text.isEmpty)
            TextButton.icon(
              onPressed: _scanID,
              icon: Icon(Icons.qr_code_scanner, size: 20),
              label: Text(
                'Scan ID',
                style: GoogleFonts.lexend(fontSize: 14),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.primaryBlue),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Identification Details', Icons.credit_card),
          SizedBox(height: 20),
          if (_isScanning)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Scanning ID...', style: GoogleFonts.lexend()),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    decoration: _buildInputDecoration(
                      'ID Type',
                      Icons.credit_card,
                      isRequired: true,
                    ),
                    items: _idTypeOptions.map((option) => DropdownMenuItem(
                      value: option['value'],
                      child: Text(
                        option['label']!,
                        style: GoogleFonts.lexend(),
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedIdType = value!;
                        _isMinor = value == 'birth_certificate_number';
                        _idNumberController.clear();
                        _idValidationError = null;
                      });
                    },
                    validator: (value) => value == null 
                        ? 'Please select an ID type' 
                        : null,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _idNumberController,
                    decoration: _buildInputDecoration(
                      'ID Number', 
                      Icons.numbers,
                      isRequired: true,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(Icons.qr_code_scanner),
                        onPressed: _scanID,
                        tooltip: 'Scan ID',
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an ID number';
                      }
                      return Provider.of<VisitorProvider>(context, listen: false)
                          .validateIdNumber(value.trim(), _selectedIdType);
                    },
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      if (_selectedIdType == 'national_id')
                        FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ),
              ],
            ),
            if (_idValidationError != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  _idValidationError!,
                  style: GoogleFonts.lexend(
                    color: AppColors.error, 
                    fontSize: 12,
                  ),
                ),
              ),
            SizedBox(height: 16),
            Text(
              'Fields marked with * are mandatory',
              style: GoogleFonts.lexend(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsStep() {
    return Form(
      key: _personalFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Personal Details', Icons.person),
            SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: _buildInputDecoration(
                'Full Name', 
                Icons.person_outline,
                isRequired: true,
              ),
              validator: Validators.validateName,
              keyboardType: TextInputType.name,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  child: TextFormField(
                    decoration: _buildInputDecoration(
                      'Code', 
                      Icons.phone,
                      isRequired: true,
                    ),
                    controller: TextEditingController(text: _phoneCountryCode),
                    readOnly: true,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: _buildInputDecoration(
                      'Phone Number',
                      Icons.phone_outlined,
                      isRequired: true,
                    ),
                    validator: Validators.validatePhoneNumber,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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
                      decoration: _buildInputDecoration(
                        'Code', 
                        Icons.phone,
                        isRequired: true,
                      ),
                      controller: TextEditingController(text: _phoneCountryCode),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianPhoneController,
                      decoration: _buildInputDecoration(
                        'Guardian Phone',
                        Icons.phone_outlined,
                        isRequired: true,
                      ),
                      validator: Validators.validatePhoneNumber,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              decoration: _buildInputDecoration(
                'Country', 
                Icons.public,
                isRequired: true,
              ),
              validator: Validators.validateCountry,
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 24),
            _buildSectionHeader('Visit Details', Icons.work_outline),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _visitType,
              decoration: _buildInputDecoration(
                'Visit Type', 
                Icons.work_outline,
                isRequired: true,
              ),
              items: _visitTypeOptions.map((option) => DropdownMenuItem(
                value: option['value'],
                child: Text(
                  option['label']!,
                  style: GoogleFonts.lexend(),
                ),
              )).toList(),
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
              validator: (value) => value == null 
                  ? 'Please select a visit type' 
                  : null,
            ),
            SizedBox(height: 16),
            if (_visitType == 'staff') ...[
              TextFormField(
                controller: _hostNameController,
                decoration: _buildInputDecoration(
                  'Host Name', 
                  Icons.person_outline,
                  isRequired: true,
                ),
                validator: Validators.validateName,
                keyboardType: TextInputType.name,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 100,
                    child: TextFormField(
                      decoration: _buildInputDecoration(
                        'Code', 
                        Icons.phone,
                        isRequired: true,
                      ),
                      controller: TextEditingController(text: _phoneCountryCode),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _hostPhoneController,
                      decoration: _buildInputDecoration(
                        'Host Phone',
                        Icons.phone_outlined,
                        isRequired: true,
                      ),
                      validator: Validators.validatePhoneNumber,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _hostEmailController,
                decoration: _buildInputDecoration(
                  'Host Email', 
                  Icons.email_outlined,
                  isRequired: false,
                ),
                validator: Validators.validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _hostDepartmentController,
                decoration: _buildInputDecoration(
                  'Host Department', 
                  Icons.business_outlined,
                  isRequired: false,
                ),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _hostPositionController,
                decoration: _buildInputDecoration(
                  'Host Position', 
                  Icons.work_outline,
                  isRequired: false,
                ),
                keyboardType: TextInputType.text,
              ),
            ],
            if (_visitType == 'office') ...[
              TextFormField(
                controller: _officeNameController,
                decoration: _buildInputDecoration(
                  'Office Name', 
                  Icons.business_outlined,
                  isRequired: true,
                ),
                validator: Validators.validateRequired,
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 100,
                    child: TextFormField(
                      decoration: _buildInputDecoration(
                        'Code', 
                        Icons.phone,
                        isRequired: true,
                      ),
                      controller: TextEditingController(text: _phoneCountryCode),
                      readOnly: true,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _officePhoneController,
                      decoration: _buildInputDecoration(
                        'Office Phone',
                        Icons.phone_outlined,
                        isRequired: true,
                      ),
                      validator: Validators.validatePhoneNumber,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _officeEmailController,
                decoration: _buildInputDecoration(
                  'Office Email', 
                  Icons.email_outlined,
                  isRequired: false,
                ),
                validator: Validators.validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _officeDepartmentController,
                decoration: _buildInputDecoration(
                  'Office Department', 
                  Icons.business_outlined,
                  isRequired: false,
                ),
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _officeContactPersonController,
                decoration: _buildInputDecoration(
                  'Contact Person', 
                  Icons.person_outline,
                  isRequired: true,
                ),
                validator: Validators.validateName,
                keyboardType: TextInputType.name,
              ),
            ],
            SizedBox(height: 16),
            TextFormField(
              controller: _appointmentController,
              decoration: _buildInputDecoration(
                'Appointment Details', 
                Icons.event_outlined,
                isRequired: false,
              ),
              keyboardType: TextInputType.text,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryDetailsStep() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final availableTags = visitorProvider.gateId != null
        ? visitorProvider.visitorTags.where((tag) {
            final gateMatch = tag['visitor_gate_id']?.toString() ==
                visitorProvider.gateId?.toString();
            final unassigned = tag['is_assigned'] == false ||
                tag['is_assigned'].toString() == 'false';
            return gateMatch && unassigned;
          }).toList()
        : [];

    if (_selectedVisitorTagId != null &&
        !availableTags.any(
            (tag) => tag['id']?.toString() == _selectedVisitorTagId)) {
      _selectedVisitorTagId =
          availableTags.isNotEmpty ? availableTags.first['id']?.toString() : null;
    }

    final hasValidGate =
        visitorProvider.gateId != null && visitorProvider.deviceGate != null;

    return Form(
      key: _entryFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Entry Details', Icons.directions),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedDestinationId,
              decoration: _buildInputDecoration(
                'Destination', 
                Icons.location_on_outlined,
                isRequired: true,
              ),
              items: visitorProvider.destinations.isNotEmpty
                  ? visitorProvider.destinations.map((dest) => DropdownMenuItem(
                      value: dest['id']?.toString(),
                      child: Text(
                        dest['name']?.toString() ?? 'Unknown',
                        style: GoogleFonts.lexend(),
                      ),
                    )).toList()
                  : [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'No destinations available',
                          style: GoogleFonts.lexend(),
                        ),
                      ),
                    ],
              onChanged: visitorProvider.destinations.isNotEmpty
                  ? (value) {
                      setState(() {
                        _selectedDestinationId = value;
                      });
                    }
                  : null,
              validator: (value) => visitorProvider.destinations.isEmpty
                  ? 'No destinations available'
                  : (value == null ? 'Please select a destination' : null),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVisitorTagId,
              decoration: _buildInputDecoration(
                'Visitor Tag', 
                Icons.tag_outlined,
                isRequired: true,
              ),
              items: availableTags.isNotEmpty
                  ? availableTags.map((tag) => DropdownMenuItem(
                      value: tag['id']?.toString(),
                      child: Text(
                        tag['tag_number']?.toString() ?? 'Tag ${tag['id']}',
                        style: GoogleFonts.lexend(),
                      ),
                    )).toList()
                  : [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'No tags available',
                          style: GoogleFonts.lexend(),
                        ),
                      ),
                    ],
              onChanged: availableTags.isNotEmpty
                  ? (value) {
                      setState(() {
                        _selectedVisitorTagId = value;
                      });
                    }
                  : null,
              validator: (value) => availableTags.isEmpty
                  ? 'No unassigned visitor tags available'
                  : (value == null ? 'Please select a visitor tag' : null),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: hasValidGate ? _selectedGate : null,
              decoration: _buildInputDecoration(
                'Visitor Gate', 
                Icons.door_front_door_outlined,
                isRequired: true,
              ),
              items: hasValidGate
                  ? [
                      DropdownMenuItem(
                        value: visitorProvider.gateId?.toString(),
                        child: Text(
                          visitorProvider.deviceGate ?? 'Unknown',
                          style: GoogleFonts.lexend(),
                        ),
                      ),
                    ]
                  : [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'No gate assigned',
                          style: GoogleFonts.lexend(),
                        ),
                      ),
                    ],
              onChanged: hasValidGate
                  ? (value) {
                      setState(() {
                        _selectedGate = value;
                      });
                    }
                  : null,
              validator: (value) => !hasValidGate
                  ? 'No gate assigned to device'
                  : (value == null ? 'Please select a visitor gate' : null),
            ),
            SizedBox(height: 24),
            _buildSectionHeader('Vehicle Details', Icons.directions_car_outlined),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _vehicleTypeController.text.isNotEmpty
                  ? _vehicleTypeController.text
                  : null,
              decoration: _buildInputDecoration(
                'Vehicle Type', 
                Icons.directions_car_outlined,
                isRequired: false,
              ),
              items: _vehicleTypeOptions.map((option) => DropdownMenuItem(
                value: option['value'],
                child: Text(
                  option['label']!,
                  style: GoogleFonts.lexend(),
                ),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _vehicleTypeController.text = value!;
                });
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _vehicleRegController,
              decoration: _buildInputDecoration(
                'Vehicle Registration', 
                Icons.confirmation_number_outlined,
                isRequired: false,
              ),
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 16),
            Text(
              '* Mandatory fields',
              style: GoogleFonts.lexend(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleNext() async {
    if (_currentStep == 0) {
      if (_idFormKey.currentState?.validate() ?? false) {
        setState(() {
          _currentStep = 1;
        });
      }
    } else if (_currentStep == 1) {
      if (_personalFormKey.currentState?.validate() ?? false) {
        setState(() {
          _currentStep = 2;
        });
      }
    } else if (_currentStep == 2) {
      if (_entryFormKey.currentState?.validate() ?? false) {
        setState(() {
          _isLoading = true;
        });
        try {
          // TODO: Implement registration logic here.
          // After successful registration:
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pop(); // Or show a success dialog/snackbar
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog('Registration failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final canRegister = visitorProvider.gateId != null &&
        visitorProvider.deviceGate != null &&
        visitorProvider.visitorTags.any((tag) =>
            tag['visitor_gate_id']?.toString() ==
                visitorProvider.gateId?.toString() &&
            (tag['is_assigned'] == false ||
                tag['is_assigned'].toString() == 'false'));

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
        child: canRegister
            ? Stepper(
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
                          OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                              side: BorderSide(color: AppColors.primaryBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'BACK',
                              style: GoogleFonts.lexend(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            _currentStep == 2
                                ? (_isLoading ? 'REGISTERING...' : 'REGISTER')
                                : 'NEXT',
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: Text(
                      'Identification',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w500,
                        color: _currentStep == 0
                            ? AppColors.primaryBlue
                            : Colors.grey,
                      ),
                    ),
                    content: _buildIdentificationStep(),
                    isActive: _currentStep == 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text(
                      'Personal Details',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w500,
                        color: _currentStep == 1
                            ? AppColors.primaryBlue
                            : Colors.grey,
                      ),
                    ),
                    content: _buildPersonalDetailsStep(),
                    isActive: _currentStep == 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text(
                      'Entry Details',
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w500,
                        color: _currentStep == 2
                            ? AppColors.primaryBlue
                            : Colors.grey,
                      ),
                    ),
                    content: _buildEntryDetailsStep(),
                    isActive: _currentStep == 2,
                    state: StepState.indexed,
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    SizedBox(height: 20),
                    Text(
                      'Registration Unavailable',
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'No unassigned visitor tags or gate assignment available. Please contact the administrator.',
                        style: GoogleFonts.lexend(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: Text(
                        'RETURN HOME',
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}