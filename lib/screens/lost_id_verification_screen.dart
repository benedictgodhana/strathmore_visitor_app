import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../utils/constants.dart';
import '../providers/visitor_provider.dart';

const Color kPrimary = Color(0xFF0B3D91);
const Color kPrimaryLight = Color(0xFF1E5AA8);
const Color kPrimaryDark = Color(0xFF061E45);
const Color kGold = Color(0xFFB8860B);
const Color kGoldLight = Color(0xFFD4A72C);
const Color kSuccess = Color(0xFF047857);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);

class IdentityVerificationScreen extends StatefulWidget {
  @override
  _IdentityVerificationScreenState createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _staffNoController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _verificationType = 'student';
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  Map<String, dynamic>? _identityData;
  List<Map<String, dynamic>> _recentVerifications = [];
  late ConfettiController _confettiController;
  bool isDarkMode = false;
  String? deviceGate;

  // ── Theme tokens ─────────────────────────────────────────────────────────
  Color get _bg => isDarkMode ? const Color(0xFF060B1A) : Colors.white;
  Color get _surface => isDarkMode ? const Color(0xFF0D1730) : Colors.white;
  Color get _tile => isDarkMode ? const Color(0xFF14213F) : const Color(0xFFE8EEFB);
  Color get _stroke => isDarkMode ? Colors.white.withOpacity(0.08) : kPrimary.withOpacity(0.10);
  Color get _text => isDarkMode ? const Color(0xFFF1F5FF) : kPrimaryDark;
  Color get _muted => isDarkMode ? const Color(0xFF8FA0C4) : const Color(0xFF5B6B85);
  Color get _accent => isDarkMode ? kGoldLight : kPrimary;
  Color get _ok => isDarkMode ? kSignalGreen : kSuccess;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadSavedData();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _usernameController.dispose();
    _staffNoController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
        deviceGate = prefs.getString('device_gate') ?? 'Main Gate';
        _verificationType = prefs.getString('verification_type') ?? 'student';
        _studentIdController.text = prefs.getString('last_student_id') ?? '';
        _usernameController.text = prefs.getString('last_username') ?? '';
        _staffNoController.text = prefs.getString('last_staff_no') ?? '';
      });
      await _loadRecentVerifications();
    } catch (e) {
      _showError('Failed to load saved data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verification_type', _verificationType);
      if (_verificationType == 'student' && _studentIdController.text.isNotEmpty) {
        await prefs.setString('last_student_id', _studentIdController.text);
      }
      if (_verificationType == 'username' && _usernameController.text.isNotEmpty) {
        await prefs.setString('last_username', _usernameController.text);
      }
      if (_verificationType == 'staffNo' && _staffNoController.text.isNotEmpty) {
        await prefs.setString('last_staff_no', _staffNoController.text);
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  Future<void> _saveVerificationHistory(Map<String, dynamic> verificationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      final newEntry = {
        'type': verificationData['type'],
        'id': verificationData['type'] == 'student' ? verificationData['studentId'] : verificationData['staffNo'],
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
      debugPrint('Error saving verification history: $e');
    }
  }

  Future<void> _loadRecentVerifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      if (!mounted) return;
      setState(() {
        _recentVerifications = historyList.map((entry) {
          final decoded = jsonDecode(entry);
          return <String, dynamic>{
            'display': '${decoded['type'].toString().capitalize()} ID: ${decoded['id']} (${decoded['name']})',
            'timestamp': decoded['timestamp'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading recent verifications: $e');
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
      if (!mounted) return;
      setState(() {
        _recentVerifications.clear();
        _clearForm();
      });
      HapticFeedback.mediumImpact();
      _confettiController.play();
      _showSuccess('All saved data cleared');
    } catch (e) {
      _showError('Failed to clear data: $e');
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
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        Map<String, dynamic> result;
        if (_verificationType == 'student') {
          result = await visitorProvider.verifyIdentity(studentId: _studentIdController.text);
        } else if (_verificationType == 'username') {
          result = await visitorProvider.verifyIdentity(username: _usernameController.text);
        } else {
          result = await visitorProvider.verifyIdentity(staffNo: _staffNoController.text);
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

          if (!mounted) return;
          setState(() {
            _identityData = identityData;
            _successMessage = result['message'] ?? '${result['type'].toString().capitalize()} verified successfully';
          });

          HapticFeedback.mediumImpact();
          _confettiController.play();
          await _saveVerificationHistory(identityData);
        } else {
          if (!mounted) return;
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to verify ${_verificationType == 'student' ? 'student' : 'staff'}';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error verifying ${_verificationType == 'student' ? 'student ID' : 'staff'}: $e';
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
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

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    setState(() => _successMessage = msg);
  }

  void _toggleDarkMode() async {
    setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
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
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPageHeader(),
                              const SizedBox(height: 16),
                              _buildVerificationTypeSelector(),
                              const SizedBox(height: 16),
                              _buildInputForm(),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _buildMessageCard(_errorMessage!, kDanger, Icons.error_outline_rounded),
                              ],
                              if (_successMessage != null) ...[
                                const SizedBox(height: 16),
                                _buildMessageCard(_successMessage!, _ok, Icons.check_circle_outline_rounded),
                              ],
                              if (_identityData != null) ...[
                                const SizedBox(height: 20),
                                _buildInfoCard(),
                              ],
                              const SizedBox(height: 20),
                              _buildRecentVerifications(),
                              const SizedBox(height: 32),
                              Center(
                                child: Text(
                                  'For security use only • ${AppStrings.universityName}',
                                  style: GoogleFonts.afacad(fontSize: 15, color: _muted),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
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
        style: GoogleFonts.afacad(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
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
                    style: GoogleFonts.afacad(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACCESS CONTROL',
                    style: GoogleFonts.afacad(color: kGoldLight, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            item(Icons.grid_view_rounded, 'Dashboard', _goHome),
            item(Icons.people_alt_outlined, 'All Visitors', () => _go('/visitor-list')),
            item(Icons.search_rounded, 'Search Records', () => _go('/visitor-search')),
            item(Icons.exit_to_app_rounded, 'Check Out', () => _go('/check-out')),
            item(Icons.settings_outlined, 'Settings', () => _go('/settings')),
            const Spacer(),
            SwitchListTile(
              value: isDarkMode,
              onChanged: (_) => _toggleDarkMode(),
              activeColor: kGoldLight,
              secondary: const Icon(Icons.dark_mode_rounded, color: Colors.white70, size: 28),
              title: Text(
                'Dark mode',
                style: GoogleFonts.afacad(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600),
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
            'Verify ID',
            style: GoogleFonts.afacad(fontSize: 26, fontWeight: FontWeight.w800, color: _text),
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

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify Identity',
          style: GoogleFonts.afacad(fontSize: 36, height: 1.1, fontWeight: FontWeight.w800, color: _text),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the verification type and enter the appropriate details.',
          style: GoogleFonts.afacad(fontSize: 18, color: _muted),
        ),
      ],
    );
  }

  Widget _buildVerificationTypeSelector() {
    return Container(
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
      child: DropdownButtonFormField<String>(
        value: _verificationType,
        decoration: InputDecoration(
          labelText: 'Verification Type',
          labelStyle: GoogleFonts.afacad(fontSize: 18, color: _muted, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _accent, width: 2)),
          filled: true,
          fillColor: _tile.withOpacity(isDarkMode ? 0.7 : 0.55),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
        dropdownColor: _surface,
        borderRadius: BorderRadius.circular(20),
        style: GoogleFonts.afacad(fontSize: 19, fontWeight: FontWeight.w600, color: _text),
        items: [
          DropdownMenuItem(value: 'student', child: Text('Student ID', style: GoogleFonts.afacad(fontSize: 19, color: _text))),
          DropdownMenuItem(value: 'username', child: Text('Staff Username', style: GoogleFonts.afacad(fontSize: 19, color: _text))),
          DropdownMenuItem(value: 'staffNo', child: Text('Staff Number', style: GoogleFonts.afacad(fontSize: 19, color: _text))),
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

  Widget _buildInputForm() {
    return Container(
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
          Text(
            _verificationType == 'student'
                ? 'Student ID Number'
                : _verificationType == 'username'
                    ? 'Staff Username'
                    : 'Staff Number',
            style: GoogleFonts.afacad(fontSize: 20, fontWeight: FontWeight.w800, color: _text),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _verificationType == 'student'
                ? _studentIdController
                : _verificationType == 'username'
                    ? _usernameController
                    : _staffNoController,
            keyboardType: _verificationType == 'student' ? TextInputType.number : TextInputType.text,
            style: GoogleFonts.afacad(fontSize: 20, color: _text),
            decoration: InputDecoration(
              hintText: _verificationType == 'student'
                  ? 'Enter 6 or 7-digit ID (e.g., 123456)'
                  : _verificationType == 'username'
                      ? 'Enter staff username'
                      : 'Enter staff number',
              hintStyle: GoogleFonts.afacad(color: _muted, fontSize: 18),
              prefixIcon: Icon(
                _verificationType == 'student' ? Icons.badge_rounded : Icons.person_rounded,
                color: _accent,
                size: 28,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: _accent, width: 2)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: kDanger, width: 1.5)),
              filled: true,
              fillColor: _tile.withOpacity(isDarkMode ? 0.7 : 0.55),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter ${_verificationType == 'student'
                    ? 'a student ID'
                    : _verificationType == 'username'
                        ? 'a username'
                        : 'a staff number'}';
              }
              if (_verificationType == 'student' && !RegExp(r'^\d{6,7}$').hasMatch(value)) {
                return 'Student ID must be 6 or 7 digits';
              }
              return null;
            },
            onChanged: (value) => _saveData(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: _isLoading
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _verifyIdentity();
                            },
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              )
                            : Text(
                                'Verify ${_verificationType.capitalize()}',
                                style: GoogleFonts.afacad(color: isDarkMode ? kPrimaryDark : Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_identityData != null) ...[
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    side: BorderSide(color: _stroke, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.afacad(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
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
              style: GoogleFonts.afacad(color: color, fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _ok.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: _ok, size: 28),
              ),
              const SizedBox(width: 14),
              Text(
                '${_identityData!['type'].toString().capitalize()} Verified',
                style: GoogleFonts.afacad(fontSize: 24, fontWeight: FontWeight.w800, color: _text),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Name', _identityData!['name']),
          if (_identityData!['type'] == 'student') ...[
            _buildInfoRow('Student ID', _identityData!['studentId']),
            _buildInfoRow('Courses', _identityData!['courses']),
            _buildInfoRow('Faculties', _identityData!['faculties']),
            _buildInfoRow('Status', _identityData!['status']),
            _buildInfoRow('ID Expiry', _identityData!['idExpiry']),
          ] else ...[
            _buildInfoRow('Username', _identityData!['username']),
            _buildInfoRow('Staff Number', _identityData!['staffNo']),
            _buildInfoRow('Department', _identityData!['department']),
            _buildInfoRow('Status', _identityData!['status']),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 62,
            child: ElevatedButton(
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
                backgroundColor: _accent,
                foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: GoogleFonts.afacad(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.afacad(fontSize: 16, fontWeight: FontWeight.w600, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.afacad(fontSize: 17, fontWeight: FontWeight.w700, color: _text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVerifications() {
    if (_recentVerifications.isEmpty) return const SizedBox.shrink();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Verifications',
                style: GoogleFonts.afacad(fontSize: 20, fontWeight: FontWeight.w800, color: _text),
              ),
              TextButton(
                onPressed: _clearAllSavedData,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear All',
                  style: GoogleFonts.afacad(fontSize: 16, color: kDanger, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._recentVerifications.take(5).map(
            (verification) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 22, color: _muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      verification['display'],
                      style: GoogleFonts.afacad(fontSize: 16, color: _text),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}