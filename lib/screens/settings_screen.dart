import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_bottom_nav.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool isDarkMode = false;
  bool _notificationsEnabled = true;
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  int _currentIndex = 4;
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ConfettiController _confettiController;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _loadSettings();
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

  Future<void> _loadSettings() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          isDarkMode = prefs.getBool('isDarkMode') ?? false;
          _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
          _userData = {
            'userName': prefs.getString('userName') ?? 'Not available',
            'email': prefs.getString('userEmail') ?? 'Not available',
            'phoneNumber': prefs.getString('userPhone') ?? 'Not available',
            'role': prefs.getString('userRole') ?? 'Not available',
            'position': prefs.getString('userPosition') ?? 'Not available',
            'gateId': prefs.getString('gate_id') ?? 'Not available',
            'deviceGate': prefs.getString('device_gate') ?? 'Not available',
            'avatarUrl': prefs.getString('userAvatarUrl'),
          };
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to load settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
      await prefs.setBool('notificationsEnabled', _notificationsEnabled);
      if (mounted) {
        _showSuccessMessage('Settings saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to save settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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

  void _toggleDarkMode() async {
    if (!mounted) return;
    setState(() {
      isDarkMode = !isDarkMode;
    });
    HapticFeedback.mediumImpact();
    await _saveSettings();
  }

  void _toggleNotifications() async {
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = !_notificationsEnabled;
    });
    HapticFeedback.mediumImpact();
    await _saveSettings();
  }

  Future<void> _logout() async {
    if (!mounted) return;

    final shouldLogout =
        await showDialog<bool>(
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
                    'Confirm Logout',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to log out?',
                style: GoogleFonts.afacad(
                  fontSize: 14,
                  color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                ),
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
                    'Logout',
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

    if (shouldLogout) {
      setState(() {
        _isLoading = true;
      });
      try {
        final visitorProvider = Provider.of<VisitorProvider>(
          context,
          listen: false,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userName');
        await prefs.remove('userEmail');
        await prefs.remove('userPhone');
        await prefs.remove('userRole');
        await prefs.remove('userPosition');
        await prefs.remove('gate_id');
        await prefs.remove('device_gate');
        await prefs.remove('userAvatarUrl');
        await prefs.remove('token');
        await visitorProvider.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } catch (e) {
        String errorMsg = 'Logout failed: $e';
        if (e.toString().contains('401')) {
          errorMsg = 'Session expired. Please log in again.';
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
        }
        if (mounted) {
          _showErrorMessage(errorMsg);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
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

  Widget _buildSettingTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isSmallScreen,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            border:
                isDarkMode
                    ? Border.all(color: Color(0xFF475569), width: 1)
                    : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primaryBlue,
                size: isSmallScreen ? 20 : 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primaryBlue,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSmallScreen,
    Color? buttonColor,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor ?? AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isSmallScreen ? 18 : 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            border:
                isDarkMode
                    ? Border.all(color: Color(0xFF475569), width: 1)
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Profile',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : AppColors.primaryBlue,
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Semantics(
                  label: 'User avatar',
                  child: CircleAvatar(
                    radius: isSmallScreen ? 40 : 50,
                    backgroundColor: AppColors.primaryBlue,
                    backgroundImage:
                        _userData?['avatarUrl'] != null
                            ? NetworkImage(_userData!['avatarUrl'])
                            : null,
                    child:
                        _userData?['avatarUrl'] == null
                            ? Icon(
                              Icons.person,
                              size: isSmallScreen ? 40 : 50,
                              color: Colors.white,
                            )
                            : null,
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildProfileField(
                label: 'Name',
                value: _userData?['userName'] ?? 'Not available',
                icon: Icons.person_outline,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Email',
                value: _userData?['email'] ?? 'Not available',
                icon: Icons.email_outlined,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Phone Number',
                value: _userData?['phoneNumber'] ?? 'Not available',
                icon: Icons.phone_outlined,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Role',
                value: _userData?['role'] ?? 'Not available',
                icon: Icons.admin_panel_settings_outlined,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Position',
                value: _userData?['position'] ?? 'Not available',
                icon: Icons.work_outline,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Gate ID',
                value: _userData?['gateId'] ?? 'Not available',
                icon: Icons.confirmation_number_outlined,
                isSmallScreen: isSmallScreen,
              ),
              SizedBox(height: 12),
              _buildProfileField(
                label: 'Device Gate',
                value: _userData?['deviceGate'] ?? 'Not available',
                icon: Icons.door_front_door_outlined,
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
    required bool isSmallScreen,
  }) {
    return Semantics(
      label: 'User $label',
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryBlue,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.afacad(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onBottomNavTap(int index) {
    if (!mounted) return;
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
        break;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF0A0E21) : Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Settings',
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showBackButton: true,
        showNotifications: true,
        showAccount: true,
        showLogout: true,
        notificationCount: visitorProvider.visitors.length,
        onLogoutTap: _logout,
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
                              'Settings',
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
                              'Customize your app preferences.',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null)
                          _buildMessageCard(
                            _errorMessage!,
                            AppColors.error,
                            Icons.error_outline,
                            true,
                            isSmallScreen,
                          ),
                        if (_successMessage != null)
                          _buildMessageCard(
                            _successMessage!,
                            Colors.green,
                            Icons.check_circle_outline,
                            false,
                            isSmallScreen,
                          ),
                        SizedBox(height: 16),
                        _buildProfileSection(isSmallScreen),
                        SizedBox(height: 16),
                        _buildSettingTile(
                          title: 'Dark Mode',
                          icon:
                              isDarkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                          value: isDarkMode,
                          onChanged: (value) => _toggleDarkMode(),
                          isSmallScreen: isSmallScreen,
                        ),
                        _buildSettingTile(
                          title: 'Notifications',
                          icon: Icons.notifications_outlined,
                          value: _notificationsEnabled,
                          onChanged: (value) => _toggleNotifications(),
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: 24),
                        _buildActionButton(
                          title: 'Save Settings',
                          icon: Icons.save,
                          onPressed: _saveSettings,
                          isSmallScreen: isSmallScreen,
                        ),
                        _buildActionButton(
                          title: 'Logout',
                          icon: Icons.logout,
                          onPressed: _logout,
                          isSmallScreen: isSmallScreen,
                          buttonColor: AppColors.warning,
                        ),
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
        isLoading: _isLoading,
        isDarkMode: isDarkMode,
        children: const <Widget>[],
      ),
    );
  }
}
