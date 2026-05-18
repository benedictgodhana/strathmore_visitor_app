import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    print('SplashScreen: Checking authentication status...');

    // Attempt to validate token via API
    String? token;
    String? gateId;
    String? deviceGate;

    try {
      // Placeholder for token validation API call
      // Replace with actual API endpoint to validate token
      final response = await http
          .get(
            Uri.parse('${AppStrings.apiBaseUrl}/api/validate-token'),
            headers: {
              'Content-Type': 'application/json',
              // Assume token is passed from app context or environment
              'Authorization': 'Bearer ${token ?? ''}',
            },
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'];
        gateId = data['gate_id']?.toString();
        deviceGate = data['gate_name'];
      }
    } catch (e) {
      print('SplashScreen: Token validation failed: $e');
      // Token is invalid or unavailable; proceed to login
    }

    if (token != null && gateId != null && deviceGate != null) {
      try {
        print(
          'SplashScreen: Initializing VisitorProvider with token: $token, gateId: $gateId, deviceGate: $deviceGate',
        );
        await visitorProvider.init(token, gateId, deviceGate);
        print(
          'SplashScreen: isAuthenticated: ${visitorProvider.isAuthenticated}, deviceGate: ${visitorProvider.deviceGate}',
        );

        if (visitorProvider.isAuthenticated) {
          await Future.delayed(Duration(seconds: 3));
          print('SplashScreen: Navigating to /home');
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      } catch (e) {
        print('SplashScreen: Initialization error: $e');
        setState(() {
          _errorMessage = 'Failed to initialize: $e';
        });
        _showErrorDialog();
        return;
      }
    }

    // No valid token or initialization failed; navigate to login
    await Future.delayed(Duration(seconds: 3));
    print('SplashScreen: Navigating to /login');
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Initialization Error',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'BrandonGrotesque',
              ),
            ),
            content: Text(
              _errorMessage ??
                  'An error occurred while loading the app. Please try again.',
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(
                  'Go to Login',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontFamily: 'BrandonGrotesque',
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/strathmore_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.school,
                                  size: 80,
                                  color: AppColors.primaryBlue,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      AppStrings.universityName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'BrandonGrotesque',
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Visitor Management System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'BrandonGrotesque',
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 60),
                    Container(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'BrandonGrotesque',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}