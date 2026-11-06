import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';
import '../utils/brand_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
  final _secureStorage = const FlutterSecureStorage();

  // Store unique gate names to prevent duplicates
  List<String> _uniqueGateNames = [];
  Map<String, String> _gateIdMap = {};

  static const Color _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGates().then((_) => _loadCachedGate());
    });
  }

  // ── Logic (unchanged) ─────────────────────────────────────────────────────
  Future<void> _loadCachedGate() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedGate = prefs.getString('deviceGate');

    if (cachedGate != null && cachedGate.isNotEmpty) {
      if (_uniqueGateNames.contains(cachedGate)) {
        if (mounted) {
          setState(() {
            _selectedGate = cachedGate;
          });
          debugPrint('📴 Loaded cached gate: $_selectedGate');
        }
      } else {
        if (mounted && _uniqueGateNames.isNotEmpty) {
          setState(() {
            _selectedGate = _uniqueGateNames.first;
          });
          debugPrint(
            '⚠️ Cached gate $cachedGate not found, reset to $_selectedGate',
          );
        }
      }
    } else if (_uniqueGateNames.isNotEmpty && mounted) {
      setState(() {
        _selectedGate = _uniqueGateNames.first;
      });
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

      // Create unique gate names and mapping (prevents duplicates)
      final Map<String, String> tempMap = {};
      for (var gate in visitorProvider.gates) {
        final name = gate['name']?.toString().trim() ?? '';
        final id = gate['id']?.toString() ?? '';
        if (name.isNotEmpty && !tempMap.containsKey(name)) {
          tempMap[name] = id;
        }
      }

      _gateIdMap = tempMap;
      _uniqueGateNames = tempMap.keys.toList();

      // If no gates found, add default
      if (_uniqueGateNames.isEmpty) {
        _uniqueGateNames = ['Default Gate'];
        _gateIdMap = {'Default Gate': '1'};
      }

      if (mounted) {
        setState(() {
          if (_selectedGate == null ||
              !_uniqueGateNames.contains(_selectedGate)) {
            _selectedGate =
                _uniqueGateNames.isNotEmpty ? _uniqueGateNames.first : null;
          }
        });
        debugPrint(
          '✅ Loaded ${_uniqueGateNames.length} unique gates: $_uniqueGateNames',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading gates: $e');

      // Use default gate as fallback
      if (mounted && _uniqueGateNames.isEmpty) {
        setState(() {
          _uniqueGateNames = ['Default Gate'];
          _gateIdMap = {'Default Gate': '1'};
          _selectedGate = 'Default Gate';
        });

        const errorMessage = 'Failed to load gates. Using default gate.';
        showToast(errorMessage, backgroundColor: Colors.orange);
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
    debugPrint('📴 Saved gate to preferences: ID=$gateId, Name=$deviceGate');
  }

  void _showErrorAlert(String message, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                color: _muted,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.afacad(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
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
      debugPrint('❌ Form validation failed');
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

      // Ensure gates are loaded
      if (_uniqueGateNames.isEmpty) {
        await _loadGates();
      }

      // Get gate ID from the selected gate name
      final gateId = _gateIdMap[_selectedGate] ?? '1';
      final gateName = _selectedGate ?? 'Default Gate';

      debugPrint(
        '🔍 Attempting login with Username: ${_usernameController.text.trim()}, Gate: $gateName (ID: $gateId)',
      );

      await _saveGateToPreferences(gateId, gateName);
      await visitorProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        gateId,
        gateName,
      );

      debugPrint('✅ Login successful, navigating to home');
      showToast('Login successful!', backgroundColor: kPrimary);
      _passwordController.text = '';
      _usernameController.text = '';
      await _secureStorage.delete(key: 'password');

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      debugPrint('❌ Login failed: $e');

      String errorMessage;
      if (e.toString().contains('Invalid username or password')) {
        errorMessage = 'The username or password is incorrect.';
        showToast(errorMessage, backgroundColor: AppColors.error);
      } else if (e.toString().contains('No valid gates available')) {
        errorMessage = 'No valid gates available. Please try again.';
        _showErrorAlert(errorMessage, onRetry: _login);
      } else if (e.toString().contains('Request timed out')) {
        errorMessage =
            'Request timed out. Please check your network connection.';
        _showErrorAlert(errorMessage, onRetry: _login);
      } else {
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
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    // Scale the logo smoothly with screen width (responsive across phones,
    // tablets, and large tablets) instead of a single fixed breakpoint value.
    final logoHeight = (size.width * 0.20).clamp(100.0, 190.0).toDouble();

    final s = _Sizes(
      field: isTablet ? 18 : 16,
      label: isTablet ? 16 : 14,
      icon: isTablet ? 26 : 22,
      fieldPad: isTablet ? 20 : 17,
      button: isTablet ? 19 : 17,
    );
    final titleSize = isTablet ? 46.0 : 36.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kPrimary,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kPrimary, kPrimaryDark],
                  ),
                ),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _BlobPainter())),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 40 : 24,
                    vertical: 24,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo
                            Image.asset(
                              'assets/images/strathmore_logo.png',
                              height: logoHeight,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: isTablet ? 56 : 40),
                            Text(
                              'VISITOR MANAGEMENT',
                              style: GoogleFonts.afacad(
                                color: kGoldLight,
                                fontSize: isTablet ? 14 : 12.5,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hey,\nLet\'s Sign In!',
                              style: GoogleFonts.afacad(
                                color: Colors.white,
                                fontSize: titleSize,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: isTablet ? 36 : 28),
                            TextFormField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              cursorColor: Colors.white,
                              decoration: _decoration(
                                s,
                                'Username',
                                Icons.person_outline_rounded,
                              ),
                              style: GoogleFonts.afacad(
                                fontSize: s.field,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your username';
                                }
                                if (value.contains('<') ||
                                    value.contains('>')) {
                                  return 'Invalid characters in username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              cursorColor: Colors.white,
                              onFieldSubmitted: (_) {
                                if (!_isLoading) _login();
                              },
                              decoration: _decoration(
                                s,
                                'Password',
                                Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: s.icon,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    if (mounted) {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    }
                                  },
                                ),
                              ),
                              style: GoogleFonts.afacad(
                                fontSize: s.field,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value:
                                  _selectedGate != null &&
                                          _uniqueGateNames.contains(
                                            _selectedGate,
                                          )
                                      ? _selectedGate
                                      : (_uniqueGateNames.isNotEmpty
                                          ? _uniqueGateNames.first
                                          : null),
                              decoration: _decoration(
                                s,
                                'Select Gate',
                                Icons.door_front_door_outlined,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                                size: s.icon,
                              ),
                              dropdownColor: kPrimaryDark,
                              borderRadius: BorderRadius.zero,
                              style: GoogleFonts.afacad(
                                fontSize: s.field,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              items: _gateItems(),
                              onChanged:
                                  _isGateLoading
                                      ? null
                                      : (value) {
                                        if (mounted && value != null) {
                                          setState(() {
                                            _selectedGate = value;
                                            final gateId =
                                                _gateIdMap[value] ?? '1';
                                            debugPrint(
                                              '✅ Selected gate: Name=$value, ID=$gateId',
                                            );
                                            _saveGateToPreferences(
                                              gateId,
                                              value,
                                            );
                                          });
                                        }
                                      },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a gate';
                                }
                                return null;
                              },
                              hint: Text(
                                'Select a gate',
                                style: GoogleFonts.afacad(
                                  fontSize: s.field,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_uniqueGateNames.isEmpty &&
                                !_isGateLoading) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadGates,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'Retry Loading Gates',
                                  style: GoogleFonts.afacad(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.afacad(
                                    fontSize: s.label,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kGold,
                                  foregroundColor: kPrimaryDark,
                                  disabledBackgroundColor: kGold.withOpacity(
                                    0.6,
                                  ),
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: s.fieldPad,
                                  ),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: kPrimaryDark,
                                            strokeWidth: 3,
                                          ),
                                        )
                                        : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Login',
                                              style: GoogleFonts.afacad(
                                                fontSize: s.button,
                                                fontWeight: FontWeight.w800,
                                                color: kPrimaryDark,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                              color: kPrimaryDark,
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                            SizedBox(height: isTablet ? 36 : 28),
                            Center(
                              child: Text(
                                AppStrings.universityName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.afacad(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
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
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(
    _Sizes s,
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    OutlineInputBorder box(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.afacad(
        fontSize: s.field,
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, size: s.icon, color: Colors.white70),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.16),
      border: box(Colors.white.withOpacity(0.45)),
      enabledBorder: box(Colors.white.withOpacity(0.45)),
      focusedBorder: box(kGold, 2),
      errorBorder: box(kGoldLight),
      focusedErrorBorder: box(kGoldLight, 2),
      errorStyle: GoogleFonts.afacad(fontSize: 13, color: kGoldLight),
      contentPadding: EdgeInsets.symmetric(
        vertical: s.fieldPad,
        horizontal: 20,
      ),
    );
  }

  List<DropdownMenuItem<String>> _gateItems() {
    if (_isGateLoading) {
      return [
        DropdownMenuItem(
          value: null,
          child: Text(
            'Loading gates...',
            style: GoogleFonts.afacad(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          enabled: false,
        ),
      ];
    }
    if (_uniqueGateNames.isEmpty) {
      return [
        DropdownMenuItem(
          value: 'Default Gate',
          child: Text(
            'Default Gate',
            style: GoogleFonts.afacad(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }
    return _uniqueGateNames.map((gateName) {
      return DropdownMenuItem<String>(
        value: gateName,
        child: Text(
          gateName,
          style: GoogleFonts.afacad(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList();
  }
}

/// Organic gold blob (top-right) + soft light-blue circle (bottom-left),
/// echoing the reference design in the brand palette.
class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bw = (w * 0.5).clamp(240.0, 560.0);

    final gold =
        Path()
          ..moveTo(w - bw, 0)
          ..cubicTo(
            w - bw * 0.97,
            bw * 0.34,
            w - bw * 0.6,
            bw * 0.42,
            w - bw * 0.32,
            bw * 0.62,
          )
          ..cubicTo(
            w - bw * 0.12,
            bw * 0.78,
            w - bw * 0.02,
            bw * 0.56,
            w,
            bw * 0.42,
          )
          ..lineTo(w, 0)
          ..close();
    canvas.drawPath(gold, Paint()..color = kGold);

    canvas.drawCircle(
      Offset(0, size.height),
      w * 0.38,
      Paint()..color = kPrimaryLight.withOpacity(0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Sizes {
  final double field;
  final double label;
  final double icon;
  final double fieldPad;
  final double button;

  const _Sizes({
    required this.field,
    required this.label,
    required this.icon,
    required this.fieldPad,
    required this.button,
  });
}
