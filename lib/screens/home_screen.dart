import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_swipe/liquid_swipe.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_bottom_nav.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  final LiquidController _liquidController = LiquidController();
  final PageController _pageController = PageController();

  // Data
  int todaysVisitors = 0;
  int currentlyIn = 0;
  int totalVisitors = 0;
  int checkedOutToday = 0;
  bool isDarkMode = false;
  String selectedTimeRange = 'Today';
  String? deviceGate;
  String? gateId;
  String? _token; // Authentication token
  bool _isRefreshing = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserPreferences();
      await _loadTokenFromPreferences();
      if (_token == null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        await _refreshData();
      }
    });
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

    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
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

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedGate = prefs.getString('device_gate') ?? 'Main Gate';

    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
        deviceGate = loadedGate;
      });
    }
  }
 Future<void> _loadTokenFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      gateId = prefs.getString('gate_id');
      deviceGate = prefs.getString('device_gate') ?? 'Gate A';
    });
    debugPrint(_token != null ? '✅ Loaded auth token: $_token' : '⚠️ No auth token found');
    debugPrint(gateId != null ? '✅ Loaded gateId: $gateId' : '⚠️ No gateId found');
    debugPrint('📴 Loaded cached gate: $deviceGate');
    await _refreshData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: AppStrings.universityName,
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showBackButton: false,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount:
            Provider.of<VisitorProvider>(context).visitors.length,
        onLogoutTap: () async {
          final visitorProvider = Provider.of<VisitorProvider>(
            context,
            listen: false,
          );
          await visitorProvider.logout();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('gate_id');
          if (mounted) {
            setState(() {
              _token = null;
              gateId = null;
            });
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
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
        onBack: () {},
        isDarkMode: isDarkMode,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (mounted) {
            setState(() {
              _scrollOffset = notification.metrics.pixels;
            });
          }
          return false;
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 500),
              height: 280 + (_scrollOffset * 0.5).clamp(280.0, 400.0),
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
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.white,
                backgroundColor: AppColors.primaryBlue,
                displacement: 80,
                edgeOffset: 20,
                triggerMode: RefreshIndicatorTriggerMode.anywhere,
                child: CustomScrollView(
                  physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: 80)),
                    SliverToBoxAdapter(child: _buildGateHeader(isSmallScreen)),
                    SliverToBoxAdapter(
                      child: _buildTimeRangeSelector(isSmallScreen),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: isSmallScreen ? 16 : 24,
                        right: isSmallScreen ? 16 : 24,
                        top: 30,
                        bottom: 16,
                      ),
                      sliver:
                          _isRefreshing
                              ? SliverToBoxAdapter(
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                              : SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 1.1,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildModernStatCard(
                                    index == 0
                                        ? 'Today\'s Visitors'
                                        : index == 1
                                        ? 'Currently In'
                                        : index == 2
                                        ? 'Total Visitors'
                                        : 'Checked Out',
                                    index == 0
                                        ? todaysVisitors.toString()
                                        : index == 1
                                        ? currentlyIn.toString()
                                        : index == 2
                                        ? totalVisitors.toString()
                                        : checkedOutToday.toString(),
                                    index == 0
                                        ? Icons.people_alt_rounded
                                        : index == 1
                                        ? Icons.person_pin_circle_rounded
                                        : index == 2
                                        ? Icons.groups_rounded
                                        : Icons.logout_rounded,
                                    index == 0
                                        ? Color(0xFF10B981)
                                        : index == 1
                                        ? Color(0xFFF59E0B)
                                        : index == 2
                                        ? AppColors.primaryBlue
                                        : Color(0xFFEF4444),
                                    isSmallScreen,
                                    index == 0
                                        ? '+12%'
                                        : index == 2
                                        ? '+5%'
                                        : '',
                                    index == 0 || index == 2,
                                  ),
                                  childCount: 4,
                                ),
                              ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isSmallScreen ? 24 : 32,
                          top: 24,
                          bottom: 16,
                        ),
                        child: Text(
                          'Quick Actions',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 22 : 26,
                            fontWeight: FontWeight.w700,
                            color:
                                isDarkMode ? Colors.white : Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.3,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final actions = [
                            {
                              'title': 'New Visitor',
                              'subtitle': 'Register visitor',
                              'icon': Icons.person_add_alt_1_rounded,
                              'color': Color(0xFF10B981),
                              'route': '/visitor-registration',
                            },
                            {
                              'title': 'Check Out',
                              'subtitle': 'Complete visit',
                              'icon': Icons.logout_rounded,
                              'color': Color(0xFFF59E0B),
                              'route': '/check-out',
                            },
                            {
                              'title': 'Verify Student',
                              'subtitle': 'ID verification',
                              'icon': Icons.verified_user_rounded,
                              'color': Color(0xFF3B82F6),
                              'route': '/lost-id-verification',
                            },
                            {
                              'title': 'Settings',
                              'subtitle': 'App preferences',
                              'icon': Icons.settings_rounded,
                              'color': Color(0xFF8B5CF6),
                              'route': '/settings',
                            },
                          ];
                          return _buildModernActionCard(
                            actions[index]['title'] as String,
                            actions[index]['subtitle'] as String,
                            actions[index]['icon'] as IconData,
                            actions[index]['color'] as Color,
                            actions[index]['route'] as String,
                            isSmallScreen,
                          );
                        }, childCount: 4),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isSmallScreen ? 24 : 32,
                          top: 24,
                          bottom: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Visitors',
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 22 : 26,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDarkMode
                                        ? Colors.white
                                        : Color(0xFF0F172A),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/visitor-list');
                              },
                              child: Text(
                                'View All',
                                style: GoogleFonts.afacad(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                      ),
                      sliver: SliverToBoxAdapter(
                        child:
                            _token == null
                                ? Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color:
                                        isDarkMode
                                            ? Color(0xFF1E293B)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Please log in to view visitors',
                                        style: GoogleFonts.afacad(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            '/login',
                                            (route) => false,
                                          );
                                        },
                                        child: Text('Go to Login'),
                                      ),
                                    ],
                                  ),
                                )
                                : Consumer<VisitorProvider>(
                                  builder: (context, visitorProvider, child) {
                                    final recentVisitors =
                                        visitorProvider.visitors
                                            .where(
                                              (visitor) =>
                                                  visitor.gate == deviceGate ||
                                                  visitor.gateId == gateId,
                                            )
                                            .take(3)
                                            .toList();
                                    return _buildRecentVisitors(
                                      recentVisitors,
                                      isSmallScreen,
                                    );
                                  },
                                ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
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
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildGateHeader(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withOpacity(0.9),
            AppColors.secondaryBlue.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: isSmallScreen ? 24 : 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Location',
                      style: GoogleFonts.afacad(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      deviceGate ?? 'Main Gate',
                      style: GoogleFonts.afacad(
                        fontSize: isSmallScreen ? 22 : 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Online • ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.afacad(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: GoogleFonts.afacad(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$todaysVisitors visitors',
                    style: GoogleFonts.afacad(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: todaysVisitors / (todaysVisitors + 10).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(bool isSmallScreen) {
    final timeRanges = ['Today', 'This Week', 'This Month', 'Custom'];

    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: timeRanges.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = timeRanges[index] == selectedTimeRange;
          return GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  selectedTimeRange = timeRanges[index];
                });
              }
              _refreshData();
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  width: isSelected ? 0 : 1,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                        : [],
              ),
              child: Text(
                timeRanges[index],
                style: GoogleFonts.afacad(
                  color: isSelected ? AppColors.primaryBlue : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
    bool isSmallScreen,
    String trend,
    bool showTrend,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (title == 'Today\'s Visitors') {
            Navigator.pushNamed(context, '/visitor-list');
          }
        },
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 20,
                offset: Offset(0, 8),
                spreadRadius: -5,
              ),
            ],
            border:
                isDarkMode
                    ? Border.all(color: Color(0xFF334155), width: 1)
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isSmallScreen ? 22 : 26,
                    ),
                  ),
                  if (showTrend && trend.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 6),
                          Text(
                            trend,
                            style: GoogleFonts.afacad(
                              fontSize: 13,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCount(
                    count: int.parse(count),
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 30 : 34,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.afacad(
                      fontSize: isSmallScreen ? 14 : 15,
                      color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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

  Widget _buildModernActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String route,
    bool isSmallScreen,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pushNamed(context, route);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isSmallScreen ? 44 : 50,
                height: isSmallScreen ? 44 : 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.2), color.withOpacity(0.4)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: isSmallScreen ? 22 : 26, color: color),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.afacad(
                  fontSize: isSmallScreen ? 12 : 13,
                  color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentVisitors(List<Visitor> visitors, bool isSmallScreen) {
    if (visitors.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No recent visitors for $deviceGate',
              style: GoogleFonts.afacad(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children:
            visitors.map((visitor) {
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                title: Text(
                  visitor.name,
                  style: GoogleFonts.afacad(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitor.hadAppointment ?? 'No appointment',
                      style: GoogleFonts.afacad(
                        color:
                            isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Check-in: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                      style: GoogleFonts.afacad(
                        fontSize: 12,
                        color:
                            isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Check-out: ${visitor.checkOutTime?.format(context) ?? 'Not checked out'}',
                      style: GoogleFonts.afacad(
                        fontSize: 12,
                        color:
                            isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            visitor.checkOutTime == null
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        visitor.checkOutTime == null
                            ? 'Checked In'
                            : 'Checked Out',
                        style: GoogleFonts.afacad(
                          fontSize: 12,
                          color:
                              visitor.checkOutTime == null
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/visitor-details',
                    arguments: visitor,
                  );
                },
              );
            }).toList(),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
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
        child: Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }

  void _toggleDarkMode() async {
    if (mounted) {
      setState(() {
        isDarkMode = !isDarkMode;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  // Dummy implementation for _loadGates to resolve the error.
  Future<void> _loadGates() async {
    // TODO: Implement actual gate loading logic if needed.
    await Future.delayed(Duration(milliseconds: 100));
  }

 Future<void> _refreshData() async {
    // Check if token, gateId, or deviceGate is missing
    if (_token == null || gateId == null || deviceGate == null) {
      debugPrint('⚠️ token, gateId, or deviceGate is null, cannot refresh data');
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

    // Validate Sanctum token format (id|token)
    bool isValidTokenFormat(String token) {
      final parts = token.split('|');
      return parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;
    }

    if (_token != null && !isValidTokenFormat(_token!)) {
      debugPrint('⚠️ Invalid token format: $_token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('gate_id');
      if (mounted) {
        setState(() {
          _token = null;
          gateId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid authentication token. Please log in again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
      return;
    }

    if (!mounted) {
      debugPrint('⚠️ HomeScreen is not mounted, skipping refresh');
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
    try {
      await _loadGates();
      visitorProvider.setAuthData(_token!, gateId!, deviceGate ?? 'Gate A');
      await visitorProvider.loadCheckedInVisitors();
      await visitorProvider.logVisitCount();
      if (mounted) {
        setState(() {
          todaysVisitors = visitorProvider.todaysVisitCount;
          currentlyIn = visitorProvider.checkedInCount;
          checkedOutToday = visitorProvider.checkedOutCount;
          totalVisitors = visitorProvider.totalVisitCount;
          _isRefreshing = false;
        });

        final prefs = await SharedPreferences.getInstance();
        if (todaysVisitors >= (prefs.getInt('confettiThreshold') ?? 20)) {
          // Assume _confettiController.play() is defined
          // _confettiController.play();
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing data: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        String errorMessage = 'Failed to refresh data: $e';
        if (e.toString().contains('Status 401') || e.toString().contains('Authentication failed')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('gate_id');
          setState(() {
            _token = null;
            gateId = null;
          });
          errorMessage = 'Session expired or invalid token. Please log in again.';
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  

  }  void _onBottomNavTap(int index) {
    final navRoutes = {
      0: null, // Home
      1: '/visitor-registration',
      2: '/check-out',
      3: '/lost-id-verification',
      4: '/settings',
    };

    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }

    final route = navRoutes[index];
    if (route != null) {
      Navigator.pushNamed(context, route);
    }
  }
}

extension on LiquidController {
  void dispose() {
    // Assuming LiquidController handles its own disposal
  }
}

extension DateTimeExtension on DateTime? {
  String format(BuildContext context) {
    if (this == null) return 'Not available';
    try {
      final localTime = this!.toLocal(); // Convert to local time (EAT assumed)
      final formatter = DateFormat('dd MMM yyyy, hh:mm a');
      return formatter.format(localTime);
    } catch (e) {
      debugPrint('❌ Error formatting date: $this, Error: $e');
      return 'Invalid date';
    }
  }
}

class AnimatedCount extends StatefulWidget {
  final int count;
  final TextStyle? style;

  const AnimatedCount({required this.count, this.style});

  @override
  _AnimatedCountState createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = IntTween(
      begin: _previousCount,
      end: widget.count,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    if (oldWidget.count != widget.count) {
      _previousCount = _animation.value;
      _controller.reset();
      _animation = IntTween(
        begin: _previousCount,
        end: widget.count,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller.forward();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(_animation.value.toString(), style: widget.style);
      },
    );
  }
}
