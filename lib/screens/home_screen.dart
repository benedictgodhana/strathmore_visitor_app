import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
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
  int todaysTotalCount = 0;
  int currentlyIn = 0;
  int checkedOutToday = 0;
  bool isDarkMode = false;
  String selectedTimeRange = 'Today';
  String? deviceGate;
  String? gateId;
  String? _token;
  bool _isRefreshing = false;
  double _scrollOffset = 0;
  
  // Animation delays
  final List<double> _delays = [0.1, 0.2, 0.3, 0.4, 0.5];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
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
    debugPrint(
      _token != null
          ? '✅ Loaded auth token: ${_token!.substring(0, 10)}...'
          : '⚠️ No auth token found',
    );
    debugPrint(
      gateId != null ? '✅ Loaded gateId: $gateId' : '⚠️ No gateId found',
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: AppStrings.universityName,
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount: Provider.of<VisitorProvider>(context).visitors.length,
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
            // Animated Gradient Header
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 300 + (_scrollOffset * 0.5).clamp(0.0, 120.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.secondaryBlue,
                    const Color(0xFF1E3A8A),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
            // Background Pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/pattern.png'),
                      repeat: ImageRepeat.repeat,
                    ),
                  ),
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
                  Colors.purple,
                ],
                numberOfParticles: 50,
                gravity: 0.2,
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
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: const SizedBox(height: 70)),
                    SliverToBoxAdapter(child: _buildGateHeader(isSmallScreen)),
                    SliverToBoxAdapter(
                      child: _buildTimeRangeSelector(isSmallScreen),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                        vertical: 24,
                      ),
                      sliver: _isRefreshing
                          ? SliverToBoxAdapter(
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 1.1,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => FadeInUp(
                                  delay: Duration(milliseconds: (200 * index).toInt()),
                                  child: _buildModernStatCard(
                                    index == 0
                                        ? 'Today\'s Total'
                                        : index == 1
                                        ? 'Currently In'
                                        : 'Checked Out Today',
                                    index == 0
                                        ? todaysTotalCount.toString()
                                        : index == 1
                                        ? currentlyIn.toString()
                                        : checkedOutToday.toString(),
                                    index == 0
                                        ? Icons.people_alt_rounded
                                        : index == 1
                                        ? Icons.person_pin_circle_rounded
                                        : Icons.logout_rounded,
                                    index == 0
                                        ? const Color(0xFF10B981)
                                        : index == 1
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFEF4444),
                                    isSmallScreen,
                                    index == 0 ? '+12%' : '',
                                    index == 0,
                                  ),
                                ),
                                childCount: 3,
                              ),
                            ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 24 : 32,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 22 : 26,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'BrandonGrotesque',
                                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '5 available',
                                style: TextStyle(
                                  fontSize: 12,
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final actions = [
                              {
                                'title': 'New Visitor',
                                'subtitle': 'Register a new visitor',
                                'icon': Icons.person_add_alt_1_rounded,
                                'color': const Color(0xFF10B981),
                                'route': '/visitor-registration',
                              },
                              {
                                'title': 'Check Out',
                                'subtitle': 'Complete a visit',
                                'icon': Icons.logout_rounded,
                                'color': const Color(0xFFF59E0B),
                                'route': '/check-out',
                              },
                              {
                                'title': 'Verify ID',
                                'subtitle': 'Student verification',
                                'icon': Icons.verified_user_rounded,
                                'color': const Color(0xFF3B82F6),
                                'route': '/lost-id-verification',
                              },
                              {
                                'title': 'Search',
                                'subtitle': 'Find visitor records',
                                'icon': Icons.search_rounded,
                                'color': const Color(0xFFCC9C4A),
                                'route': '/visitor-search',
                              },
                              {
                                'title': 'Settings',
                                'subtitle': 'App preferences',
                                'icon': Icons.settings_rounded,
                                'color': const Color(0xFF8B5CF6),
                                'route': '/settings',
                              },
                            ];
                            return FadeInUp(
                              delay: Duration(milliseconds: (150 * index).toInt()),
                              child: _buildModernActionCard(
                                actions[index]['title'] as String,
                                actions[index]['subtitle'] as String,
                                actions[index]['icon'] as IconData,
                                actions[index]['color'] as Color,
                                actions[index]['route'] as String,
                                isSmallScreen,
                              ),
                            );
                          },
                          childCount: 5,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 24 : 32,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Visitors',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 22 : 26,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'BrandonGrotesque',
                                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/visitor-list');
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 16 : 20,
                                      vertical: isSmallScreen ? 8 : 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'View All',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'BrandonGrotesque',
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
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
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 400),
                          child: _token == null
                              ? _buildEmptyState()
                              : Consumer<VisitorProvider>(
                                  builder: (context, visitorProvider, child) {
                                    final recentVisitors = visitorProvider.visitors
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
                    ),
                    SliverToBoxAdapter(child: const SizedBox(height: 100)),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Not Authenticated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'BrandonGrotesque',
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please log in to view visitor information',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'BrandonGrotesque',
              color: isDarkMode ? Colors.grey : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: const Text(
                    'Go to Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'BrandonGrotesque',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateHeader(bool isSmallScreen) {
    return FadeInDown(
      child: Container(
        margin: EdgeInsets.all(isSmallScreen ? 16 : 24),
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: Icon(
                    Icons.location_on_rounded,
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
                        'Current Location',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          fontFamily: 'BrandonGrotesque',
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deviceGate ?? 'Main Gate',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontFamily: 'BrandonGrotesque',
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontFamily: 'BrandonGrotesque',
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Activity',
                      style: TextStyle(
                        fontFamily: 'BrandonGrotesque',
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$todaysTotalCount visitors',
                      style: TextStyle(
                        fontFamily: 'BrandonGrotesque',
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (todaysTotalCount / 50).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Daily goal: 50 visitors',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'BrandonGrotesque',
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(bool isSmallScreen) {
    final timeRanges = ['Today', 'This Week', 'This Month'];

    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: timeRanges.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
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
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                      )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  timeRanges[index],
                  style: TextStyle(
                    fontFamily: 'BrandonGrotesque',
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: -2,
            ),
          ],
          border: isDarkMode
              ? Border.all(color: const Color(0xFF334155), width: 1)
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 12,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trend,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'BrandonGrotesque',
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCount(
                  count: int.parse(count),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 32 : 36,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'BrandonGrotesque',
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontFamily: 'BrandonGrotesque',
                    color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
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
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: isDarkMode
                ? Border.all(color: const Color(0xFF334155), width: 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isSmallScreen ? 48 : 52,
                height: isSmallScreen ? 48 : 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 24 : 26,
                  color: color,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'BrandonGrotesque',
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  fontFamily: 'BrandonGrotesque',
                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent visitors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New visitors will appear here',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'BrandonGrotesque',
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: visitors.asMap().entries.map((entry) {
          final index = entry.key;
          final visitor = entry.value;
          return Column(
            children: [
              if (index > 0) Divider(height: 1, color: Colors.grey.shade200),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.secondaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  visitor.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'BrandonGrotesque',
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Check-in: ${visitor.checkInTime?.format(context) ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'BrandonGrotesque',
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (visitor.checkOutTime != null)
                      Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Check-out: ${visitor.checkOutTime!.format(context)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'BrandonGrotesque',
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: visitor.checkOutTime == null
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    visitor.checkOutTime == null ? 'Active' : 'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'BrandonGrotesque',
                      color: visitor.checkOutTime == null
                          ? Colors.green
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/visitor-details',
                    arguments: visitor,
                  );
                },
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _scaleAnimation,
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

  Future<void> _loadGates() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _refreshData() async {
    if (_token == null || gateId == null || deviceGate == null) {
      debugPrint('⚠️ token, gateId, or deviceGate is null, cannot refresh data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Authentication token or gate information missing'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (_token == null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
      return;
    }

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
            content: const Text('Invalid authentication token. Please log in again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    try {
      await _loadGates();
      visitorProvider.setAuthData(_token!, gateId!, deviceGate ?? 'Gate A');
      await visitorProvider.loadCheckedInVisitors();
      await visitorProvider.logVisitCount(timeRange: selectedTimeRange);
      if (mounted) {
        setState(() {
          todaysTotalCount = visitorProvider.todaysTotalCount;
          currentlyIn = visitorProvider.checkedInCount;
          checkedOutToday = visitorProvider.checkedOutCount;
          _isRefreshing = false;
        });

        final prefs = await SharedPreferences.getInstance();
        if (todaysTotalCount >= (prefs.getInt('confettiThreshold') ?? 20)) {
          _confettiController.play();
        }
      }
    } catch (e) {
      debugPrint('❌ Error refreshing data: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        String errorMessage = 'Failed to refresh data: $e';
        if (e.toString().contains('Status 401') ||
            e.toString().contains('Authentication failed')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('gate_id');
          setState(() {
            _token = null;
            gateId = null;
          });
          errorMessage = 'Session expired or invalid token. Please log in again.';
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  void _onBottomNavTap(int index) {
    final navRoutes = {
      0: null,
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

extension DateTimeExtension on DateTime? {
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = IntTween(
      begin: _previousCount,
      end: widget.count,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _previousCount = _animation.value;
      _controller.reset();
      _animation = IntTween(
        begin: _previousCount,
        end: widget.count,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward();
    }
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

// Add this class for fade-in animations
class FadeInUp extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeInUp({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class FadeInDown extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const FadeInDown({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}