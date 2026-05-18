import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  int _currentIndex = 2;
  bool isDarkMode = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadDarkMode();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.fastOutSlowIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
    _slideController.forward();
    _scaleController.forward();
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
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
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
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _errorMessage == message) {
        setState(() => _errorMessage = null);
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _successMessage == message) {
        setState(() => _successMessage = null);
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
      final validationError = visitorProvider.validateIdNumber(
        idNumber,
        _visitor?.identificationType ?? 'national_id',
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
          (v) => v.identificationNumber?.toUpperCase() == searchId && v.checkInTime != null,
          orElse: () => throw Exception('Visitor not found'),
        );
      } catch (e) {
        _showErrorMessage('No checked-in visitor found with ID "$searchId"');
        return;
      }

      if (!_isValidVisitorData(visitor)) {
        _showErrorMessage('Visitor data is incomplete. Please contact administration.');
        return;
      }

      setState(() => _visitor = visitor);
      _animationController.reset();
      _animationController.forward();
      _scrollToVisitorInfo();
    } catch (e) {
      String errorMsg = 'Error fetching visitor information';
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMsg = 'Request timeout. Please try again.';
      }
      _showErrorMessage(errorMsg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValidVisitorData(Visitor visitor) {
    return (visitor.name != null && visitor.name!.isNotEmpty) &&
        (visitor.identificationNumber != null && visitor.identificationNumber!.isNotEmpty);
  }

  void _scrollToVisitorInfo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
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
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _clearForm();
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
      setState(() => _isCheckingOut = false);
    }
  }

  Visitor _createUpdatedVisitor() {
    return Visitor(
      id: _visitor!.id,
      identificationType: _visitor!.identificationType,
      identificationNumber: _visitor!.identificationNumber,
      name: _visitor!.name,
      phoneNumber: _visitor!.phoneNumber,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.logout, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Check Out',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF334155) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _visitor!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'ID: ${_visitor!.identificationNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                    style: TextStyle(
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
                    style: TextStyle(
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
    if (_visitor == null) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
              ],
              border: isDarkMode ? Border.all(color: const Color(0xFF334155), width: 1) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(isSmallScreen),
                const SizedBox(height: 24),
                _buildPersonalInfo(isSmallScreen),
                if (_visitor!.host != null ||
                    _visitor!.officeDepartment != null ||
                    _visitor!.visitType != null) ...[
                  const SizedBox(height: 20),
                  _buildVisitInfo(isSmallScreen),
                ],
                const SizedBox(height: 20),
                _buildCheckoutButton(isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.shade700],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.person_outline,
            color: Colors.white,
            size: isSmallScreen ? 24 : 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visitor Found',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready for checkout',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CHECKED IN',
            style: TextStyle(
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
        _buildInfoRow('ID Number', _visitor!.identificationNumber ?? '', Icons.badge, isSmallScreen),
        _buildInfoRow(
          'ID Type',
          (_visitor!.identificationType ?? '').replaceAll('_', ' ').toUpperCase(),
          Icons.credit_card,
          isSmallScreen,
        ),
        if (_visitor!.phoneNumber != null && _visitor!.phoneNumber!.isNotEmpty)
          _buildInfoRow('Phone', _visitor!.phoneNumber!, Icons.phone, isSmallScreen),
        if (_visitor!.isMinor && _visitor!.guardianPhone != null && _visitor!.guardianPhone!.isNotEmpty)
          _buildInfoRow('Guardian Phone', _visitor!.guardianPhone!, Icons.phone, isSmallScreen),
        if (_visitor!.vehicleType != null && _visitor!.vehicleType!.isNotEmpty)
          _buildInfoRow('Vehicle Type', _visitor!.vehicleType!, Icons.directions_car, isSmallScreen),
      ],
      isSmallScreen,
    );
  }

  Widget _buildVisitInfo(bool isSmallScreen) {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    final destination = visitorProvider.destinations.isNotEmpty
        ? visitorProvider.destinations.firstWhere(
            (dest) => dest['id']?.toString() == _visitor!.destinationId,
            orElse: () => {'id': 'unknown', 'name': 'Unknown'},
          )
        : {'id': 'unknown', 'name': 'Unknown'};
    final tag = visitorProvider.visitorTags.isNotEmpty
        ? visitorProvider.visitorTags.firstWhere(
            (tag) => tag['id']?.toString() == _visitor!.visitorTagId,
            orElse: () => {'id': 'unknown', 'name': _visitor!.visitorTagId ?? 'Unknown'},
          )
        : {'id': 'unknown', 'name': _visitor!.visitorTagId ?? 'Unknown'};

    return _buildInfoSection(
      'Visit Information',
      Icons.business,
      AppColors.info,
      [
        _buildInfoRow('Visit Type', _visitor!.visitType?.toUpperCase() ?? 'Unknown', Icons.event, isSmallScreen),
        _buildInfoRow('Destination', destination['name']?.toString() ?? 'Unknown', Icons.location_on, isSmallScreen),
        _buildInfoRow('Visitor Tag', tag['name']?.toString() ?? 'Unknown', Icons.tag, isSmallScreen),
        _buildInfoRow('Gate', (_visitor!.gateId ?? 'Unknown').toString(), Icons.door_front_door, isSmallScreen),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF334155) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: isDarkMode ? Border.all(color: const Color(0xFF475569), width: 1) : null,
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue.withOpacity(0.7), size: isSmallScreen ? 16 : 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isCheckingOut ? null : () {
          HapticFeedback.mediumImpact();
          _checkOutVisitor();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Checking Out...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Check Out Visitor',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageCard(String message, Color color, IconData icon, bool isError, bool isSmallScreen) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
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
    _animationController.forward();
  }

  void _toggleDarkMode() async {
    setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _onBottomNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.pushNamed(context, '/visitor-registration');
        break;
      case 2:
        break;
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
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final visitorProvider = Provider.of<VisitorProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        },
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDarkMode),
                color: Colors.white,
              ),
            ),
            onPressed: _toggleDarkMode,
          ),
        ],
        onBack: () => Navigator.pop(context),
        isDarkMode: isDarkMode,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          setState(() => _scrollOffset = notification.metrics.pixels);
          return false;
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 200 + (_scrollOffset * 0.3).clamp(0.0, 80.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.secondaryBlue, const Color(0xFF1E3A8A)],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: const BorderRadius.only(
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
                  Colors.pink,
                ],
                numberOfParticles: 50,
                gravity: 0.2,
              ),
            ),
            SafeArea(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: const SizedBox(height: 20)),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
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
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 28 : 32,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'BrandonGrotesque',
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter the visitor ID number to proceed with check-out',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                  fontFamily: 'BrandonGrotesque',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24, vertical: 24),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Info Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Enter a valid ID number to search for checked-in visitors',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        fontFamily: 'BrandonGrotesque',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Search Card
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                    isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Visitor ID Number',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'BrandonGrotesque',
                                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _idNumberController,
                                    keyboardType: TextInputType.text,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'Enter ID number (e.g., 123456 or passport)',
                                      hintStyle: TextStyle(
                                        color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                      prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: isDarkMode ? const Color(0xFF334155) : Colors.grey[100],
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter an ID number';
                                      }
                                      return visitorProvider.validateIdNumber(
                                        value,
                                        _visitor?.identificationType ?? 'national_id',
                                      );
                                    },
                                    onFieldSubmitted: (value) {
                                      if (!_isLoading && !visitorProvider.isLoading) {
                                        HapticFeedback.lightImpact();
                                        _fetchVisitor(value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primaryBlue.withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _isLoading || visitorProvider.isLoading
                                                ? null
                                                : () {
                                                    HapticFeedback.mediumImpact();
                                                    _fetchVisitor(_idNumberController.text);
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
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
                                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Text(
                                                        'Searching...',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: const [
                                                      Icon(Icons.search, size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Find Visitor',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton(
                                        onPressed: _isLoading || visitorProvider.isLoading ? null : _clearForm,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDarkMode ? Colors.white : AppColors.primaryBlue,
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                          side: BorderSide(color: AppColors.primaryBlue),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.clear, size: 18),
                                            SizedBox(width: 4),
                                            Text('Clear'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_errorMessage != null) const SizedBox(height: 16),
                            if (_errorMessage != null) _buildMessageCard(
                              _errorMessage!,
                              AppColors.error,
                              Icons.error_outline,
                              true,
                              isSmallScreen,
                            ),
                            if (_successMessage != null) const SizedBox(height: 16),
                            if (_successMessage != null) _buildMessageCard(
                              _successMessage!,
                              Colors.green,
                              Icons.check_circle_outline,
                              false,
                              isSmallScreen,
                            ),
                            _buildVisitorInfoCard(isSmallScreen),
                            const SizedBox(height: 32),
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.security,
                                          size: 16,
                                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Secure Access System',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'BrandonGrotesque',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppStrings.universityName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      fontFamily: 'BrandonGrotesque',
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
                  SliverToBoxAdapter(child: const SizedBox(height: 100)),
                ],
              ),
            ),
          ],
        ),
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