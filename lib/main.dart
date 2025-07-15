import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strathmore_visitor_app/screens/check_out_screen.dart';
import 'package:strathmore_visitor_app/screens/lost_id_verification_screen.dart';
import 'providers/visitor_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/visitor_registration_screen.dart';
import 'screens/admin_dashboard.dart';
import 'utils/constants.dart';

void main() {
  runApp(StrathmoreBMS());
}

class StrathmoreBMS extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VisitorProvider()),
      ],
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
          '/lost-id-verification': (context) =>  IdentityVerificationScreen(),
          '/check-out': (context) => CheckOutScreen(), // Assuming check-out uses the same screen
           // New route

        },
      ),
    );
  }
}