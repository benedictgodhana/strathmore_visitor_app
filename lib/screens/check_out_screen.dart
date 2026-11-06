import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';
const Color kPrimary = Color(0xFF0B3D91);
const Color kPrimaryLight = Color(0xFF1E5AA8);
const Color kPrimaryDark = Color(0xFF061E45);
const Color kGold = Color(0xFFB8860B);
const Color kGoldLight = Color(0xFFD4A72C);
const Color kSuccess = Color(0xFF047857);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);
const Color kSignalAmber = Color(0xFFFBBF24);
const _tabular = [FontFeature.tabularFigures()];
class CheckOutScreen extends StatefulWidget {
  @override
  _CheckOutScreenState createState() => _CheckOutScreenState();
}
class _CheckOutScreenState extends State<CheckOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late ConfettiController _confettiController;
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  bool _isCheckingOut = false;
  Visitor? _visitor;
  bool isDarkMode = false;
  String? deviceGate;
  Color get _bg => isDarkMode ? const Color(0xFF060B1A) : Colors.white;
  Color get _surface => isDarkMode ? const Color(0xFF0D1730) : Colors.white;
  Color get _tile => isDarkMode ? const Color(0xFF14213F) : const Color(0xFFE8EEFB);
  Color get _stroke => isDarkMode ? Colors.white.withOpacity(0.08) : kPrimary.withOpacity(0.10);
  Color get _text => isDarkMode ? const Color(0xFFF1F5FF) : kPrimaryDark;
  Color get _muted => isDarkMode ? const Color(0xFF8FA0C4) : const Color(0xFF5B6B85);
  Color get _accent => isDarkMode ? kGoldLight : kPrimary;
  Color get _ok => isDarkMode ? kSignalGreen : kSuccess;
  Color get _warn => isDarkMode ? kSignalAmber : kGold;
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadPreferences();
    _loadInitialData();
  }
  @override
  void dispose() {
    _idNumberController.dispose();
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      deviceGate = prefs.getString('device_gate') ?? 'Main Gate';
    });
  }
  void _toggleDarkMode() async {
    if (mounted) setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
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
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _errorMessage == message) {
        setState(() => _errorMessage = null);
      }
    });
  }
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
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
    if (!(_formKey.currentState?.validate() ?? false)) {
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
      if (mounted) setState(() => _isLoading = false);
    }
  }
  bool _isValidVisitorData(Visitor visitor) {
    return visitor.name.isNotEmpty &&
        (visitor.identificationNumber != null && visitor.identificationNumber!.isNotEmpty);
  }
  void _scrollToVisitorInfo() {
    Future.delayed(const Duration(milliseconds: 150), () {
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
      if (mounted) setState(() => _isCheckingOut = false);
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
              backgroundColor: _surface,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _warn.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.logout_rounded, color: _warn, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Confirm Check Out',
                    style: GoogleFonts.afacad(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _text,
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
                    style: GoogleFonts.afacad(fontSize: 16, color: _muted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _tile,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _visitor!.name,
                          style: GoogleFonts.afacad(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_visitor!.identificationNumber}',
                          style: GoogleFonts.afacad(
                            fontSize: 15,
                            color: _muted,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _warn,
                    foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Check Out',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }
  void _clearForm() {
    setState(() {
      _idNumberController.clear();
      _visitor = null;
      _errorMessage = null;
      _successMessage = null;
    });
    HapticFeedback.lightImpact();
  }
  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }
  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }
  Future<void> _logout() async {
    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    await visitorProvider.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('gate_id');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bg,
          drawer: _buildDrawer(),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [Colors.white, kPrimary, kPrimaryLight, kGold, kGoldLight],
                  numberOfParticles: 50,
                  gravity: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildDrawer() {
    Widget item(IconData i, String label, VoidCallback onTap) => ListTile(
      leading: Icon(i, color: Colors.white.withOpacity(0.9), size: 28),
      title: Text(
        label,
        style: GoogleFonts.afacad(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
    return Drawer(
      backgroundColor: kPrimaryDark,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.universityName,
                    style: GoogleFonts.afacad(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACCESS CONTROL',
                    style: GoogleFonts.afacad(
                      color: kGoldLight,
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            item(Icons.grid_view_rounded, 'Dashboard', _goHome),
            item(Icons.people_alt_outlined, 'All Visitors', () => _go('/visitor-list')),
            item(Icons.search_rounded, 'Search Records', () => _go('/visitor-search')),
            item(Icons.verified_user_outlined, 'Verify ID', () => _go('/lost-id-verification')),
            item(Icons.settings_outlined, 'Settings', () => _go('/settings')),
            const Spacer(),
            SwitchListTile(
              value: isDarkMode,
              onChanged: (_) => _toggleDarkMode(),
              activeColor: kGoldLight,
              secondary: const Icon(Icons.dark_mode_rounded, color: Colors.white70, size: 28),
              title: Text(
                'Dark mode',
                style: GoogleFonts.afacad(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            item(Icons.logout_rounded, 'Log out', _logout),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Open menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(Icons.grid_view_rounded, color: _text, size: 32),
          ),
          Text(
            'Check Out',
            style: GoogleFonts.afacad(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          IconButton(
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
            onPressed: _toggleDarkMode,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(isDarkMode),
                color: _text,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(),
        const SizedBox(height: 16),
        _buildSearchPanel(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard(_errorMessage!, kDanger, Icons.error_outline_rounded),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard(_successMessage!, _ok, Icons.check_circle_outline_rounded),
        ],
        if (_visitor != null) ...[
          const SizedBox(height: 20),
          _buildVisitorInfoPanel(),
        ],
        const SizedBox(height: 32),
        _buildComplianceFooter(),
      ],
    );
  }
  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check out visitor',
          style: GoogleFonts.afacad(
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Search by ID to securely end their visit.',
          style: GoogleFonts.afacad(fontSize: 18, color: _muted),
        ),
      ],
    );
  }
  Widget _buildSearchPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : kPrimaryDark.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.badge_rounded, color: _accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor ID',
                        style: GoogleFonts.afacad(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                      Text(
                        'Enter ID number to locate visitor',
                        style: GoogleFonts.afacad(fontSize: 16, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _idNumberController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.afacad(fontSize: 20, color: _text),
              decoration: InputDecoration(
                hintText: 'Enter ID number',
                hintStyle: GoogleFonts.afacad(color: _muted, fontSize: 18),
                prefixIcon: Icon(Icons.search_rounded, color: _accent, size: 28),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: _accent, width: 2),
                ),
                filled: true,
                fillColor: _tile.withOpacity(isDarkMode ? 0.7 : 0.55),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an ID number';
                }
                final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
                return visitorProvider.validateIdNumber(
                  value,
                  _visitor?.identificationType ?? 'national_id',
                );
              },
              onFieldSubmitted: (value) {
                if (!_isLoading) {
                  HapticFeedback.lightImpact();
                  _fetchVisitor(value);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _primaryAction(
                    icon: Icons.search_rounded,
                    label: _isLoading ? 'Searching…' : 'Find Visitor',
                    loading: _isLoading,
                    onTap: _isLoading
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _fetchVisitor(_idNumberController.text);
                          },
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : _clearForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    side: BorderSide(color: _stroke, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.clear_rounded, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Clear',
                        style: GoogleFonts.afacad(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _primaryAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: isDarkMode ? kPrimaryDark : Colors.white, size: 26),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.afacad(
                    color: isDarkMode ? kPrimaryDark : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildVisitorInfoPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _stroke, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : kPrimaryDark.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ok.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _ok.withOpacity(0.5), width: 2),
                ),
                child: Text(
                  _visitor!.name.isNotEmpty ? _visitor!.name[0].toUpperCase() : '?',
                  style: GoogleFonts.afacad(
                    color: _ok,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visitor Found',
                      style: GoogleFonts.afacad(
                        fontSize: 15,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _visitor!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.afacad(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _ok.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _ok.withOpacity(0.30)),
                ),
                child: Text(
                  'ON SITE',
                  style: GoogleFonts.afacad(
                    fontSize: 14,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: _ok,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: _stroke),
          const SizedBox(height: 20),
          _subHeader('Personal Information'),
          const SizedBox(height: 12),
          _infoRow('Name', _visitor!.name, Icons.person_rounded),
          _infoRow('ID Number', _visitor!.identificationNumber ?? '', Icons.badge_rounded),
          _infoRow(
            'ID Type',
            (_visitor!.identificationType ?? '').replaceAll('_', ' ').toUpperCase(),
            Icons.credit_card_rounded,
          ),
          if (_visitor!.phoneNumber.isNotEmpty)
            _infoRow('Phone', _visitor!.phoneNumber, Icons.phone_rounded),
          if (_visitor!.isMinor && _visitor!.guardianPhone != null && _visitor!.guardianPhone!.isNotEmpty)
            _infoRow('Guardian Phone', _visitor!.guardianPhone!, Icons.phone_rounded),
          if (_visitor!.vehicleType != null && _visitor!.vehicleType!.isNotEmpty)
            _infoRow('Vehicle', '${_visitor!.vehicleType} (${_visitor!.vehicleRegistration ?? "N/A"})', Icons.directions_car_rounded),
          if (_visitor!.host != null || _visitor!.officeDepartment != null || _visitor!.visitType != null) ...[
            const SizedBox(height: 20),
            _subHeader('Visit Information'),
            const SizedBox(height: 12),
            _buildVisitInfoRows(),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _isCheckingOut ? null : () {
                HapticFeedback.mediumImpact();
                _checkOutVisitor();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _warn,
                foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: _isCheckingOut
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.logout_rounded, size: 26),
              label: Text(
                _isCheckingOut ? 'Checking Out…' : 'Confirm Check Out',
                style: GoogleFonts.afacad(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildVisitInfoRows() {
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
    return Column(
      children: [
        _infoRow('Visit Type', _visitor!.visitType?.toUpperCase() ?? 'Unknown', Icons.event_rounded),
        _infoRow('Destination', destination['name']?.toString() ?? 'Unknown', Icons.location_on_rounded),
        _infoRow('Visitor Tag', tag['name']?.toString() ?? 'Unknown', Icons.tag_rounded),
        _infoRow('Gate', (_visitor!.gateId ?? 'Unknown').toString(), Icons.door_front_door_outlined),
        _infoRow('Check-in Time', _formatDateTime(_visitor!.checkInTime ?? DateTime.now()), Icons.access_time_rounded),
      ],
    );
  }
  Widget _subHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.afacad(
        fontSize: 15,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: _muted,
      ),
    );
  }
  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.afacad(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.afacad(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.30), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.afacad(
                fontSize: 17,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  Widget _buildComplianceFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security_rounded, size: 18, color: _muted),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Secure Access System · ${AppStrings.universityName}',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(fontSize: 15, color: _muted),
          ),
        ),
      ],
    );
  }
}