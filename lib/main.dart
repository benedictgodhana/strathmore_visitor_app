import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:strathmore_visitor_app/screens/check_out_screen.dart';
import 'package:strathmore_visitor_app/screens/forget_screen.dart';
import 'package:strathmore_visitor_app/screens/lost_id_verification_screen.dart';
import 'package:strathmore_visitor_app/screens/splash_screen.dart';
import 'package:strathmore_visitor_app/screens/login_screen.dart';
import 'package:strathmore_visitor_app/screens/home_screen.dart';
import 'package:strathmore_visitor_app/screens/visitor_list_screen.dart';
import 'package:strathmore_visitor_app/screens/visitor_registration_screen.dart';
import 'package:strathmore_visitor_app/screens/admin_dashboard.dart';

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

void main() {
  HttpOverrides.global = MyHttpOverrides(); // Set override globally
  runApp(StrathmoreBMS());
}

class StrathmoreBMS extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => VisitorProvider())],
      child: MaterialApp(
        title: 'Strathmore Visitor Management',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: AppColors.primaryBlue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textTheme: GoogleFonts.lexendTextTheme(
            Theme.of(context).textTheme.copyWith(
              titleLarge: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlue,
              ),
              bodyLarge: GoogleFonts.lexend(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade800,
              ),
              bodyMedium: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
              labelLarge: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        initialRoute: '/',
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
        },
      ),
    );
  }
}
