import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedGate;
  bool _isLoading = false;
  bool _isGateLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGates().then((_) => _loadCachedGate());
    });
  }

  Future<void> _loadCachedGate() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedGate = prefs.getString('deviceGate');
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );

    if (cachedGate != null && cachedGate.isNotEmpty) {
      if (visitorProvider.gates.any((gate) => gate['name'] == cachedGate)) {
        if (mounted) {
          setState(() {
            _selectedGate = cachedGate;
          });
          print('📴 Loaded cached gate: $_selectedGate');
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedGate = visitorProvider.gates.isNotEmpty
                ? visitorProvider.gates.first['name']
                : null;
          });
          print('⚠️ Cached gate $cachedGate not found, reset to $_selectedGate');
        }
      }
    }
  }

  Future<void> _loadGates() async {
    if (mounted) {
      setState(() {
        _isGateLoading = true;
      });
    }
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    try {
      await visitorProvider.loadGates();
      if (visitorProvider.gates.isNotEmpty && mounted) {
        setState(() {
          if (_selectedGate == null ||
              !visitorProvider.gates.any(
                (gate) => gate['name'] == _selectedGate,
              )) {
            _selectedGate =
                visitorProvider.gates.first['name'] ?? 'Default Gate';
          }
        });
        print(
          '✅ Loaded ${visitorProvider.gates.length} gates: ${visitorProvider.gates}',
        );
        print('Gate map: ${visitorProvider.gateMap}');
      } else {
        print('⚠️ No gates available from API');
        if (mounted) {
          showToast('No gates available. Please try again.', backgroundColor: AppColors.error);
        }
      }
    } catch (e) {
      print('❌ Error loading gates: $e');
      if (mounted) {
        showToast('Failed to load gates: $e', backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGateLoading = false;
        });
      }
    }
  }

  Future<void> _saveGateToPreferences(String gateId, String deviceGate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gateId', gateId);
    await prefs.setString('deviceGate', deviceGate);
    print('📴 Saved gate to preferences: ID=$gateId, Name=$deviceGate');
  }

  void _showErrorAlert(String message, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Login Error',
          style: GoogleFonts.afacad(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.afacad(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.afacad(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(
                'Retry',
                style: GoogleFonts.afacad(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void showToast(String message, {Color? backgroundColor}) {
    if (mounted) {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: backgroundColor ?? AppColors.error,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    try {
      await visitorProvider.logout();

      if (visitorProvider.gateMap == null || visitorProvider.gateMap!.isEmpty) {
        print('⚠️ Gate map not loaded, attempting to reload gates');
        await _loadGates();
        if (visitorProvider.gateMap == null ||
            visitorProvider.gateMap!.isEmpty) {
          throw Exception('No valid gates available');
        }
      }

      if (_selectedGate == null ||
          !visitorProvider.gateMap!.containsKey(_selectedGate)) {
        if (mounted) {
          setState(() {
            _selectedGate =
                visitorProvider.gates.first['name'] ?? 'Default Gate';
          });
        }
      }

      final gateId =
          visitorProvider.gateMap![_selectedGate] ??
          (visitorProvider.gates.isNotEmpty
              ? visitorProvider.gates.first['id'] ?? '1'
              : '1');
      final gateName =
          _selectedGate ??
          visitorProvider.gates.first['name'] ??
          'Default Gate';

      print(
        '🔍 Attempting login with Username: ${_usernameController.text.trim()}, Gate: $gateName (ID: $gateId)',
      );

      await _saveGateToPreferences(gateId, gateName);
      await visitorProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        gateId,
        gateName,
      );

      print('✅ Login successful, navigating to home');
      showToast('Login successful!', backgroundColor: AppColors.primaryBlue);
      _passwordController.text = '';
      _usernameController.text = '';
      await _secureStorage.delete(key: 'password');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      String errorMessage;
      print('❌ Login failed: $e');
      switch (e.toString()) {
        case 'Exception: Invalid username or password':
          errorMessage = 'The username or password is incorrect.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: Invalid gate ID format':
          errorMessage = 'Invalid gate ID format. Please select a valid gate.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: Selected gate is invalid or inactive.':
          errorMessage = 'Selected gate is invalid or inactive.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: You are not authorized to access this gate.':
          errorMessage = 'You are not authorized to access this gate.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: No valid gates available':
          errorMessage = 'No valid gates available. Please try again.';
          _showErrorAlert(
            errorMessage,
            onRetry: _login,
          );
          break;
        case 'Exception: Request timed out. Please check your network connection.':
          errorMessage =
              'Request timed out. Please check your network connection.';
          _showErrorAlert(
            errorMessage,
            onRetry: _login,
          );
          break;
        case 'Exception: Invalid response format from server':
          errorMessage =
              'Server returned an invalid response. Please try again.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: Invalid response from server: Missing token or user data':
          errorMessage =
              'Server error: Missing required data. Please try again.';
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        case 'Exception: Session expired. Please log in again.':
          errorMessage = 'Session expired. Please try logging in again.';
          await visitorProvider.logout();
          showToast(errorMessage, backgroundColor: AppColors.error);
          break;
        default:
          errorMessage =
              'Login failed: ${e.toString().replaceFirst('Exception: ', '')}';
          showToast(errorMessage, backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.text = '';
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final visitorProvider = Provider.of<VisitorProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(color: Colors.white),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
                    width: isSmallScreen ? double.infinity : 450,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/strathmore_logo.png',
                            height: isSmallScreen ? 150 : 200,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'VISITOR MANAGEMENT',
                            style: GoogleFonts.afacad(
                              fontSize: isSmallScreen ? 24 : 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: GoogleFonts.afacad(
                                color: Colors.grey.shade600,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: AppColors.primaryBlue,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your username';
                              }
                              if (value.contains('<') || value.contains('>')) {
                                return 'Invalid characters in username';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.afacad(
                                color: Colors.grey.shade600,
                              ),
                              prefixIcon: Icon(
                                Icons.lock,
                                color: AppColors.primaryBlue,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: AppColors.primaryBlue,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  }
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedGate != null &&
                                    visitorProvider.gates.any(
                                      (gate) => gate['name'] == _selectedGate,
                                    )
                                ? _selectedGate
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Select Gate',
                              labelStyle: GoogleFonts.afacad(
                                color: Colors.grey.shade600,
                              ),
                              prefixIcon: Icon(
                                Icons.door_front_door,
                                color: AppColors.primaryBlue,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            items: _isGateLoading
                                ? [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        'Loading gates...',
                                        style: GoogleFonts.afacad(),
                                      ),
                                      enabled: false,
                                    ),
                                  ]
                                : visitorProvider.gates.isEmpty
                                    ? [
                                        DropdownMenuItem(
                                          value: 'Default Gate',
                                          child: Text(
                                            'Default Gate',
                                            style: GoogleFonts.afacad(),
                                          ),
                                        ),
                                      ]
                                    : visitorProvider.gates.map((gate) {
                                        final gateName =
                                            gate['name'] ?? 'Unknown Gate';
                                        return DropdownMenuItem<String>(
                                          value: gateName,
                                          child: Text(
                                            gateName,
                                            style: GoogleFonts.afacad(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                            onChanged: _isGateLoading
                                ? null
                                : (value) {
                                    if (mounted) {
                                      setState(() {
                                        _selectedGate = value;
                                        final gateId =
                                            visitorProvider.gateMap![value] ??
                                                '1';
                                        print(
                                          '✅ Selected gate: Name=$value, ID=$gateId',
                                        );
                                        _saveGateToPreferences(
                                          gateId,
                                          value!,
                                        );
                                      });
                                    }
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a gate';
                              }
                              if (visitorProvider.gateMap != null &&
                                  !visitorProvider.gateMap!.containsKey(
                                    value,
                                  )) {
                                return 'Invalid gate selected';
                              }
                              return null;
                            },
                            hint: Text(
                              'Select a gate',
                              style: GoogleFonts.afacad(),
                            ),
                          ),
                          if (visitorProvider.gates.isEmpty &&
                              !_isGateLoading) ...[
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadGates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Retry Loading Gates',
                                style: GoogleFonts.afacad(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.afacad(
                                  fontSize: 14,
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          _isLoading
                              ? CircularProgressIndicator(
                                  color: AppColors.primaryBlue,
                                  strokeWidth: 3,
                                )
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryBlue,
                                          AppColors.primaryBlue.withOpacity(0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 40 : 60,
                                        vertical: 16,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Login',
                                        style: GoogleFonts.afacad(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}