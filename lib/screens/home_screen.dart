import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Data
  int todaysVisitors = 0;
  int currentlyIn = 0;
  int totalVisitors = 0;
  int checkedOutToday = 0;
  bool isDarkMode = false;
  String selectedTimeRange = 'Today';
  String? deviceGate;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedGate = prefs.getString('deviceGate') ?? 'Main Gate';

    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      deviceGate = loadedGate;
    });

    print('🎯 Preferences Loaded — DeviceGate: $deviceGate');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final cardPadding = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: AppStrings.universityName,
        color: Colors.white,
        backgroundColor: AppColors.primaryBlue,
        showBackButton: false,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount: Provider.of<VisitorProvider>(context).visitors.length,
        onLogoutTap: () async {
          final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
          await visitorProvider.logout();
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        },
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: _toggleDarkMode,
          ),
        ], onBack: () {  },
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primaryBlue,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildWelcomeCard(cardPadding, isSmallScreen),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    _buildTimeRangeSelector(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildEnhancedStats(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    _buildSectionHeader('Quick Actions', isSmallScreen),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildMenuGrid(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        onNext: () {},
        onBack: () {},
        step: 0,
        isLoading: false,
        children: const <Widget>[],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildWelcomeCard(double cardPadding, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back!',
                      style: GoogleFonts.lexend(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${AppStrings.welcomeMessage} - ${deviceGate ?? "Main Gate"}',
                      style: GoogleFonts.lexend(
                        fontSize: isSmallScreen ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage your visitors efficiently',
                      style: GoogleFonts.lexend(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: isSmallScreen ? 35 : 45,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(bool isSmallScreen) {
    final timeRanges = ['Today', 'This Week', 'This Month'];

    return Container(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timeRanges.length,
        itemBuilder: (context, index) {
          final isSelected = timeRanges[index] == selectedTimeRange;
          return Padding(
            padding: EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTimeRange = timeRanges[index];
                    });
                    _refreshData();
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.primaryBlue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      timeRanges[index],
                      style: GoogleFonts.lexend(
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedStats(bool isSmallScreen) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Today\'s Visitors',
                todaysVisitors.toString(),
                Icons.people_rounded,
                AppColors.success,
                isSmallScreen,
                '+12%',
                true,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Currently In',
                currentlyIn.toString(),
                Icons.person_pin_circle_rounded,
                AppColors.warning,
                isSmallScreen,
                '',
                false,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Visitors',
                totalVisitors.toString(),
                Icons.groups_rounded,
                AppColors.primaryBlue,
                isSmallScreen,
                '+5%',
                true,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Checked Out Today',
                checkedOutToday.toString(),
                Icons.logout_rounded,
                AppColors.error,
                isSmallScreen,
                '',
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color,
      bool isSmallScreen, String trend, bool showTrend) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              if (showTrend && trend.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trend,
                    style: GoogleFonts.lexend(
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            count,
            style: GoogleFonts.lexend(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isSmallScreen) {
    return Text(
      title,
      style: GoogleFonts.lexend(
        fontSize: isSmallScreen ? 20 : 24,
        fontWeight: FontWeight.w700,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildMenuGrid(bool isSmallScreen) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: isSmallScreen ? 16 : 24,
      mainAxisSpacing: isSmallScreen ? 16 : 24,
      childAspectRatio: 1.1,
      children: [
        _buildMenuCard(
          context,
          'New Visitor',
          'Register a new visitor',
          Icons.person_add_alt_1_rounded,
          AppColors.success,
          '/visitor-registration',
          isSmallScreen,
        ),
        _buildMenuCard(
          context,
          'Check Out',
          'Check out visitor',
          Icons.logout_rounded,
          AppColors.warning,
          '/check-out',
          isSmallScreen,
        ),
        _buildMenuCard(
          context,
          'Student Verification',
          'Verify student identity',
          Icons.verified_user_rounded,
          AppColors.info,
          '/lost-id-verification',
          isSmallScreen,
        ),
        _buildMenuCard(
          context,
          'Settings',
          'App settings and preferences',
          Icons.settings_rounded,
          AppColors.error,
          '/settings',
          isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, String route, bool isSmallScreen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(25),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 30 : 35,
                  color: color,
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.lexend(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Container(
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        Navigator.pushNamed(context, '/visitor-registration');
      },
      backgroundColor: AppColors.primaryBlue,
      child: Icon(
        Icons.add,
        size: 28,
        color: Colors.white,
      ),
      elevation: 0,
    );
  }

  void _toggleDarkMode() async {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }
Future<void> _refreshData() async {
  final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);

  await visitorProvider.loadVisitors();
  await visitorProvider.logVisitCount();

  final now = DateTime.now();

  // Just use the server values directly from VisitorProvider
  setState(() {
    todaysVisitors = visitorProvider.todaysVisitCount;
    currentlyIn = visitorProvider.checkedInCount;
    checkedOutToday = visitorProvider.checkedOutCount;
    totalVisitors = visitorProvider.totalVisitCount;
  });

  final avg = totalVisitors ~/ 30;
  print('📊 Stats for $deviceGate on ${now.day}/${now.month}/${now.year} at ${now.hour}:${now.minute} EAT — '
      'Today: $todaysVisitors, Currently In: $currentlyIn, Checked Out Today: $checkedOutToday, '
      'Total: $totalVisitors, Avg/day: $avg');
}


  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
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