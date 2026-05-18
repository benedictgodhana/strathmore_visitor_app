import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fabAnimation;
  late ConfettiController _confettiController;
  int _currentIndex = 0;
  bool _isDarkMode = false;
  double _scrollOffset = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _deviceGate;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.position.pixels;
      });
    });

    _initializeAnimations();
    _loadUserPreferences();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

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

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
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

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _slideController.forward();
    _fabAnimationController.forward();
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
              style: const TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
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
            borderRadius: BorderRadius.zero,
          ),
          backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          elevation: 8,
          contentPadding: const EdgeInsets.all(24),
          title: Text(
            'Session Expired',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'BrandonGrotesque',
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
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'BrandonGrotesque',
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
                style: TextStyle(
                  fontFamily: 'BrandonGrotesque',
                  color: _isDarkMode ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    fontFamily: 'BrandonGrotesque',
                    fontWeight: FontWeight.w600,
                  ),
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
    _fabAnimationController.dispose();
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
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(_isDarkMode),
                color: Colors.white,
              ),
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
            height: 200 + (_scrollOffset * 0.3).clamp(0.0, 80.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryBlue, AppColors.secondaryBlue, const Color(0xFF1E3A8A)],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.zero,
                bottomRight: Radius.zero,
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
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.zero,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by name or ID number',
                              hintStyle: TextStyle(
                                fontFamily: 'BrandonGrotesque',
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: 'BrandonGrotesque',
                              fontSize: 16,
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
                    ),
                    sliver: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Checked-in Visitors',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 26,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'BrandonGrotesque',
                                  color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Text(
                                  '${filteredVisitors.length} visitors',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'BrandonGrotesque',
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                child: ScaleTransition(
                                  scale: _fabAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                          _isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.zero,
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
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'BrandonGrotesque',
                                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Visitors will appear here when they check in',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'BrandonGrotesque',
                                            color: _isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                                            ),
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              _loadCheckedInVisitors();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.zero,
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Refresh',
                                              style: TextStyle(
                                                fontFamily: 'BrandonGrotesque',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _buildVisitorCard(visitor, visitorProvider, isSmallScreen),
                                        ),
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
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _confettiController.play();
              Navigator.pushNamed(context, '/visitor-registration');
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildVisitorCard(Visitor visitor, VisitorProvider provider, bool isSmallScreen) {
    final statusColor = visitor.checkOutTime != null ? Colors.green : const Color(0xFFF59E0B);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                _isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: -2,
              ),
            ],
            border: _isDarkMode ? Border.all(color: const Color(0xFF334155), width: 1) : null,
          ),
          child: Row(
            children: [
              Container(
                width: isSmallScreen ? 50 : 54,
                height: isSmallScreen ? 50 : 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: statusColor,
                  size: isSmallScreen ? 24 : 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.name ?? 'Unknown Visitor',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'BrandonGrotesque',
                        color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.badge, size: 14, color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'ID: ${visitor.identificationNumber ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontFamily: 'BrandonGrotesque',
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business_center, size: 14, color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          visitTypeLabel,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontFamily: 'BrandonGrotesque',
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.event, size: 14, color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          visitor.hadAppointment == true ? 'Has Appointment' : 'No Appointment',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontFamily: 'BrandonGrotesque',
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Check-in: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            fontFamily: 'BrandonGrotesque',
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
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
                          gradient: LinearGradient(
                            colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.1)],
                          ),
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
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'BrandonGrotesque',
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
                        gradient: LinearGradient(
                          colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Checked Out',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'BrandonGrotesque',
                              color: Colors.green,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        visitor.name ?? 'Unknown Visitor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'BrandonGrotesque',
                          color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailSection('Personal Information', _isDarkMode, [
                  _buildDetailRow('ID Number', visitor.identificationNumber ?? 'N/A', _isDarkMode),
                  _buildDetailRow('ID Type', (visitor.identificationType ?? '').replaceAll('_', ' ').toUpperCase(), _isDarkMode),
                  _buildDetailRow('Phone', visitor.phoneNumber ?? 'N/A', _isDarkMode),
                  _buildDetailRow('Gender', visitor.gender ?? 'N/A', _isDarkMode),
                  if (visitor.isMinor == true)
                    _buildDetailRow('Guardian Phone', visitor.guardianPhone ?? 'N/A', _isDarkMode),
                ]),
                const SizedBox(height: 16),
                _buildDetailSection('Visit Information', _isDarkMode, [
                  _buildDetailRow('Destination', destinationName, _isDarkMode),
                  _buildDetailRow('Check-in Time', visitor.checkInTime?.format(context) ?? 'Not available', _isDarkMode),
                  _buildDetailRow('Check-out Time', visitor.checkOutTime?.format(context) ?? 'Not checked out', _isDarkMode),
                  _buildDetailRow('Host Type', visitor.visitType?.toUpperCase() ?? 'N/A', _isDarkMode),
                  _buildDetailRow('Appointment', visitor.hadAppointment == true ? 'Yes' : 'No', _isDarkMode),
                  if (visitor.appointmentDetails != null && visitor.appointmentDetails != 'N/A')
                    _buildDetailRow('Appointment Details', visitor.appointmentDetails ?? 'N/A', _isDarkMode),
                  if (visitor.remarks != null && visitor.remarks != 'N/A')
                    _buildDetailRow('Remarks', visitor.remarks ?? 'N/A', _isDarkMode),
                  if (visitor.vehicleType != null || visitor.vehicleRegistration != null)
                    _buildDetailRow('Vehicle', '${visitor.vehicleType ?? 'N/A'} (${visitor.vehicleRegistration ?? 'N/A'})', _isDarkMode),
                ]),
                if (visitor.host != null && visitor.host!['name'] != null && visitor.host!['name'] != 'N/A') ...[
                  const SizedBox(height: 16),
                  _buildDetailSection('Host Information', _isDarkMode, [
                    _buildDetailRow('Name', visitor.host!['name'] ?? 'N/A', _isDarkMode),
                    _buildDetailRow('Phone', visitor.host!['phone'] ?? 'N/A', _isDarkMode),
                    if (visitor.host!['email'] != null && visitor.host!['email'] != 'N/A')
                      _buildDetailRow('Email', visitor.host!['email'] ?? 'N/A', _isDarkMode),
                    if (visitor.host!['department'] != null && visitor.host!['department'] != 'N/A')
                      _buildDetailRow('Department', visitor.host!['department'] ?? 'N/A', _isDarkMode),
                    if (visitor.host!['position'] != null && visitor.host!['position'] != 'N/A')
                      _buildDetailRow('Position', visitor.host!['position'] ?? 'N/A', _isDarkMode),
                  ]),
                ],
                if (visitor.officeName != null && visitor.officeName != 'N/A') ...[
                  const SizedBox(height: 16),
                  _buildDetailSection('Office Information', _isDarkMode, [
                    _buildDetailRow('Office Name', visitor.officeName ?? 'N/A', _isDarkMode),
                    _buildDetailRow('Phone', visitor.officePhone ?? 'N/A', _isDarkMode),
                    if (visitor.officeEmail != null && visitor.officeEmail != 'N/A')
                      _buildDetailRow('Email', visitor.officeEmail ?? 'N/A', _isDarkMode),
                    if (visitor.officeDepartment != null && visitor.officeDepartment != 'N/A')
                      _buildDetailRow('Department', visitor.officeDepartment ?? 'N/A', _isDarkMode),
                    if (visitor.officeContactPerson != null && visitor.officeContactPerson != 'N/A')
                      _buildDetailRow('Contact Person', visitor.officeContactPerson ?? 'N/A', _isDarkMode),
                  ]),
                ],
                const SizedBox(height: 24),
                if (visitor.checkOutTime == null)
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showCheckoutConfirmation(visitor, provider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Check Out Visitor',
                          style: TextStyle(
                            fontFamily: 'BrandonGrotesque',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
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

  Widget _buildDetailSection(String title, bool isDarkMode, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF334155) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode ? Border.all(color: const Color(0xFF475569), width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'BrandonGrotesque',
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'BrandonGrotesque',
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'BrandonGrotesque',
              color: _isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, size: 48, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to check out ${visitor.name}?',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'BrandonGrotesque',
                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF334155) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'BrandonGrotesque',
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                style: TextStyle(
                  fontFamily: 'BrandonGrotesque',
                  color: _isDarkMode ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.redAccent],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await provider.checkOutVisitor(visitor);
                    _confettiController.play();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${visitor.name} checked out successfully',
                          style: const TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
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
                          style: const TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
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
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  'Check Out',
                  style: TextStyle(
                    fontFamily: 'BrandonGrotesque',
                    fontWeight: FontWeight.w600,
                  ),
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