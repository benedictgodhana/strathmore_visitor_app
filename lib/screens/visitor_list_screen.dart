import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_bottom_nav.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});

  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late AnimationController _dialogAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  bool _showFab = true;
  int _currentIndex = 0;
  bool _isDarkMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _deviceGate;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _showFab = _scrollController.position.pixels <= 100;
      });
    });

    _initializeAnimations();
    _loadUserPreferences();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCheckedInVisitors();
    });
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

    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _dialogAnimationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _deviceGate = prefs.getString('device_gate') ?? 'Main Gate';
    });
  }

  Future<void> _loadCheckedInVisitors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final gateId = prefs.getString('gate_id');

      if (token == null || gateId == null) {
        debugPrint('❌ No token or gateId found in SharedPreferences');
        _showAuthErrorDialog();
        return;
      }

      debugPrint('🔑 Using token: ${token.substring(0, 10)}... for loading checked-in visitors');

      final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
      visitorProvider.setAuthData(token, gateId, _deviceGate ?? 'Main Gate');
      await visitorProvider.loadCheckedInVisitors();

      if (visitorProvider.visitors.isNotEmpty) {
        _confettiController.play();
      }
    } catch (e) {
      debugPrint('❌ Error loading checked-in visitors: $e');
      if (e.toString().contains('Authentication failed') || e.toString().contains('unauthenticated')) {
        _showAuthErrorDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load checked-in visitors: ${e.toString()}',
              style: GoogleFonts.afacad(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showAuthErrorDialog() {
    _dialogAnimationController.forward();
    showDialog(
      context: context,
      builder: (context) => ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          elevation: 8,
          contentPadding: const EdgeInsets.all(24),
          title: Text(
            'Session Expired',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Your session has expired. Please log in again to continue.',
                style: GoogleFonts.afacad(
                  fontSize: 16,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.afacad(
                  color: _isDarkMode ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Log In',
                style: GoogleFonts.afacad(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => _dialogAnimationController.reset());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    _dialogAnimationController.dispose();
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitorProvider = Provider.of<VisitorProvider>(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    final filteredVisitors = _searchQuery.isEmpty
        ? visitorProvider.visitors
        : visitorProvider.visitors.where((visitor) {
            final name = visitor.name?.toLowerCase() ?? '';
            final id = visitor.identificationNumber?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || id.contains(_searchQuery);
          }).toList();

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0A0E21) : const Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Visitor Management',
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showBackButton: true,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount: visitorProvider.visitors.length,
        onLogoutTap: () async {
          await visitorProvider.logout();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('gate_id');
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadCheckedInVisitors();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleDarkMode,
          ),
        ],
        onBack: () => Navigator.pop(context),
        isDarkMode: _isDarkMode,
      ),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
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
              ],
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadCheckedInVisitors,
              color: Colors.white,
              backgroundColor: AppColors.primaryBlue,
              displacement: 80,
              edgeOffset: 20,
              triggerMode: RefreshIndicatorTriggerMode.anywhere,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                        vertical: 16,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or ID number',
                          hintStyle: GoogleFonts.afacad(
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                        style: GoogleFonts.afacad(
                          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 24,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            'Checked-in Visitors',
                            style: GoogleFonts.poppins(
                              fontSize: isSmallScreen ? 22 : 26,
                              fontWeight: FontWeight.w700,
                              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                            ),
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
                    sliver: visitorProvider.isLoading
                        ? const SliverToBoxAdapter(
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                              ),
                            ),
                          )
                        : filteredVisitors.isEmpty
                            ? SliverToBoxAdapter(
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 64,
                                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No checked-in visitors found',
                                        style: GoogleFonts.afacad(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          _loadCheckedInVisitors();
                                        },
                                        child: Text(
                                          'Refresh',
                                          style: GoogleFonts.afacad(
                                            color: AppColors.primaryBlue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final visitor = filteredVisitors[index];
                                    return FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: SlideTransition(
                                        position: _slideAnimation,
                                        child: _buildVisitorCard(visitor, visitorProvider, isSmallScreen),
                                      ),
                                    );
                                  },
                                  childCount: filteredVisitors.length,
                                ),
                              ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
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
        isDarkMode: _isDarkMode,
        children: const <Widget>[],
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showFab ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _confettiController.play();
              Navigator.pushNamed(context, '/visitor-registration');
            },
            backgroundColor: AppColors.primaryBlue,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVisitorCard(Visitor visitor, VisitorProvider provider, bool isSmallScreen) {
    final statusColor = visitor.checkOutTime != null ? Colors.green : Colors.orange;
    final visitTypeLabel = visitor.visitType == 'staff' ? 'Visiting Staff' : 'Visiting Office';
    final destinationName = provider.destinations.isNotEmpty
        ? provider.destinations.firstWhere(
            (dest) => dest['id'].toString() == visitor.destinationId.toString(),
            orElse: () => <String, String>{'name': 'Unknown'},
          )['name'] ?? 'Unknown'
        : 'Unknown';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showVisitorDetailsModal(visitor, provider);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -5,
              ),
            ],
            border: _isDarkMode ? Border.all(color: const Color(0xFF334155), width: 1) : null,
          ),
          child: Row(
            children: [
              Container(
                width: isSmallScreen ? 44 : 48,
                height: isSmallScreen ? 44 : 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: statusColor,
                  size: isSmallScreen ? 22 : 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name ?? 'Unknown Visitor',
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${visitor.identificationNumber ?? 'N/A'}',
                      style: GoogleFonts.afacad(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$visitTypeLabel • ${visitor.hadAppointment ?? 'No appointment'}',
                      style: GoogleFonts.afacad(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Checked in: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                      style: GoogleFonts.afacad(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    if (visitor.checkOutTime != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Checked out: ${visitor.checkOutTime?.format(context) ?? 'Not available'}',
                        style: GoogleFonts.afacad(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (visitor.checkOutTime == null)
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await _showCheckoutConfirmation(visitor, provider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Check Out',
                              style: GoogleFonts.afacad(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visitor.checkOutTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Checked Out',
                        style: GoogleFonts.afacad(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisitorDetailsModal(Visitor visitor, VisitorProvider provider) {
    final destinationName = provider.destinations.isNotEmpty
        ? provider.destinations.firstWhere(
            (dest) => dest['id'].toString() == visitor.destinationId.toString(),
            orElse: () => <String, String>{'name': 'Unknown'},
          )['name'] ?? 'Unknown'
        : 'Unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  visitor.name ?? 'Unknown Visitor',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('ID Number', visitor.identificationNumber ?? 'N/A', _isDarkMode),
                _buildDetailRow('Phone', visitor.phoneNumber ?? 'N/A', _isDarkMode),
                _buildDetailRow('Destination', destinationName, _isDarkMode),
                _buildDetailRow('Check-in Time', visitor.checkInTime?.format(context) ?? 'Not available', _isDarkMode),
                _buildDetailRow('Check-out Time', visitor.checkOutTime?.format(context) ?? 'Not checked out', _isDarkMode),
                _buildDetailRow('Host Type', visitor.visitType ?? 'N/A', _isDarkMode),
                _buildDetailRow('Appointment', visitor.hadAppointment ?? 'No appointment', _isDarkMode),
                if (visitor.vehicleType != null || visitor.vehicleRegistration != null)
                  _buildDetailRow(
                    'Vehicle',
                    '${visitor.vehicleType ?? 'N/A'} (${visitor.vehicleRegistration ?? 'N/A'})',
                    _isDarkMode,
                  ),
                if (visitor.isMinor == true)
                  _buildDetailRow('Guardian Phone', visitor.guardianPhone ?? 'N/A', _isDarkMode),
                if (visitor.host != null) ...[
                  _buildDetailRow('Host Name', visitor.host!['name'] ?? 'N/A', _isDarkMode),
                  _buildDetailRow('Host Phone', visitor.host!['phone'] ?? 'N/A', _isDarkMode),
                  if (visitor.host!['email'] != null)
                    _buildDetailRow('Host Email', visitor.host!['email'] ?? 'N/A', _isDarkMode),
                  if (visitor.host!['department'] != null)
                    _buildDetailRow('Host Department', visitor.host!['department'] ?? 'N/A', _isDarkMode),
                  if (visitor.host!['position'] != null)
                    _buildDetailRow('Host Position', visitor.host!['position'] ?? 'N/A', _isDarkMode),
                ],
                if (visitor.officeName != null) ...[
                  _buildDetailRow('Office Name', visitor.officeName ?? 'N/A', _isDarkMode),
                  _buildDetailRow('Office Phone', visitor.officePhone ?? 'N/A', _isDarkMode),
                  if (visitor.officeEmail != null)
                    _buildDetailRow('Office Email', visitor.officeEmail ?? 'N/A', _isDarkMode),
                  if (visitor.officeDepartment != null)
                    _buildDetailRow('Office Department', visitor.officeDepartment ?? 'N/A', _isDarkMode),
                  if (visitor.officeContactPerson != null)
                    _buildDetailRow('Office Contact', visitor.officeContactPerson ?? 'N/A', _isDarkMode),
                ],
                const SizedBox(height: 24),
                if (visitor.checkOutTime == null)
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _showCheckoutConfirmation(visitor, provider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                      ),
                      child: Text(
                        'Check Out Visitor',
                        style: GoogleFonts.afacad(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.afacad(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.afacad(
                fontSize: 14,
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckoutConfirmation(Visitor visitor, VisitorProvider provider) async {
    _dialogAnimationController.forward();
    return showDialog(
      context: context,
      builder: (context) => ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          elevation: 8,
          contentPadding: const EdgeInsets.all(24),
          title: Text(
            'Confirm Check Out',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to check out ${visitor.name}?',
                style: GoogleFonts.afacad(
                  fontSize: 16,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check-in time: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                style: GoogleFonts.afacad(
                  fontSize: 14,
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.afacad(
                  color: _isDarkMode ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  // Pass empty token since VisitorProvider fetches it internally
                  await provider.checkOutVisitor(visitor);
                  _confettiController.play();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${visitor.name} checked out successfully',
                        style: GoogleFonts.afacad(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('❌ Error checking out visitor: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to check out: ${e.toString()}',
                        style: GoogleFonts.afacad(color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Check Out',
                style: GoogleFonts.afacad(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() => _dialogAnimationController.reset());
  }

  void _toggleDarkMode() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
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
        Navigator.pushNamed(context, '/check-out');
        break;
      case 3:
        Navigator.pushNamed(context, '/lost-id-verification');
        break;
      case 4:
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }
}

extension on DateTime? {
  String format(BuildContext context) {
    if (this == null) return 'Not available';
    try {
      final localTime = this!.toLocal();
      final formatter = DateFormat('dd MMM yyyy, hh:mm a');
      return formatter.format(localTime);
    } catch (e) {
      debugPrint('❌ Error formatting date: $this, Error: $e');
      return 'Invalid date';
    }
  }
}