/// Shared error message for network failures
import 'package:flutter/material.dart';

const String kNetworkErrorMessage =
    'Network error: Unable to connect. Please check your internet or VPN connection.';

class AppColors {
  static const Color primaryBlue = Color(0xFF02338D); // #02338D
  static const Color secondaryBlue = Color(0xFF02338D); // #CC9C4A
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color background = Color(0xFFFFFFFF);

  static const Color info = Color(0xFFFFFFFF);

  static var darkBackground;

  static var lightBackground;

  static var backgroundDark;

  static var backgroundLight; // Updated to white
}

class AppStrings {
  static const String appName = 'Strathmore Visitor Management';
  static const String universityName = 'Strathmore University';
  static const String welcomeMessage = 'Welcome to Strathmore University';
  static const String apiBaseUrl =
      'https://chala.strathmore.edu'; // Added API base URL
}
