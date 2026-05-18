import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDarkMode;

  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isDarkMode,
    // These parameters are maintained for compatibility but not used in the new design
    required void Function() onNext,
    required int step,
    required bool isLoading,
    required void Function() onBack,
    required List<Widget> children,
  }) : super(key: key);

  @override
  _CustomBottomNavState createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _rippleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.fromLTRB(20, 0, 20, 30),
            height: isVerySmallScreen ? 60 : isSmallScreen ? 65 : 75,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: widget.isDarkMode ? Color(0xFF334155) : Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    Icons.home_rounded,
                    'Home',
                    0,
                    Color(0xFF3B82F6),
                  ),
                  _buildNavItem(
                    Icons.person_add_alt_1_rounded,
                    'Register',
                    1,
                    Color(0xFF10B981),
                  ),
                  _buildNavItem(
                    Icons.logout_rounded,
                    'Check Out',
                    2,
                    Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, Color itemColor) {
    final isSelected = widget.currentIndex == index;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              HapticFeedback.selectionClick();
              _rippleController.forward().then((_) {
                _rippleController.reverse();
              });
              widget.onTap(index);
            }
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: itemColor.withOpacity(0.1),
          highlightColor: itemColor.withOpacity(0.05),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              vertical: isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8,
              horizontal: isVerySmallScreen ? 2 : isSmallScreen ? 4 : 6,
            ),
            child: ClipRect(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.all(isSelected ? 6 : 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? itemColor.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: itemColor.withOpacity(0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: AnimatedScale(
                      duration: Duration(milliseconds: 300),
                      scale: isSelected ? 1.1 : 1.0,
                      child: Icon(
                        icon,
                        size: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                        color: isSelected
                            ? itemColor
                            : (widget.isDarkMode
                                ? Color(0xFF94A3B8)
                                : Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 0.5 : 1),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 8 : isSmallScreen ? 9 : 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontFamily: 'BrandonGrotesque',
                      color: isSelected
                          ? itemColor
                          : (widget.isDarkMode
                              ? Color(0xFF94A3B8)
                              : Color(0xFF64748B)),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isVerySmallScreen ? 0.5 : 1),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: isSelected ? 5 : 0,
                    height: isSelected ? 5 : 0,
                    decoration: BoxDecoration(
                      color: itemColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CompactCustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isDarkMode;

  const CompactCustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isDarkMode,
    // Compatibility parameters
    required void Function() onNext,
    required int step,
    required bool isLoading,
    required void Function() onBack,
    required List<Widget> children,
  }) : super(key: key);

  @override
  _CompactCustomBottomNavState createState() => _CompactCustomBottomNavState();
}

class _CompactCustomBottomNavState extends State<CompactCustomBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;

    final navItems = [
      NavItem(Icons.home_rounded, 'Home', Color(0xFF3B82F6)),
      NavItem(Icons.person_add_alt_1_rounded, 'Register', Color(0xFF10B981)),
      NavItem(Icons.logout_rounded, 'Out', Color(0xFFEF4444)),
    ];

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.fromLTRB(16, 0, 16, 20),
            height: isVerySmallScreen ? 55 : isSmallScreen ? 60 : 65,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(32.5),
              border: Border.all(
                color: widget.isDarkMode ? Color(0xFF1E293B) : Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = widget.currentIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!isSelected) {
                        HapticFeedback.selectionClick();
                        widget.onTap(index);
                      }
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.all(isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? item.color.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(
                                color: item.color.withOpacity(0.2),
                                width: 1,
                              )
                            : null,
                      ),
                      child: ClipRect(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: isVerySmallScreen ? 16 : isSmallScreen ? 17 : 18,
                              color: isSelected
                                  ? item.color
                                  : (widget.isDarkMode
                                      ? Color(0xFF64748B)
                                      : Color(0xFF94A3B8)),
                            ),
                            SizedBox(height: isVerySmallScreen ? 0.5 : 1),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 7 : isSmallScreen ? 8 : 9,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontFamily: 'BrandonGrotesque',
                                color: isSelected
                                    ? item.color
                                    : (widget.isDarkMode
                                        ? Color(0xFF64748B)
                                        : Color(0xFF94A3B8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final Color color;

  NavItem(this.icon, this.label, this.color);
}