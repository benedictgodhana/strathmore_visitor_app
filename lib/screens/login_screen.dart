import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
          debugPrint('⚠️ Cached gate $cachedGate not found, reset to $_selectedGate');
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
      _uniqueGateNames = tempMap.keys.toList(); // Convert keys to List<String>
      
      // If no gates found, add default
      if (_uniqueGateNames.isEmpty) {
        _uniqueGateNames = ['Default Gate']; // Assign as List directly
        _gateIdMap = {'Default Gate': '1'};
      }
      
      if (mounted) {
        setState(() {
          if (_selectedGate == null || !_uniqueGateNames.contains(_selectedGate)) {
            _selectedGate = _uniqueGateNames.isNotEmpty ? _uniqueGateNames.first : null;
          }
        });
        debugPrint('✅ Loaded ${_uniqueGateNames.length} unique gates: $_uniqueGateNames');
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Login Error',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'BrandonGrotesque',
            color: AppColors.error,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'BrandonGrotesque',
            color: Colors.grey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'BrandonGrotesque',
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

      debugPrint('🔍 Attempting login with Username: ${_usernameController.text.trim()}, Gate: $gateName (ID: $gateId)');

      await _saveGateToPreferences(gateId, gateName);
      await visitorProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
        gateId,
        gateName,
      );

      debugPrint('✅ Login successful, navigating to home');
      showToast('Login successful!', backgroundColor: AppColors.primaryBlue);
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
        errorMessage = 'Request timed out. Please check your network connection.';
        _showErrorAlert(errorMessage, onRetry: _login);
      } else {
        errorMessage = 'Login failed: ${e.toString().replaceFirst('Exception: ', '')}';
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

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    // Build dropdown items from unique gate names (no duplicates!)
    List<DropdownMenuItem<String>> getGateDropdownItems() {
      if (_isGateLoading) {
        return [
          const DropdownMenuItem(
            value: null,
            child: Text(
              'Loading gates...',
              style: TextStyle(fontFamily: 'BrandonGrotesque'),
            ),
            enabled: false,
          ),
        ];
      }
      
      if (_uniqueGateNames.isEmpty) {
        return [
          const DropdownMenuItem(
            value: 'Default Gate',
            child: Text(
              'Default Gate',
              style: TextStyle(fontFamily: 'BrandonGrotesque'),
            ),
          ),
        ];
      }
      
      // Create dropdown items from unique gate names - NO DUPLICATES
      return _uniqueGateNames.map((gateName) {
        return DropdownMenuItem<String>(
          value: gateName,
          child: Text(
            gateName,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'BrandonGrotesque',
              color: Colors.grey,
            ),
          ),
        );
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(color: Colors.white),
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
                          const SizedBox(height: 16),
                          Text(
                            'VISITOR MANAGEMENT',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 24 : 28,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'BrandonGrotesque',
                              color: AppColors.primaryBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: const TextStyle(
                                fontFamily: 'BrandonGrotesque',
                                color: Colors.grey,
                              ),
                              prefixIcon: Icon(
                                Icons.person,
                                color: AppColors.primaryBlue,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            style: const TextStyle(
                              fontFamily: 'BrandonGrotesque',
                              fontSize: 16,
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                fontFamily: 'BrandonGrotesque',
                                color: Colors.grey,
                              ),
                              prefixIcon: const Icon(
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
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            style: const TextStyle(
                              fontFamily: 'BrandonGrotesque',
                              fontSize: 16,
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
                            value: _selectedGate != null && _uniqueGateNames.contains(_selectedGate)
                                ? _selectedGate
                                : (_uniqueGateNames.isNotEmpty ? _uniqueGateNames.first : null),
                            decoration: InputDecoration(
                              labelText: 'Select Gate',
                              labelStyle: const TextStyle(
                                fontFamily: 'BrandonGrotesque',
                                color: Colors.grey,
                              ),
                              prefixIcon: const Icon(
                                Icons.door_front_door,
                                color: AppColors.primaryBlue,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primaryBlue,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            items: getGateDropdownItems(),
                            onChanged: _isGateLoading
                                ? null
                                : (value) {
                                    if (mounted && value != null) {
                                      setState(() {
                                        _selectedGate = value;
                                        final gateId = _gateIdMap[value] ?? '1';
                                        debugPrint('✅ Selected gate: Name=$value, ID=$gateId');
                                        _saveGateToPreferences(gateId, value);
                                      });
                                    }
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a gate';
                              }
                              return null;
                            },
                            hint: const Text(
                              'Select a gate',
                              style: TextStyle(fontFamily: 'BrandonGrotesque'),
                            ),
                          ),
                          if (_uniqueGateNames.isEmpty && !_isGateLoading) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadGates,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry Loading Gates',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'BrandonGrotesque',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
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
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'BrandonGrotesque',
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'BrandonGrotesque',
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