// components/custom_bottom_nav.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap, required void Function() onNext, required int step, required bool isLoading, required void Function() onBack, required List<Widget> children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: Colors.grey[500],
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.home_rounded, 0),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person_add_alt_1_rounded, 1),
              label: 'Register',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.login_rounded, 2),
              label: 'Check In',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.logout_rounded, 3),
              label: 'Check Out',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.admin_panel_settings_rounded, 4),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = currentIndex == index;
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primaryBlue.withOpacity(0.1) 
            : Colors.transparent,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: AppColors.primaryBlue.withOpacity(0.3))
            : null,
      ),
      child: Icon(
        icon,
        size: 24,
        color: isSelected ? AppColors.primaryBlue : Colors.grey[500],
      ),
    );
  }
}

