import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:strathmore_visitor_app/screens/check_out_screen.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import 'package:strathmore_visitor_app/screens/lost_id_verification_screen.dart';
import 'package:strathmore_visitor_app/screens/settings_screen.dart';
import 'package:strathmore_visitor_app/screens/splash_screen.dart';
import 'package:strathmore_visitor_app/screens/login_screen.dart';
import 'package:strathmore_visitor_app/screens/home_screen.dart';
import 'package:strathmore_visitor_app/screens/visitor_details_screen.dart';
import 'package:strathmore_visitor_app/screens/visitor_list_screen.dart';
import 'package:strathmore_visitor_app/screens/visitor_registration_screen.dart';
import 'package:strathmore_visitor_app/screens/admin_dashboard.dart';
import 'package:strathmore_visitor_app/screens/visitor_search_screen.dart';

import 'providers/visitor_provider.dart';
import 'utils/constants.dart';

/// Override HTTP behavior to accept self-signed certificate in development
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == "chala.strathmore.edu"; // Accept only this domain
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides(); // Set override globally

  // Configure Google Fonts to allow runtime fetching (optional fallback)

  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final token =
      prefs.getString('token')?.isNotEmpty == true
          ? prefs.getString('token')
          : null;
  final gateId =
      prefs.getString('gate_id')?.isNotEmpty == true
          ? prefs.getString('gate_id')
          : null;
  final deviceGate =
      prefs.getString('device_gate')?.isNotEmpty == true
          ? prefs.getString('device_gate')
          : null;

  // Determine initial route based on token presence
  final initialRoute =
      (token != null && gateId != null && deviceGate != null) ? '/home' : '/';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (_) =>
                  VisitorProvider()
                    ..init(token ?? '', gateId ?? '', deviceGate ?? ''),
        ),
      ],
      child: StrathmoreBMS(initialRoute: initialRoute),
    ),
  );
}

class StrathmoreBMS extends StatelessWidget {
  final String initialRoute;

  StrathmoreBMS({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF02338D),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF02338D),
          secondary: const Color(0xFFCC9C4A),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'BrandonGrotesque',
        textTheme: Theme.of(context).textTheme,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/visitor-registration': (context) => VisitorRegistrationScreen(),
        '/admin': (context) => AdminDashboard(),
        '/lost-id-verification': (context) => IdentityVerificationScreen(),
        '/check-out': (context) => CheckOutScreen(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/visitor-list': (context) => VisitorListScreen(),
        '/settings': (context) => SettingsScreen(),
        '/visitor-details': (context) => VisitorDetailsScreen(),
        '/visitor-search': (context) => VisitorSearchScreen(),
      },
    );
  }

  // Custom text theme using Brandon Grotesque fonts
  TextTheme _buildBrandonGrotesqueTextTheme(TextTheme baseTextTheme) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w700,
        fontSize: 96,
        letterSpacing: -1.5,
      ),
      displayMedium: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w700,
        fontSize: 60,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w700,
        fontSize: 48,
        letterSpacing: 0.0,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w700,
        fontSize: 40,
        letterSpacing: 0.0,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w600,
        fontSize: 34,
        letterSpacing: 0.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: 0.0,
      ),
      titleLarge: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: 0.15,
      ),
      titleMedium: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w500,
        fontSize: 16,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w400,
        fontSize: 16,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w400,
        fontSize: 14,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w400,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 1.25,
      ),
      labelMedium: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
      labelSmall: TextStyle(
        fontFamily: 'BrandonGrotesque',
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    ).copyWith(
      // Preserve any existing styles from baseTextTheme if needed
      displayLarge: baseTextTheme.displayLarge?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      displayMedium: baseTextTheme.displayMedium?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      displaySmall: baseTextTheme.displaySmall?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      headlineLarge: baseTextTheme.headlineLarge?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      headlineMedium: baseTextTheme.headlineMedium?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      headlineSmall: baseTextTheme.headlineSmall?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      titleLarge: baseTextTheme.titleLarge?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      titleMedium: baseTextTheme.titleMedium?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      titleSmall: baseTextTheme.titleSmall?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      bodyLarge: baseTextTheme.bodyLarge?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      bodyMedium: baseTextTheme.bodyMedium?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      bodySmall: baseTextTheme.bodySmall?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      labelLarge: baseTextTheme.labelLarge?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      labelMedium: baseTextTheme.labelMedium?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
      labelSmall: baseTextTheme.labelSmall?.merge(
        TextStyle(fontFamily: 'BrandonGrotesque'),
      ),
    );
  }
}
