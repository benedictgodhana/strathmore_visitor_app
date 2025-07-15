import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color color;
  final Color backgroundColor;
  final bool showBackButton;
  final bool showNotifications;
  final bool showAccount;
  final bool showLogout;
  final int notificationCount;
  final VoidCallback? onLogoutTap;
  final List<Widget>? actions;

  const CustomAppBar({
    Key? key,
    required this.title,
    required this.color,
    required this.backgroundColor,
    this.showBackButton = false,
    this.showNotifications = false,
    this.showAccount = false,
    this.showLogout = false,
    this.notificationCount = 0,
    this.onLogoutTap,
    this.actions, required void Function() onBack,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0, // Flat design to match LoginScreen
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: color),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      centerTitle: true,
      actions: [
        if (showNotifications)
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_rounded, color: color),
                onPressed: () => _showNotifications(context),
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notificationCount.toString(),
                      style: GoogleFonts.lexend(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (showAccount)
          IconButton(
            icon: Icon(Icons.account_circle_rounded, color: color),
            onPressed: () {
              // Navigate to account page or show account menu
              Navigator.pushNamed(context, '/account');
            },
          ),
        if (showLogout)
          IconButton(
            icon: Icon(Icons.logout_rounded, color: color),
            onPressed: onLogoutTap,
            tooltip: 'Logout',
          ),
        if (actions != null) ...?actions,
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.notifications_rounded, color: AppColors.primaryBlue),
                  SizedBox(width: 10),
                  Text(
                    'Notifications',
                    style: GoogleFonts.lexend(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'No new notifications',
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}