import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:strathmore_visitor_app/screens/check_out_screen.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import 'package:strathmore_visitor_app/screens/goods_gate_pass_screen.dart';
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
  HttpOverrides.global = MyHttpOverrides();

  // Load preferences before deciding the initial route.
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final gateId = prefs.getString('gate_id');
  final deviceGate = prefs.getString('device_gate');

  // ── FIX 1: A session exists only when all three values are real.
  //          Never call init() with empty strings — that used to throw
  //          VisitorValidationException and leave the provider half-built.
  final hasSession = token != null &&
      token.isNotEmpty &&
      gateId != null &&
      gateId.isNotEmpty &&
      deviceGate != null &&
      deviceGate.isNotEmpty;

  final initialRoute = hasSession ? '/home' : '/';

  debugPrint(
    '🚀 Starting app — hasSession=$hasSession, route=$initialRoute',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => hasSession
              ? (VisitorProvider()..init(token, gateId, deviceGate))
              : VisitorProvider(),
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
        fontFamily: GoogleFonts.afacad().fontFamily,
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
        '/goods-gate-pass': (context) => const GoodsGatePassScreen(),
      },
    );
  }

  // Custom text theme using Afacad (Google Fonts)
  TextTheme _buildAfacadTextTheme(TextTheme baseTextTheme) {
    return TextTheme(
      displayLarge: GoogleFonts.afacad(
        fontWeight: FontWeight.w700,
        fontSize: 96,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.afacad(
        fontWeight: FontWeight.w700,
        fontSize: 60,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.afacad(
        fontWeight: FontWeight.w700,
        fontSize: 48,
        letterSpacing: 0.0,
      ),
      headlineLarge: GoogleFonts.afacad(
        fontWeight: FontWeight.w700,
        fontSize: 40,
        letterSpacing: 0.0,
      ),
      headlineMedium: GoogleFonts.afacad(
        fontWeight: FontWeight.w600,
        fontSize: 34,
        letterSpacing: 0.25,
      ),
      headlineSmall: GoogleFonts.afacad(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: 0.0,
      ),
      titleLarge: GoogleFonts.afacad(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: 0.15,
      ),
      titleMedium: GoogleFonts.afacad(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.afacad(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.afacad(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.afacad(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.afacad(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
      labelLarge: GoogleFonts.afacad(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 1.25,
      ),
      labelMedium: GoogleFonts.afacad(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
      labelSmall: GoogleFonts.afacad(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    ).copyWith(
      displayLarge: baseTextTheme.displayLarge?.merge(GoogleFonts.afacad()),
      displayMedium: baseTextTheme.displayMedium?.merge(GoogleFonts.afacad()),
      displaySmall: baseTextTheme.displaySmall?.merge(GoogleFonts.afacad()),
      headlineLarge: baseTextTheme.headlineLarge?.merge(GoogleFonts.afacad()),
      headlineMedium: baseTextTheme.headlineMedium?.merge(GoogleFonts.afacad()),
      headlineSmall: baseTextTheme.headlineSmall?.merge(GoogleFonts.afacad()),
      titleLarge: baseTextTheme.titleLarge?.merge(GoogleFonts.afacad()),
      titleMedium: baseTextTheme.titleMedium?.merge(GoogleFonts.afacad()),
      titleSmall: baseTextTheme.titleSmall?.merge(GoogleFonts.afacad()),
      bodyLarge: baseTextTheme.bodyLarge?.merge(GoogleFonts.afacad()),
      bodyMedium: baseTextTheme.bodyMedium?.merge(GoogleFonts.afacad()),
      bodySmall: baseTextTheme.bodySmall?.merge(GoogleFonts.afacad()),
      labelLarge: baseTextTheme.labelLarge?.merge(GoogleFonts.afacad()),
      labelMedium: baseTextTheme.labelMedium?.merge(GoogleFonts.afacad()),
      labelSmall: baseTextTheme.labelSmall?.merge(GoogleFonts.afacad()),
    );
  }
}