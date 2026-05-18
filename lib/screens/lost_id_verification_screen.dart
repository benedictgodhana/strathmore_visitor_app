import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_bottom_nav.dart';
import '../providers/visitor_provider.dart';

class IdentityVerificationScreen extends StatefulWidget {
  @override
  _IdentityVerificationScreenState createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _staffNoController = TextEditingController();
  String _verificationType = 'student';
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  Map<String, dynamic>? _identityData;
  List<Map<String, dynamic>> _recentVerifications = [];
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ConfettiController _confettiController;
  int _currentIndex = 3; // Set to index for verification screen
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedData();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
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

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
        _verificationType = prefs.getString('verification_type') ?? 'student';
        _studentIdController.text = prefs.getString('last_student_id') ?? '';
        _usernameController.text = prefs.getString('last_username') ?? '';
        _staffNoController.text = prefs.getString('last_staff_no') ?? '';
      });
      await _loadRecentVerifications();
    } catch (e) {
      print('Error loading saved data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load saved data: $e',
            style: TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verification_type', _verificationType);
      if (_verificationType == 'student' &&
          _studentIdController.text.isNotEmpty) {
        await prefs.setString('last_student_id', _studentIdController.text);
      }
      if (_verificationType == 'username' &&
          _usernameController.text.isNotEmpty) {
        await prefs.setString('last_username', _usernameController.text);
      }
      if (_verificationType == 'staffNo' &&
          _staffNoController.text.isNotEmpty) {
        await prefs.setString('last_staff_no', _staffNoController.text);
      }
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _saveVerificationHistory(
    Map<String, dynamic> verificationData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      final newEntry = {
        'type': verificationData['type'],
        'id':
            verificationData['type'] == 'student'
                ? verificationData['studentId']
                : verificationData['staffNo'],
        'name': verificationData['name'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      historyList.insert(0, jsonEncode(newEntry));
      if (historyList.length > 10) {
        historyList.removeRange(10, historyList.length);
      }
      await prefs.setStringList('verification_history', historyList);
      await _loadRecentVerifications();
    } catch (e) {
      print('Error saving verification history: $e');
    }
  }

  Future<void> _loadRecentVerifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      setState(() {
        _recentVerifications =
            historyList.map((entry) {
              final decoded = jsonDecode(entry);
              return <String, dynamic>{
                'display':
                    '${decoded['type'].toString().capitalize()} ID: ${decoded['id']} (${decoded['name']})',
                'timestamp': decoded['timestamp'],
              };
            }).toList();
      });
    } catch (e) {
      print('Error loading recent verifications: $e');
    }
  }

  Future<void> _clearAllSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('verification_type');
      await prefs.remove('last_student_id');
      await prefs.remove('last_username');
      await prefs.remove('last_staff_no');
      await prefs.remove('verification_history');
      setState(() {
        _recentVerifications.clear();
        _clearForm();
      });
      HapticFeedback.mediumImpact();
      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All saved data cleared',
            style: TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      print('Error clearing saved data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to clear data: $e',
            style: TextStyle(fontFamily: 'BrandonGrotesque', color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _verifyIdentity() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
        _identityData = null;
      });

      try {
        await _saveData();
        final visitorProvider = Provider.of<VisitorProvider>(
          context,
          listen: false,
        );
        Map<String, dynamic> result;
        if (_verificationType == 'student') {
          result = await visitorProvider.verifyIdentity(
            studentId: _studentIdController.text,
          );
        } else if (_verificationType == 'username') {
          result = await visitorProvider.verifyIdentity(
            username: _usernameController.text,
          );
        } else {
          result = await visitorProvider.verifyIdentity(
            staffNo: _staffNoController.text,
          );
        }

        if (result['success']) {
          final identityData = {
            'type': result['type'],
            if (result['type'] == 'student') ...{
              'studentId': result['studentId'],
              'name': result['name'] ?? 'Unknown',
              'surname': result['surname'] ?? 'N/A',
              'otherNames': result['otherNames'] ?? 'N/A',
              'gender': result['gender'] ?? 'N/A',
              'dateOfBirth': result['dateOfBirth'] ?? 'N/A',
              'courses': result['courses'] ?? 'N/A',
              'faculties': result['faculties'] ?? 'N/A',
              'email': result['email'] ?? 'N/A',
              'mobileNo': result['mobileNo'] ?? 'N/A',
              'feeBalance': result['feeBalance'] ?? 'N/A',
              'status': result['status'] ?? 'Active',
              'idExpiry': result['idExpiry'] ?? 'N/A',
            } else ...{
              'username': result['username'] ?? 'N/A',
              'staffNo': result['staffNo'] ?? 'N/A',
              'name': result['name'] ?? 'Unknown',
              'department': result['department'] ?? 'N/A',
              'status': result['status'] ?? 'Active',
            },
          };

          setState(() {
            _identityData = identityData;
            _successMessage =
                result['message'] ??
                '${result['type'].toString().capitalize()} verified successfully';
          });

          HapticFeedback.mediumImpact();
          _confettiController.play();
          await _saveVerificationHistory(identityData);
        } else {
          setState(() {
            _errorMessage =
                result['message'] ??
                'Failed to verify ${_verificationType == 'student' ? 'student' : 'staff'}';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage =
              'Error verifying ${_verificationType == 'student' ? 'student ID' : 'staff'}: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearForm() {
    setState(() {
      _studentIdController.clear();
      _usernameController.clear();
      _staffNoController.clear();
      _identityData = null;
      _errorMessage = null;
      _successMessage = null;
    });
    HapticFeedback.selectionClick();
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
        Navigator.pushNamed(context, '/check-out');
        break;
      case 3:
        break; // Already on this screen
      case 4:
        Navigator.pushNamed(context, '/settings');
        break;
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _usernameController.dispose();
    _staffNoController.dispose();
    _animationController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF0A0E21) : Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(
        title: 'Identity Verification',
        color: Colors.white,
        backgroundColor: Colors.transparent,
        showBackButton: true,
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
                              'Verify Identity',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'BrandonGrotesque',
                                color:
                                    isDarkMode
                                        ? Colors.white
                                        : Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select the verification type and enter the appropriate details.',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'BrandonGrotesque',
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
                              _buildVerificationTypeSelector(isSmallScreen),
                              SizedBox(height: 24),
                              _buildInputForm(isSmallScreen),
                              if (_errorMessage != null) ...[
                                SizedBox(height: 16),
                                _buildErrorMessage(isSmallScreen),
                              ],
                              if (_successMessage != null) ...[
                                SizedBox(height: 16),
                                _buildSuccessMessage(isSmallScreen),
                              ],
                              _buildInfoCard(isSmallScreen),
                              _buildRecentVerifications(isSmallScreen),
                              SizedBox(height: 24),
                              Center(
                                child: Text(
                                  'For security use only • ${AppStrings.universityName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'BrandonGrotesque',
                                    color:
                                        isDarkMode
                                            ? Color(0xFF94A3B8)
                                            : Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
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

  Widget _buildVerificationTypeSelector(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(16),
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
      ),
      child: DropdownButtonFormField<String>(
        value: _verificationType,
        decoration: InputDecoration(
          labelText: 'Verification Type',
          labelStyle: TextStyle(
            fontFamily: 'BrandonGrotesque',
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDarkMode ? Color(0xFF334155) : Colors.grey[100],
        ),
        items: [
          DropdownMenuItem(
            value: 'student',
            child: Text(
              'Student ID',
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownMenuItem(
            value: 'username',
            child: Text(
              'Staff Username',
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownMenuItem(
            value: 'staffNo',
            child: Text(
              'Staff Number',
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _verificationType = value!;
            _clearForm();
          });
          HapticFeedback.selectionClick();
          _saveData();
        },
      ),
    );
  }

  Widget _buildInputForm(bool isSmallScreen) {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _verificationType == 'student'
                ? 'Student ID Number'
                : _verificationType == 'username'
                ? 'Staff Username'
                : 'Staff Number',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'BrandonGrotesque',
              color: isDarkMode ? Colors.white : Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 12),
          TextFormField(
            controller:
                _verificationType == 'student'
                    ? _studentIdController
                    : _verificationType == 'username'
                    ? _usernameController
                    : _staffNoController,
            keyboardType:
                _verificationType == 'student'
                    ? TextInputType.number
                    : TextInputType.text,
            decoration: InputDecoration(
              hintText:
                  _verificationType == 'student'
                      ? 'Enter 6 or 7-digit ID (e.g., 123456)'
                      : _verificationType == 'username'
                      ? 'Enter staff username'
                      : 'Enter staff number',
              hintStyle: TextStyle(fontFamily: 'BrandonGrotesque'),
              prefixIcon: Icon(
                _verificationType == 'student' ? Icons.badge : Icons.person,
                color: AppColors.primaryBlue,
              ),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.error, width: 2),
              ),
              filled: true,
              fillColor: isDarkMode ? Color(0xFF334155) : Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(
              fontFamily: 'BrandonGrotesque',
              fontSize: 16,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter ${_verificationType == 'student'
                    ? 'a student ID'
                    : _verificationType == 'username'
                    ? 'a username'
                    : 'a staff number'}';
              }
              if (_verificationType == 'student' &&
                  !RegExp(r'^\d{6,7}$').hasMatch(value)) {
                return 'Student ID must be 6 or 7 digits';
              }
              return null;
            },
            onChanged: (value) => _saveData(),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            HapticFeedback.mediumImpact();
                            _verifyIdentity();
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isLoading
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            'Verify ${_verificationType.capitalize()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'BrandonGrotesque',
                            ),
                          ),
                ),
              ),
              if (_identityData != null) ...[
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _clearForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'BrandonGrotesque',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                color: AppColors.error,
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _successMessage!,
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                color: Colors.green,
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isSmallScreen) {
    if (_identityData == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 20),
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
            isDarkMode ? Border.all(color: Color(0xFF334155), width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                '${_identityData!['type'].toString().capitalize()} Verified',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'BrandonGrotesque',
                  color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('Name:', _identityData!['name'], isSmallScreen),
          if (_identityData!['type'] == 'student') ...[
            _buildInfoRow(
              'Student ID:',
              _identityData!['studentId'],
              isSmallScreen,
            ),
            _buildInfoRow('Courses:', _identityData!['courses'], isSmallScreen),
            _buildInfoRow(
              'Faculties:',
              _identityData!['faculties'],
              isSmallScreen,
            ),
            _buildInfoRow('Status:', _identityData!['status'], isSmallScreen),
            _buildInfoRow(
              'ID Expiry:',
              _identityData!['idExpiry'],
              isSmallScreen,
            ),
          ] else ...[
            _buildInfoRow(
              'Username:',
              _identityData!['username'],
              isSmallScreen,
            ),
            _buildInfoRow(
              'Staff Number:',
              _identityData!['staffNo'],
              isSmallScreen,
            ),
            _buildInfoRow(
              'Department:',
              _identityData!['department'],
              isSmallScreen,
            ),
            _buildInfoRow('Status:', _identityData!['status'], isSmallScreen),
          ],
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(
                context,
                _identityData!['type'] == 'student'
                    ? _identityData!['studentId']
                    : _identityData!['staffNo'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
                color: isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontFamily: 'BrandonGrotesque',
                color: isDarkMode ? Colors.white : Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVerifications(bool isSmallScreen) {
    if (_recentVerifications.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 20),
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
            isDarkMode ? Border.all(color: Color(0xFF334155), width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Verifications',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'BrandonGrotesque',
                  color: isDarkMode ? Colors.white : Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _clearAllSavedData,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontFamily: 'BrandonGrotesque',
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._recentVerifications
              .take(5)
              .map(
                (verification) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: isSmallScreen ? 16 : 18,
                        color:
                            isDarkMode ? Color(0xFF94A3B8) : Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          verification['display'],
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            fontFamily: 'BrandonGrotesque',
                            color:
                                isDarkMode
                                    ? Color(0xFF94A3B8)
                                    : Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}