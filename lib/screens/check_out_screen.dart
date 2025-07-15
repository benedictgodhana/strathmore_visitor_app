
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';
import 'dart:convert';

class CheckOutScreen extends StatefulWidget {
  @override
  _CheckOutScreenState createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _scrollController = ScrollController();

  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  bool _isCheckingOut = false;
  Visitor? _visitor;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        if (visitorProvider.visitors.isEmpty) {
          visitorProvider.loadCheckedInVisitors();
        }
      } catch (e) {
        _showErrorMessage('Failed to load initial data: ${e.toString()}');
      }
    });
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    _animationController.forward();

    Future.delayed(Duration(seconds: 5), () {
      if (mounted && _errorMessage == message) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
    _animationController.forward();

    Future.delayed(Duration(seconds: 3), () {
      if (mounted && _successMessage == message) {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }
Future<void> _fetchVisitor(String idNumber) async {
  if (idNumber.trim().isEmpty) {
    _showErrorMessage('Please enter an ID number');
    return;
  }

  final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);

  try {
    final validationError = visitorProvider.validateIdNumber(idNumber, _visitor?.idType ?? 'national_id');
    if (validationError != null) {
      _showErrorMessage(validationError);
      return;
    }
  } catch (e) {
    _showErrorMessage('Invalid ID number format');
    return;
  }

  if (!_formKey.currentState!.validate()) {
    _showErrorMessage('Please enter a valid ID number');
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _visitor = null;
  });

  try {
    if (visitorProvider.visitors.isEmpty) {
      await visitorProvider.loadCheckedInVisitors();
    }

    final visitors = visitorProvider.visitors;
    print('🔍 Searching for visitor with ID: $idNumber, Visitors count: ${visitors.length}');
    print('📋 Available visitors: ${visitors.map((v) => {'idNumber': v.idNumber, 'action': v.action}).toList()}');

    if (visitors.isEmpty) {
      _showErrorMessage('No checked-in visitors available. Please refresh and try again.');
      return;
    }

    final searchId = idNumber.trim().toUpperCase(); // Normalize input

    Visitor? visitor;
    try {
      visitor = visitors.firstWhere(
        (v) => v.idNumber?.toUpperCase() == searchId && v.action == 'checked in',
        orElse: () => throw Exception('Visitor not found'),
      );
    } catch (e) {
      _showErrorMessage('No checked-in visitor found with ID "$searchId"');
      print('⚠️ Visitor search failed: $e');
      return;
    }

    if (!_isValidVisitorData(visitor)) {
      _showErrorMessage('Visitor data is incomplete. Please contact administration.');
      return;
    }

    setState(() {
      _visitor = visitor;
      print('✅ Visitor found: ${visitor?.name}, ID: ${visitor?.idNumber}, Action: ${visitor?.action}');
    });

    _scrollToVisitorInfo();
  } catch (e) {
    String errorMsg = 'Error fetching visitor information';
    if (e.toString().contains('network') || e.toString().contains('connection')) {
      errorMsg = 'Network error. Please check your connection and try again.';
    } else if (e.toString().contains('timeout')) {
      errorMsg = 'Request timeout. Please try again.';
    }
    _showErrorMessage(errorMsg);
    print('❌ Error in _fetchVisitor: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  bool _isValidVisitorData(Visitor visitor) {
    return visitor.name.isNotEmpty && visitor.idNumber.isNotEmpty;
  }

  void _scrollToVisitorInfo() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _checkOutVisitor() async {
    if (_visitor == null) {
      _showErrorMessage('No visitor selected for checkout');
      return;
    }

    final shouldCheckOut = await _showCheckoutConfirmation();
    if (!shouldCheckOut) return;

    setState(() {
      _isCheckingOut = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
      final updatedVisitor = _createUpdatedVisitor();

      await visitorProvider.checkOutVisitor(updatedVisitor);

      _showSuccessMessage('${_visitor!.name} has been successfully checked out');

      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _clearForm();
        }
      });
    } catch (e) {
      String errorMsg = 'Failed to check out visitor';
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMsg = 'Network error. Please check connection and try again.';
      } else if (e.toString().contains('permission')) {
        errorMsg = 'Permission denied. Please contact administrator.';
      }
      _showErrorMessage(errorMsg);
    } finally {
      setState(() {
        _isCheckingOut = false;
      });
    }
  }

  Visitor _createUpdatedVisitor() {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    return Visitor(
      id: _visitor!.id,
      idType: _visitor!.idType,
      idNumber: _visitor!.idNumber,
      name: _visitor!.name,
      phoneNumber: _visitor!.phoneNumber,
      guardianPhone: _visitor!.guardianPhone,
      country: _visitor!.country,
      visitType: _visitor!.visitType,
      host: _visitor!.host,
      office: _visitor!.office,
      appointmentDetails: _visitor!.appointmentDetails,
      destinationId: _visitor!.destinationId,
      visitorTagId: _visitor!.visitorTagId,
      visitorGateId: _visitor!.visitorGateId,
      vehicleType: _visitor!.vehicleType,
      vehicleRegistration: _visitor!.vehicleRegistration,
      isMinor: _visitor!.isMinor,
      action: 'checked out',
      gate: visitorProvider.deviceGate ?? _visitor!.visitorGateId ?? 'Main Gate',
      time: DateTime.now(),
      createdAt: _visitor!.createdAt,
    );
  }

  Future<bool> _showCheckoutConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Confirm Check Out',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to check out:',
                style: GoogleFonts.lexend(fontSize: 14),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _visitor!.name,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'ID: ${_visitor!.idNumber}',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.lexend(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Check Out',
                style: GoogleFonts.lexend(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildVisitorInfoCard() {
    if (_visitor == null) return SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.symmetric(vertical: 16),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  AppColors.primaryBlue.withOpacity(0.03),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(),
                SizedBox(height: 24),
                _buildPersonalInfo(),
                if (_visitor!.host != null || _visitor!.office != null || _visitor!.visitType != null) ...[
                  SizedBox(height: 20),
                  _buildVisitInfo(),
                ],
                SizedBox(height: 20),
                _buildCheckoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.success.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.person_outline,
            color: AppColors.success,
            size: 28,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visitor Found',
                style: GoogleFonts.lexend(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              Text(
                'Ready for checkout',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CHECKED IN',
            style: GoogleFonts.lexend(
              fontSize: 12,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfo() {
    return _buildInfoSection(
      'Personal Information',
      Icons.person_outline,
      AppColors.primaryBlue,
      [
        _buildInfoRow('Name', _visitor!.name, Icons.person),
        _buildInfoRow('ID Number', _visitor!.idNumber, Icons.badge),
        _buildInfoRow('ID Type', _visitor!.idType.replaceAll('_', ' ').toUpperCase(), Icons.credit_card),
        if (_visitor!.phoneNumber != null && _visitor!.phoneNumber!.isNotEmpty)
          _buildInfoRow('Phone', _visitor!.phoneNumber!, Icons.phone),
        if (_visitor!.isMinor && _visitor!.guardianPhone != null && _visitor!.guardianPhone!.isNotEmpty)
          _buildInfoRow('Guardian Phone', _visitor!.guardianPhone!, Icons.phone),
        if (_visitor!.country != null && _visitor!.country!.isNotEmpty)
          _buildInfoRow('Country', _visitor!.country!, Icons.public),
      ],
    );
  }

Widget _buildVisitInfo() {
  final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
  final host = _visitor!.host != null
      ? (_visitor!.host is String
          ? (jsonDecode(_visitor!.host! as String) as Map?)?.cast<String, dynamic>()
          : _visitor!.host as Map<String, dynamic>?)
      : null;
  final office = _visitor!.office != null
      ? (_visitor!.office is String
          ? (jsonDecode(_visitor!.office! as String) as Map?)?.cast<String, dynamic>()
          : _visitor!.office as Map<String, dynamic>?)
      : null;
  final destination = visitorProvider.destinations.firstWhere(
    (dest) => dest['id']?.toString() == _visitor!.destinationId,
    orElse: () => {'id': 'unknown', 'name': 'Unknown'},
  );
  final tag = visitorProvider.visitorTags.firstWhere(
    (tag) => tag['id']?.toString() == _visitor!.visitorTagId,
    orElse: () => {'id': 'unknown', 'name': _visitor!.visitorTagId ?? 'Unknown'},
  );

  return _buildInfoSection(
    'Visit Information',
    Icons.business,
    AppColors.info,
    [
      if (host != null && host['name'] != null)
        _buildInfoRow('Host', host['name'].toString(), Icons.person_add),
      if (office != null && office['name'] != null)
        _buildInfoRow('Office', office['name'].toString(), Icons.business),
      _buildInfoRow('Visit Type', _visitor!.visitType?.toUpperCase() ?? 'Unknown', Icons.event),
      _buildInfoRow('Destination', destination['name']?.toString() ?? 'Unknown', Icons.location_on),
      _buildInfoRow('Visitor Tag', tag['name']?.toString() ?? 'Unknown', Icons.tag),
      _buildInfoRow('Gate', _visitor!.gate ?? _visitor!.visitorGateId ?? 'Unknown', Icons.door_front_door),
      _buildInfoRow('Check-in Time', _formatDateTime(_visitor!.time ?? DateTime.now()), Icons.access_time),
    ],
  );
}

  Widget _buildInfoSection(String title, IconData icon, Color color, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue.withOpacity(0.7), size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCheckingOut ? null : _checkOutVisitor,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isCheckingOut
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Checking Out...',
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Check Out Visitor',
                    style: GoogleFonts.lexend(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageCard(String message, Color color, IconData icon, bool isError) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _clearForm() {
    setState(() {
      _idNumberController.clear();
      _visitor = null;
      _errorMessage = null;
      _successMessage = null;
    });
    HapticFeedback.lightImpact();
    _animationController.reset();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Check Out Visitor',
        color: Colors.white,
        backgroundColor: AppColors.primaryBlue,
        showBackButton: true,
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check Out Visitor',
                  style: GoogleFonts.lexend(
                    fontSize: isSmallScreen ? 28 : 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Enter the visitor ID number to proceed with check-out.',
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Enter a valid ID number to search for checked-in visitors.',
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              color: AppColors.primaryBlue,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visitor ID Number',
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _idNumberController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Enter ID number (e.g., 123456)',
                            prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.error, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an ID number';
                            }
                            return visitorProvider.validateIdNumber(value, _visitor?.idType ?? 'national_id');
                          },
                          onFieldSubmitted: (value) {
                            if (!_isLoading && !visitorProvider.isLoading) {
                              _fetchVisitor(value);
                            }
                          },
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading || visitorProvider.isLoading
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        _fetchVisitor(_idNumberController.text);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                child: _isLoading || visitorProvider.isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Searching...',
                                            style: GoogleFonts.lexend(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Find Visitor',
                                            style: GoogleFonts.lexend(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isLoading || visitorProvider.isLoading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _clearForm();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.clear, size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: GoogleFonts.lexend(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  SizedBox(height: 16),
                if (_errorMessage != null)
                  _buildMessageCard(
                    _errorMessage!,
                    AppColors.error,
                    Icons.error_outline,
                    true,
                  ),
                if (_successMessage != null)
                  SizedBox(height: 16),
                if (_successMessage != null)
                  _buildMessageCard(
                    _successMessage!,
                    AppColors.success,
                    Icons.check_circle_outline,
                    false,
                  ),
                _buildVisitorInfoCard(),
                SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.security,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Secure Access System',
                              style: GoogleFonts.lexend(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Strathmore University',
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}