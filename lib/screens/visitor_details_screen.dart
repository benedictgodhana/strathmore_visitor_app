import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/visitor.dart';
import '../utils/constants.dart';

// ── Brand tokens ─────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFF02338D);
const Color kPrimaryLight = Color(0xFF2A5CAA);
const Color kPrimaryDark = Color(0xFF001A4A);
const Color kGold = Color(0xFFCC9C4A);
const Color kGoldLight = Color(0xFFE5B96B);
const Color kSuccess = Color(0xFF047857);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);
const Color kSignalAmber = Color(0xFFFBBF24);

class VisitorDetailsScreen extends StatefulWidget {
  @override
  State<VisitorDetailsScreen> createState() => _VisitorDetailsScreenState();
}

class _VisitorDetailsScreenState extends State<VisitorDetailsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDarkMode = false;

  // ── Theme tokens ────────────────────────────────────────────────────────
  Color get _bg =>
      _isDarkMode ? const Color(0xFF060B1A) : const Color(0xFFF7F9FC);
  Color get _surface => _isDarkMode ? const Color(0xFF0D1730) : Colors.white;
  Color get _tile =>
      _isDarkMode ? const Color(0xFF14213F) : const Color(0xFFE8EEFB);
  Color get _stroke =>
      _isDarkMode ? Colors.white.withOpacity(0.08) : kPrimary.withOpacity(0.08);
  Color get _text => _isDarkMode ? const Color(0xFFF1F5FF) : kPrimaryDark;
  Color get _muted =>
      _isDarkMode ? const Color(0xFF8FA0C4) : const Color(0xFF5B6B85);
  Color get _accent => _isDarkMode ? kGoldLight : kPrimary;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    }
  }

  void _toggleDarkMode() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('gate_id');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Visitor? visitor =
        ModalRoute.of(context)?.settings.arguments as Visitor?;

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
            _isDarkMode
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bg,
          drawer: _buildDrawer(),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child:
                          visitor == null
                              ? _buildEmptyState()
                              : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  40,
                                ),
                                child: _buildBody(visitor),
                              ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Drawer ──────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    Widget item(IconData i, String label, VoidCallback onTap) => ListTile(
      leading: Icon(i, color: Colors.white.withOpacity(0.9), size: 26),
      title: Text(
        label,
        style: GoogleFonts.afacad(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );

    return Drawer(
      backgroundColor: kPrimaryDark,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/strathmore_logo.png',
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.universityName,
                    style: GoogleFonts.afacad(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'VISITOR DETAILS',
                    style: GoogleFonts.afacad(
                      color: kGoldLight,
                      fontSize: 12.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            item(Icons.grid_view_rounded, 'Dashboard', _goHome),
            item(
              Icons.people_alt_outlined,
              'All Visitors',
              () => _go('/visitor-list'),
            ),
            item(
              Icons.search_rounded,
              'Search Records',
              () => _go('/visitor-search'),
            ),
            item(
              Icons.exit_to_app_rounded,
              'Check Out',
              () => _go('/check-out'),
            ),
            item(
              Icons.verified_user_outlined,
              'Verify ID',
              () => _go('/lost-id-verification'),
            ),
            item(Icons.settings_outlined, 'Settings', () => _go('/settings')),
            const Spacer(),
            SwitchListTile(
              value: _isDarkMode,
              onChanged: (_) => _toggleDarkMode(),
              activeColor: kGoldLight,
              secondary: const Icon(
                Icons.dark_mode_rounded,
                color: Colors.white70,
                size: 26,
              ),
              title: Text(
                'Dark mode',
                style: GoogleFonts.afacad(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            item(Icons.logout_rounded, 'Log out', _logout),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Open menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(Icons.grid_view_rounded, color: _text, size: 28),
          ),
          Text(
            "Profile",
            style: GoogleFonts.afacad(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          IconButton(
            tooltip: _isDarkMode ? 'Light mode' : 'Dark mode',
            onPressed: _toggleDarkMode,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(_isDarkMode),
                color: _text,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main Body ───────────────────────────────────────────────────────────
  Widget _buildBody(Visitor visitor) {
    final active = visitor.checkOutTime == null;
    final initial =
        visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(visitor, initial, active),
        const SizedBox(height: 24),

        _buildSectionTitle('Visit Details', trailing: 'View all'),
        const SizedBox(height: 12),
        _buildHorizontalPills(visitor, active),
        const SizedBox(height: 24),

        _buildSectionTitle('Visitor Information'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildListTile(
                icon: Icons.badge_outlined,
                title: 'Identification',
                subtitle:
                    (visitor.identificationType ?? 'ID')
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                trailing: visitor.identificationNumber ?? '-',
              ),
              Divider(height: 1, color: _stroke),
              _buildListTile(
                icon: Icons.phone_outlined,
                title: 'Contact',
                subtitle: 'Phone Number',
                trailing:
                    visitor.phoneNumber.isNotEmpty ? visitor.phoneNumber : '-',
              ),
              Divider(height: 1, color: _stroke),
              _buildListTile(
                icon: Icons.location_on_outlined,
                title: 'Entry Gate',
                subtitle: 'Assigned Gate',
                trailing: visitor.gate ?? '-',
              ),
              Divider(height: 1, color: _stroke),
              _buildListTile(
                icon: Icons.public_rounded,
                title: 'Country',
                subtitle: 'Nationality',
                trailing: visitor.country ?? '-',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero Card (Like the top of the reference image) ─────────────────────
  Widget _buildHeroCard(Visitor visitor, String initial, bool active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: kPrimary, // Deep blue from the image
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Profile Avatar
          Container(
            width: 90,
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              initial,
              style: GoogleFonts.afacad(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            visitor.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.afacad(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Subtitle (Status)
          Text(
            active ? 'Currently On Site' : 'Checked Out',
            style: GoogleFonts.afacad(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: active ? kSignalGreen : Colors.white70,
            ),
          ),
          const SizedBox(height: 28),

          // Stats Row (adapted from Followers/Following/Projects)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(
                'Check-in',
                _formatTimeOnly(visitor.checkInTime),
              ),
              _buildStatColumn('Gate', visitor.gate ?? '-'),
              _buildStatColumn(
                'Tag ID',
                visitor.visitorTagId?.toString() ?? '-',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.afacad(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.afacad(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ── Horizontal Pills (Like the "Folders" section) ───────────────────────
  Widget _buildHorizontalPills(Visitor visitor, bool active) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildPill(
            icon: Icons.schedule_rounded,
            title: 'Check-in',
            subtitle: _formatTimeOnly(visitor.checkInTime),
          ),
          const SizedBox(width: 12),
          _buildPill(
            icon: Icons.logout_rounded,
            title: 'Check-out',
            subtitle:
                visitor.checkOutTime == null
                    ? 'Pending'
                    : _formatTimeOnly(visitor.checkOutTime),
          ),
          const SizedBox(width: 12),
          _buildPill(
            icon: Icons.event_available_rounded,
            title: 'Appointment',
            subtitle: (visitor.hadAppointment ?? false) ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile, // Light blue background
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.afacad(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.afacad(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── List Tiles (Like the "My Team" section) ─────────────────────────────
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: _tile, shape: BoxShape.circle),
            child: Icon(icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.afacad(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.afacad(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: GoogleFonts.afacad(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.afacad(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.afacad(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: _tile,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: _muted),
            const SizedBox(height: 14),
            Text(
              'No visitor data provided',
              style: GoogleFonts.afacad(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open this screen from a visitor record.',
              textAlign: TextAlign.center,
              style: GoogleFonts.afacad(fontSize: 15, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOnly(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('hh:mm a').format(value.toLocal());
  }
}
