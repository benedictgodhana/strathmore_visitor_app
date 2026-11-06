import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/visitor_provider.dart';
import '../utils/constants.dart';

// ── Brand tokens (identical to HomeScreen / CheckOutScreen) ───────────────
const Color kPrimary = Color(0xFF0B3D91);
const Color kPrimaryLight = Color(0xFF1E5AA8);
const Color kPrimaryDark = Color(0xFF061E45);
const Color kGold = Color(0xFFB8860B);
const Color kGoldLight = Color(0xFFD4A72C);
const Color kSuccess = Color(0xFF047857);
const Color kSignalGreen = Color(0xFF34D399);
const Color kDanger = Color(0xFFB91C1C);

const int kDailyGoal = 50;
const String kAppVersion = '3.2.1';
const String kPrivacyNotice =
    'Visitor data is processed per institutional privacy policy and the '
    "Kenya Data Protection Act, 2019.";

const _tabular = [FontFeature.tabularFigures()];

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;

  String? _errorMessage;

  // ── Theme tokens ────────────────────────────────────────────────────────
  Color get _bg => const Color(0xFFEFF2F8);
  Color get _surface => Colors.white;
  Color get _text => kPrimaryDark;
  Color get _muted => const Color(0xFF5B6B85);
  Color get _accent => kPrimary;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();

    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final visitorProvider =
        Provider.of<VisitorProvider>(context, listen: false);

    // Read stored session directly (main.dart may not have initialised
    // the provider if we launched on this route).
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final gateId = prefs.getString('gate_id');
    final deviceGate = prefs.getString('device_gate');

    final hasSession = token != null &&
        token.isNotEmpty &&
        gateId != null &&
        gateId.isNotEmpty &&
        deviceGate != null &&
        deviceGate.isNotEmpty;

    if (!hasSession) {
      // No stored session — brief pause for the animation, then login.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Seed the provider with the stored session. init() now tolerates
      // transient network failures and won't wipe the token.
      if (!visitorProvider.isAuthenticated) {
        await visitorProvider.init(token, gateId, deviceGate);
      }

      // Give the animation a moment to complete before routing.
      await Future.delayed(const Duration(milliseconds: 1400));

      if (!mounted) return;

      if (visitorProvider.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kDanger.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: kDanger, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Initialization Error',
              style: GoogleFonts.afacad(
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
          ],
        ),
        content: Text(
          _errorMessage ??
              'An error occurred while loading the app. Please try again.',
          style: GoogleFonts.afacad(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text(
              'Go to Login',
              style: GoogleFonts.afacad(
                color: _accent,
                fontWeight: FontWeight.w800,
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
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.height < 700;

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [kPrimaryLight, kPrimary, kPrimaryDark],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),

            // Gold edge line (matches hero card)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    kGoldLight.withOpacity(0.9),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildBrandMark(compact),
                            SizedBox(height: compact ? 24 : 40),
                            _buildWordmark(),
                            SizedBox(height: compact ? 28 : 44),
                            _buildStatusPill(),
                            SizedBox(height: compact ? 24 : 36),
                            _buildProgressIndicator(),
                            SizedBox(height: compact ? 32 : 56),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Brand mark — same gold gradient shield as the sidebar ───────────────
  Widget _buildBrandMark(bool compact) {
    final markSize = compact ? 96.0 : 120.0;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        children: [
          Container(
            width: markSize,
            height: markSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kGoldLight, kGold],
              ),
              borderRadius: BorderRadius.circular(markSize * 0.28),
              boxShadow: [
                BoxShadow(
                  color: kGold.withOpacity(0.45),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.shield_rounded,
              color: kPrimaryDark,
              size: markSize * 0.55,
            ),
          ),
          SizedBox(height: compact ? 16 : 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulseDot(color: kSignalGreen, size: 7),
                const SizedBox(width: 10),
                Text(
                  'ACCESS CONTROL',
                  style: GoogleFonts.afacad(
                    color: kGoldLight,
                    fontSize: 11,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Wordmark ────────────────────────────────────────────────────────────
  Widget _buildWordmark() {
    return Column(
      children: [
        Text(
          AppStrings.universityName,
          textAlign: TextAlign.center,
          style: GoogleFonts.afacad(
            color: Colors.white,
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Visitor Management System',
          textAlign: TextAlign.center,
          style: GoogleFonts.afacad(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Status pill (mirrors hero card's "SYSTEM SECURE") ───────────────────
  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kSignalGreen.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSignalGreen.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(color: kSignalGreen, size: 6),
          const SizedBox(width: 10),
          Text(
            'SECURE CHANNEL · INITIALIZING',
            style: GoogleFonts.afacad(
              color: kSignalGreen,
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress indicator ──────────────────────────────────────────────────
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 2.5,
                  ),
                ),
              ),
              // Spinner
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(kGoldLight),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Loading secure session…',
          style: GoogleFonts.afacad(
            color: Colors.white60,
            fontSize: 12.5,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Footer (mirrors _buildComplianceFooter in HomeScreen) ───────────────
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security_rounded,
            size: 13, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'v$kAppVersion · $kPrivacyNotice',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.afacad(
              fontSize: 10.5,
              color: Colors.white.withOpacity(0.45),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pulsing live indicator (identical to HomeScreen) ──────────────────────
class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseDot({required this.color, this.size = 8});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s + (s * 1.4) * _c.value,
              height: s + (s * 1.4) * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.45 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid painter (identical to HomeScreen) ────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}