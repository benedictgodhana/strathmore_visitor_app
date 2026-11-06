import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Brand (mirrors home_screen.dart so the theme matches) ───────────────────
const Color kPrimary = Color(0xFF02338D);
const Color kPrimaryLight = Color(0xFF2A5CAA);
const Color kPrimaryDark = Color(0xFF001A4A);
const Color kGold = Color(0xFFCC9C4A);
const Color kGoldLight = Color(0xFFE5B96B);
const Color kSuccess = Color(0xFF047857);
const Color kSignalGreen = Color(0xFF34D399);

class GoodsGatePassScreen extends StatefulWidget {
  const GoodsGatePassScreen({super.key});

  @override
  State<GoodsGatePassScreen> createState() => _GoodsGatePassScreenState();
}

class _GoodsGatePassScreenState extends State<GoodsGatePassScreen> {
  bool _isDarkMode = false;

  // Theme getters (same palette as home)
  Color get _bg => _isDarkMode ? const Color(0xFF060B1A) : Colors.white;
  Color get _surface => _isDarkMode ? const Color(0xFF0D1730) : Colors.white;
  Color get _tile =>
      _isDarkMode ? const Color(0xFF14213F) : const Color(0xFFE8EEFB);
  Color get _stroke =>
      _isDarkMode ? Colors.white.withOpacity(0.08) : kPrimary.withOpacity(0.10);
  Color get _text => _isDarkMode ? const Color(0xFFF1F5FF) : kPrimaryDark;
  Color get _muted =>
      _isDarkMode ? const Color(0xFF8FA0C4) : const Color(0xFF5B6B85);
  Color get _accent => _isDarkMode ? kGoldLight : kPrimary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            _isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            foregroundColor: _text,
            title: Text(
              'Goods Gate Pass',
              style: GoogleFonts.afacad(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildComingSoon(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon badge
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              size: 48,
              color: _accent,
            ),
          ),
          const SizedBox(height: 20),

          // "Coming Soon" pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: kGold.withOpacity(_isDarkMode ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'COMING SOON',
              style: GoogleFonts.afacad(
                fontSize: 12.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
                color: _isDarkMode ? kGoldLight : kGold,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Goods Gate Pass',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'We are working on this feature.\n'
            'Logging goods entering and leaving the gate\n'
            'will be available in an upcoming update.',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(
              fontSize: 16,
              height: 1.4,
              color: _muted,
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(
                'Back to Home',
                style: GoogleFonts.afacad(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isDarkMode ? kGoldLight : kPrimary,
                foregroundColor: _isDarkMode ? kPrimaryDark : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}