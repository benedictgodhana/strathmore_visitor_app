import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_bottom_nav.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';
import 'dart:convert';

class CheckOutScreen extends StatefulWidget {
  @override
  _CheckOutScreenState createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _scrollController = ScrollController();
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  bool _isCheckingOut = false;
  Visitor? _visitor;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ConfettiController _confettiController;
  int _currentIndex = 2; // Set to index for check-out screen
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _loadDarkMode();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.fastOutSlowIn),
    );
    _animationController.forward();
    _slideController.forward();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _loadInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final visitorProvider = Provider.of<VisitorProvider>(
          context,
          listen: false,
        );
        if (visitorProvider.visitors.isEmpty) {
          visitorProvider.loadCheckedInVisitors();
        }
      } catch (e) {
        _showErrorMessage('Failed to load initial data: $e');
      }
    });
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    _animationController.reset();
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
    _animationController.reset();
    _animationController.forward();
    _confettiController.play();
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

    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );

    try {
      final validationError = visitorProvider.validateIdNumber(
        idNumber,
        _visitor?. identificationType ?? 'national_id',
      );
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
      final searchId = idNumber.trim().toUpperCase();

      Visitor? visitor;
      try {
        visitor = visitors.firstWhere(
          (v) =>
              v.identificationNumber?.toUpperCase() == searchId && v.checkInTime != null,
          orElse: () => throw Exception('Visitor not found'),
        );
      } catch (e) {
        _showErrorMessage('No checked-in visitor found with ID "$searchId"');
        return;
      }

      if (!_isValidVisitorData(visitor)) {
        _showErrorMessage(
          'Visitor data is incomplete. Please contact administration.',
        );
        return;
      }

      setState(() {
        _visitor = visitor;
      });

      _animationController.reset();
      _animationController.forward();
      _scrollToVisitorInfo();
    } catch (e) {
      String errorMsg = 'Error fetching visitor information';
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Request timeout. Please try again.';
      }
      _showErrorMessage(errorMsg);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isValidVisitorData(Visitor visitor) {
    return (visitor.name != null && visitor.name!.isNotEmpty) &&
        (visitor.identificationNumber != null && visitor.identificationNumber!.isNotEmpty);
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
      final visitorProvider = Provider.of<VisitorProvider>(
        context,
        listen: false,
      );
      final updatedVisitor = _createUpdatedVisitor();
      await visitorProvider.checkOutVisitor(updatedVisitor);
      _showSuccessMessage(
        '${_visitor!.name} has been successfully checked out',
      );
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _clearForm();
        }
      });
    } catch (e) {
      String errorMsg = 'Failed to check out visitor';
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
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
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    return Visitor(
      id: _visitor!.id,
      identificationType: _visitor!.identificationType,
      identificationNumber: _visitor!.identificationNumber,
      name: _visitor!.name,
      phoneNumber: _visitor!.phoneNumber, // Fixed to use correct property name
      guardianPhone: _visitor!.guardianPhone,
      visitType: _visitor!.visitType,
      host: _visitor!.host,
      officeDepartment: _visitor!.officeDepartment,
      hadAppointment: _visitor!.hadAppointment,
      destinationId: _visitor!.destinationId,
      visitorTagId: _visitor!.visitorTagId,
      gateId: _visitor!.gateId,
      vehicleType: _visitor!.vehicleType,
      vehicleRegistration: _visitor!.vehicleRegistration,
      isMinor: _visitor!.isMinor,
      checkOutTime: DateTime.now(),
    );
  }

  Future<bool> _showCheckoutConfirmation() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: isDarkMode ? Color(0xFF1E293B) : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text(
                    'Confirm Check Out',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Color(0xFF0F172A),
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
                    style: GoogleFonts.afacad(
                      fontSize: 14,
                      color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Color(0xFF334155) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _visitor!.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color:
                                isDarkMode ? Colors.white : Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'ID: ${_visitor!.identificationNumber}',
                          style: GoogleFonts.afacad(
                            fontSize: 14,
                            color:
                                isDarkMode
                                    ? Color(0xFF94A3B8)
                                    : Color(0xFF64748B),
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
                    style: GoogleFonts.afacad(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'Check Out',
                    style: GoogleFonts.afacad(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildVisitorInfoCard(bool isSmallScreen) {
    if (_visitor == null) return SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 16),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
            border:
                isDarkMode
                    ? Border.all(color: Color(0xFF334155), width: 1)
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(isSmallScreen),
              SizedBox(height: 24),
              _buildPersonalInfo(isSmallScreen),
              if (_visitor!.host != null ||
                  _visitor!.officeDepartment != null ||
                  _visitor!.visitType != null) ...[
                SizedBox(height: 20),
                _buildVisitInfo(isSmallScreen),
              ],
              SizedBox(height: 20),
              _buildCheckoutButton(isSmallScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
          ),
          child: Icon(
            Icons.person_outline,
            color: Colors.green,
            size: isSmallScreen ? 24 : 28,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visitor Found',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                ),
              ),
              Text(
                'Ready for checkout',
                style: GoogleFonts.afacad(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CHECKED IN',
            style: GoogleFonts.afacad(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfo(bool isSmallScreen) {
    return _buildInfoSection(
      'Personal Information',
      Icons.person_outline,
      AppColors.primaryBlue,
      [
        _buildInfoRow('Name', _visitor!.name, Icons.person, isSmallScreen),
        _buildInfoRow(
          'ID Number',
          _visitor!.identificationNumber ?? '',
          Icons.badge,
          isSmallScreen,
        ),
        _buildInfoRow(
          'ID Type',
          (_visitor!.identificationType ?? '').replaceAll('_', ' ').toUpperCase(),
          Icons.credit_card,
          isSmallScreen,
        ),
        if (_visitor!.phoneNumber != null && _visitor!.phoneNumber!.isNotEmpty)
          _buildInfoRow(
            'Phone',
            _visitor!.phoneNumber!,
            Icons.phone,
            isSmallScreen,
          ),
        if (_visitor!.isMinor &&
            _visitor!.guardianPhone != null &&
            _visitor!.guardianPhone!.isNotEmpty)
          _buildInfoRow(
            'Guardian Phone',
            _visitor!.guardianPhone!,
            Icons.phone,
            isSmallScreen,
          ),
        if (_visitor!.vehicleType != null &&
            _visitor!.vehicleType!.isNotEmpty)
          _buildInfoRow(
            'Vehicle Type',
            _visitor!.vehicleType!,
            Icons.directions_car,
            isSmallScreen,
          ),
      ],
      isSmallScreen,
    );
  }

  Widget _buildVisitInfo(bool isSmallScreen) {
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    final host =
        _visitor!.host != null
            ? (_visitor!.host is String
                ? (jsonDecode(_visitor!.host! as String) as Map?)
                    ?.cast<String, dynamic>()
                : _visitor!.host as Map<String, dynamic>?)
            : null;
    final office =
        null;
    final destination =
        visitorProvider.destinations.isNotEmpty
            ? visitorProvider.destinations.firstWhere(
              (dest) => dest['id']?.toString() == _visitor!.destinationId,
              orElse: () => {'id': 'unknown', 'name': 'Unknown'},
            )
            : {'id': 'unknown', 'name': 'Unknown'};
    final tag =
        visitorProvider.visitorTags.isNotEmpty
            ? visitorProvider.visitorTags.firstWhere(
              (tag) => tag['id']?.toString() == _visitor!.visitorTagId,
              orElse:
                  () => {
                    'id': 'unknown',
                    'name': _visitor!.visitorTagId ?? 'Unknown',
                  },
            )
            : {'id': 'unknown', 'name': _visitor!.visitorTagId ?? 'Unknown'};

    return _buildInfoSection(
      'Visit Information',
      Icons.business,
      AppColors.info,
      [
        if (host != null && host['name'] != null)
          _buildInfoRow(
            'Host',
            host['name'].toString(),
            Icons.person_add,
            isSmallScreen,
          ),
        if (office != null && office['name'] != null)
          _buildInfoRow(
            'Office',
            office['name'].toString(),
            Icons.business,
            isSmallScreen,
          ),
        _buildInfoRow(
          'Visit Type',
          _visitor!.visitType?.toUpperCase() ?? 'Unknown',
          Icons.event,
          isSmallScreen,
        ),
        _buildInfoRow(
          'Destination',
          destination['name']?.toString() ?? 'Unknown',
          Icons.location_on,
          isSmallScreen,
        ),
        _buildInfoRow(
          'Visitor Tag',
          tag['name']?.toString() ?? 'Unknown',
          Icons.tag,
          isSmallScreen,
        ),
        _buildInfoRow(
          'Gate',
          (_visitor!.gateId ?? 'Unknown').toString(),
          Icons.door_front_door,
          isSmallScreen,
        ),
        _buildInfoRow(
          'Check-in Time',
          _formatDateTime(_visitor!.checkInTime ?? DateTime.now()),
          Icons.access_time,
          isSmallScreen,
        ),
      ],
      isSmallScreen,
    );
  }

  Widget _buildInfoSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> rows,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF334155) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border:
                isDarkMode
                    ? Border.all(color: Color(0xFF475569), width: 1)
                    : null,
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primaryBlue.withOpacity(0.7),
            size: isSmallScreen ? 16 : 18,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 14 : 15,
                    color: isDarkMode ? Colors.white : Color(0xFF0F172A),
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

  Widget _buildCheckoutButton(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            _isCheckingOut
                ? null
                : () {
                  HapticFeedback.mediumImpact();
                  _checkOutVisitor();
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child:
            _isCheckingOut
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
                      style: GoogleFonts.afacad(
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
                      style: GoogleFonts.afacad(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildMessageCard(
    String message,
    Color color,
    IconData icon,
    bool isError,
    bool isSmallScreen,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.afacad(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
    _animationController.forward();
  }

  void _toggleDarkMode() async {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.pushNamed(context, '/visitor-registration');
        break;
      case 2:
        break; // Already on this screen
      case 3:
        Navigator.pushNamed(context, '/lost-id-verification');
        break;
      case 4:
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final visitorProvider = Provider.of<VisitorProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF0A0E21) : Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Check Out Visitor',
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showBackButton: true,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount: visitorProvider.visitors.length,
        onLogoutTap: () async {
          await visitorProvider.logout();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        },
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleDarkMode,
          ),
        ],
        onBack: () => Navigator.pop(context),
        isDarkMode: isDarkMode,
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 500),
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.white,
                AppColors.primaryBlue,
                Colors.amber,
                Colors.green,
              ],
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Check Out Visitor',
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDarkMode
                                        ? Colors.white
                                        : Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Enter the visitor ID number to proceed with check-out.',
                              style: GoogleFonts.afacad(
                                fontSize: 14,
                                color:
                                    isDarkMode
                                        ? Color(0xFF94A3B8)
                                        : Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: 16,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? Color(0xFF1E293B)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDarkMode ? 0.2 : 0.1,
                                      ),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primaryBlue,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Enter a valid ID number to search for checked-in visitors.',
                                        style: GoogleFonts.afacad(
                                          fontSize: isSmallScreen ? 13 : 14,
                                          color:
                                              isDarkMode
                                                  ? Color(0xFF94A3B8)
                                                  : AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              Container(
                                padding: EdgeInsets.all(
                                  isSmallScreen ? 16 : 20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDarkMode
                                          ? Color(0xFF1E293B)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDarkMode ? 0.2 : 0.1,
                                      ),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visitor ID Number',
                                      style: GoogleFonts.poppins(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDarkMode
                                                ? Colors.white
                                                : Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      controller: _idNumberController,
                                      keyboardType: TextInputType.text,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Enter ID number (e.g., 123456)',
                                        prefixIcon: Icon(
                                          Icons.badge,
                                          color: AppColors.primaryBlue,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryBlue,
                                            width: 2,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.error,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor:
                                            isDarkMode
                                                ? Color(0xFF334155)
                                                : Colors.grey[100],
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter an ID number';
                                        }
                                        return visitorProvider.validateIdNumber(
                                          value,
                                          _visitor?.identificationType ?? 'national_id',
                                        );
                                      },
                                      onFieldSubmitted: (value) {
                                        if (!_isLoading &&
                                            !visitorProvider.isLoading) {
                                          HapticFeedback.lightImpact();
                                          _fetchVisitor(value);
                                        }
                                      },
                                    ),
                                    SizedBox(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed:
                                                _isLoading ||
                                                        visitorProvider
                                                            .isLoading
                                                    ? null
                                                    : () {
                                                      HapticFeedback.mediumImpact();
                                                      _fetchVisitor(
                                                        _idNumberController
                                                            .text,
                                                      );
                                                    },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryBlue,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 4,
                                            ),
                                            child:
                                                _isLoading ||
                                                        visitorProvider
                                                            .isLoading
                                                    ? Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                  Color
                                                                >(Colors.white),
                                                          ),
                                                        ),
                                                        SizedBox(width: 12),
                                                        Text(
                                                          'Searching...',
                                                          style:
                                                              GoogleFonts.afacad(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    )
                                                    : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.search,
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Find Visitor',
                                                          style:
                                                              GoogleFonts.afacad(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed:
                                              _isLoading ||
                                                      visitorProvider.isLoading
                                                  ? null
                                                  : _clearForm,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[600],
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              vertical: 16,
                                              horizontal: 20,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                                style: GoogleFonts.afacad(
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
                              if (_errorMessage != null) SizedBox(height: 16),
                              if (_errorMessage != null)
                                _buildMessageCard(
                                  _errorMessage!,
                                  AppColors.error,
                                  Icons.error_outline,
                                  true,
                                  isSmallScreen,
                                ),
                              if (_successMessage != null) SizedBox(height: 16),
                              if (_successMessage != null)
                                _buildMessageCard(
                                  _successMessage!,
                                  Colors.green,
                                  Icons.check_circle_outline,
                                  false,
                                  isSmallScreen,
                                ),
                              _buildVisitorInfoCard(isSmallScreen),
                              SizedBox(height: 32),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDarkMode
                                                ? Color(0xFF334155)
                                                : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.security,
                                            size: 16,
                                            color:
                                                isDarkMode
                                                    ? Color(0xFF94A3B8)
                                                    : Color(0xFF64748B),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Secure Access System',
                                            style: GoogleFonts.afacad(
                                              fontSize: 12,
                                              color:
                                                  isDarkMode
                                                      ? Color(0xFF94A3B8)
                                                      : Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      AppStrings.universityName,
                                      style: GoogleFonts.afacad(
                                        fontSize: 12,
                                        color:
                                            isDarkMode
                                                ? Color(0xFF94A3B8)
                                                : Color(0xFF64748B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        onNext: () {},
        onBack: () {},
        step: 0,
        isLoading: false,
        isDarkMode: isDarkMode,
        children: const <Widget>[],
      ),
    );
  }
}
