import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';

const Color kPrimary = Color(0xFF0B3D91);
const Color kPrimaryLight = Color(0xFF1E5AA8);
const Color kPrimaryDark = Color(0xFF061E45);
const Color kGold = Color(0xFFB8860B);
const Color kGoldLight = Color(0xFFD4A72C);
const Color kSuccess = Color(0xFF047857);
const Color kWarning = Color(0xFFB45309);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);
const Color kSignalAmber = Color(0xFFFBBF24);
const String kAppVersion = '3.2.1';
const String kPrivacyNotice =
    'Visitor data is processed per institutional privacy policy and the '
    'Kenya Data Protection Act, 2019.';
const String kDataRetention = 'Data retention: 90 days';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key});
  @override
  _VisitorListScreenState createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late AnimationController _dialogAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  bool _isDarkMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _deviceGate;
  bool _isFetchingVisitors = false;
  String _sortBy = 'name';
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
  Color get _ok => _isDarkMode ? kSignalGreen : kSuccess;
  Color get _warn => _isDarkMode ? kSignalAmber : kWarning;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _dialogAnimationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadUserPreferences();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCheckedInVisitors();
    });
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _deviceGate = prefs.getString('device_gate') ?? 'Main Gate';
    });
  }

  Future<void> _loadCheckedInVisitors() async {
    if (_isFetchingVisitors) return;
    _isFetchingVisitors = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final gateId = prefs.getString('gate_id');
      if (token == null || gateId == null) {
        _showAuthErrorDialog();
        return;
      }
      if (!mounted) return;
      final visitorProvider = Provider.of<VisitorProvider>(
        context,
        listen: false,
      );
      visitorProvider.setAuthData(token, gateId, _deviceGate ?? 'Main Gate');
      await visitorProvider.loadCheckedInVisitors();
      if (visitorProvider.visitors.isNotEmpty) {
        _confettiController.play();
      }
    } catch (e) {
      if (e.toString().contains('Authentication failed') ||
          e.toString().contains('unauthenticated')) {
        _showAuthErrorDialog();
      } else {
        _snack('Failed to load checked-in visitors: ${e.toString()}', kDanger);
      }
    } finally {
      _isFetchingVisitors = false;
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.afacad(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dialogAnimationController.dispose();
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final visitorProvider = Provider.of<VisitorProvider>(context);
    final checkedIn =
        visitorProvider.visitors.where((v) => v.checkOutTime == null).toList();
    final filtered =
        _searchQuery.isEmpty
            ? checkedIn
            : checkedIn.where((v) {
              final name = v.name.toLowerCase();
              final id = v.identificationNumber?.toLowerCase() ?? '';
              return name.contains(_searchQuery) || id.contains(_searchQuery);
            }).toList();
    final sorted = List<Visitor>.from(filtered);
    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'checkin':
          final aT = a.checkInTime ?? DateTime(1970);
          final bT = b.checkInTime ?? DateTime(1970);
          return bT.compareTo(aT);
        case 'destination':
          return (a.destinationId ?? '').toString().compareTo(
            (b.destinationId ?? '').toString(),
          );
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
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
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              backgroundColor: _isDarkMode ? kGoldLight : kPrimary,
              foregroundColor: _isDarkMode ? kPrimaryDark : Colors.white,
              shape: const CircleBorder(),
              tooltip: 'New Visitor',
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pushNamed(context, '/visitor-registration');
              },
              child: const Icon(Icons.add_rounded, size: 34),
            ),
          ),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadCheckedInVisitors,
                            color: Colors.white,
                            backgroundColor: kPrimary,
                            child: CustomScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    0,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSummaryCard(checkedIn.length),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSearchField(),
                                            ),
                                            const SizedBox(width: 10),
                                            _buildSortMenu(),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _sectionHeader(
                                          'Checked-In Visitors',
                                          trailing: '${sorted.length} shown',
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  sliver:
                                      visitorProvider.isLoading
                                          ? const SliverToBoxAdapter(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 48,
                                              ),
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(kPrimary),
                                                ),
                                              ),
                                            ),
                                          )
                                          : sorted.isEmpty
                                          ? SliverToBoxAdapter(
                                            child: _buildEmptyState(),
                                          )
                                          : SliverList(
                                            delegate:
                                                SliverChildBuilderDelegate((
                                                  context,
                                                  i,
                                                ) {
                                                  return FadeTransition(
                                                    opacity: _fadeAnimation,
                                                    child: _buildVisitorCard(
                                                      sorted[i],
                                                      visitorProvider,
                                                    ),
                                                  );
                                                }, childCount: sorted.length),
                                          ),
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      10,
                                      20,
                                      96,
                                    ),
                                    child: _buildComplianceFooter(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.white,
                    kPrimary,
                    kPrimaryLight,
                    kGold,
                    kGoldLight,
                  ],
                  numberOfParticles: 50,
                  gravity: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                    'VISITOR MANAGEMENT',
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

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  Future<void> _logout() async {
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    await visitorProvider.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('gate_id');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
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
            'All Visitors',
            style: GoogleFonts.afacad(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.selectionClick();
              _loadCheckedInVisitors();
            },
            icon: Icon(Icons.refresh_rounded, color: _text, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDarkMode ? kPrimaryLight : kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On site now',
                  style: GoogleFonts.afacad(
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  _deviceGate ?? 'Main Gate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.afacad(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.afacad(
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.afacad(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: GoogleFonts.afacad(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: _tile.withOpacity(_isDarkMode ? 0.7 : 0.55),
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Search by name or ID',
          hintStyle: GoogleFonts.afacad(color: _muted, fontSize: 16),
          prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 24),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: _muted, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          border: InputBorder.none,
        ),
        style: GoogleFonts.afacad(fontSize: 17, color: _text),
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      initialValue: _sortBy,
      tooltip: 'Sort',
      elevation: 0,
      onSelected: (v) => setState(() => _sortBy = v),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _stroke),
      ),
      color: _surface,
      itemBuilder:
          (context) => [
            _sortItem('name', 'Name (A–Z)'),
            _sortItem('checkin', 'Check-in (newest)'),
            _sortItem('destination', 'Destination'),
          ],
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: _tile, shape: BoxShape.circle),
        child: Icon(Icons.sort_rounded, size: 24, color: _accent),
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    final selected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? _accent : _muted,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.afacad(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorCard(Visitor visitor, VisitorProvider provider) {
    final initial =
        visitor.name.isNotEmpty ? visitor.name[0].toUpperCase() : '?';
    final active = visitor.checkOutTime == null;
    final destination = _destinationName(visitor, provider);
    final t = visitor.checkInTime?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          _showVisitorDetailsModal(visitor, provider);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (active ? _ok : _muted).withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: GoogleFonts.afacad(
                        color: _accent,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visitor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.afacad(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ID: ${visitor.identificationNumber ?? 'N/A'} · ${visitor.phoneNumber.isNotEmpty ? visitor.phoneNumber : 'No phone'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.afacad(
                            fontSize: 14,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  active
                      ? _pill(
                        label: 'CHECK OUT',
                        icon: Icons.logout_rounded,
                        color: _warn,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await _showCheckoutConfirmation(visitor, provider);
                        },
                      )
                      : _pill(
                        label: 'DONE',
                        icon: Icons.check_circle_outline_rounded,
                        color: _ok,
                      ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: _muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.afacad(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                  ),
                  Icon(Icons.schedule_rounded, size: 16, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    t == null
                        ? '—'
                        : '${DateFormat('hh:mm a').format(t)} · ${DateFormat('d MMM').format(t)}',
                    style: GoogleFonts.afacad(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.afacad(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _destinationName(Visitor visitor, VisitorProvider provider) {
    if (provider.destinations.isEmpty) return 'Unknown';
    final match = provider.destinations.firstWhere(
      (dest) => dest['id'].toString() == visitor.destinationId.toString(),
      orElse: () => <String, String>{'name': 'Unknown'},
    );
    return match['name'] ?? 'Unknown';
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: _muted),
          const SizedBox(height: 12),
          Text(
            'No Checked-In Visitors',
            style: GoogleFonts.afacad(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Visitors will appear here once they check in at the gate.',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(fontSize: 15, color: _muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _loadCheckedInVisitors();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent, width: 1.2),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  'Refresh',
                  style: GoogleFonts.afacad(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/visitor-registration');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _isDarkMode ? kPrimaryDark : Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: Text(
                  'Check In Visitor',
                  style: GoogleFonts.afacad(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security_rounded, size: 16, color: _muted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '$kPrivacyNotice · $kDataRetention · v$kAppVersion',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(fontSize: 13.5, color: _muted),
          ),
        ),
      ],
    );
  }

  void _showAuthErrorDialog() {
    if (!mounted) return;
    _dialogAnimationController.forward();
    showDialog(
      context: context,
      builder:
          (context) => ScaleTransition(
            scale: _scaleAnimation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: _surface,
              elevation: 0,
              contentPadding: const EdgeInsets.all(24),
              title: Text(
                'Session Expired',
                style: GoogleFonts.afacad(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 52, color: _warn),
                  const SizedBox(height: 16),
                  Text(
                    'Your session has expired. Please log in again to continue.',
                    style: GoogleFonts.afacad(fontSize: 16, color: _muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _isDarkMode ? kPrimaryDark : Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
    ).whenComplete(() => _dialogAnimationController.reset());
  }

  void _showVisitorDetailsModal(Visitor visitor, VisitorProvider provider) {
    final destinationName = _destinationName(visitor, provider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: _bg,
      elevation: 0,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _muted.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isDarkMode ? kPrimaryLight : kPrimary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    visitor.name,
                                    style: GoogleFonts.afacad(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _text,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _pill(
                                    label:
                                        visitor.checkOutTime == null
                                            ? 'ON SITE'
                                            : 'CHECKED OUT',
                                    icon: Icons.circle,
                                    color:
                                        visitor.checkOutTime == null
                                            ? _ok
                                            : _muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildDetailSection('Personal Information', [
                          _buildDetailRow(
                            'ID Number',
                            visitor.identificationNumber ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'ID Type',
                            (visitor.identificationType ?? '')
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                          ),
                          _buildDetailRow('Phone', visitor.phoneNumber),
                          _buildDetailRow('Gender', visitor.gender ?? 'N/A'),
                          if (visitor.isMinor == true)
                            _buildDetailRow(
                              'Guardian Phone',
                              visitor.guardianPhone ?? 'N/A',
                            ),
                        ]),
                        const SizedBox(height: 12),
                        _buildDetailSection('Visit Information', [
                          _buildDetailRow('Destination', destinationName),
                          _buildDetailRow(
                            'Check-in Time',
                            visitor.checkInTime?.format(context) ??
                                'Not available',
                          ),
                          _buildDetailRow(
                            'Check-out Time',
                            visitor.checkOutTime?.format(context) ??
                                'Not checked out',
                          ),
                          _buildDetailRow(
                            'Host Type',
                            visitor.visitType?.toUpperCase() ?? 'N/A',
                          ),
                          _buildDetailRow(
                            'Appointment',
                            visitor.hadAppointment == true ? 'Yes' : 'No',
                          ),
                          if (visitor.appointmentDetails != null &&
                              visitor.appointmentDetails != 'N/A')
                            _buildDetailRow(
                              'Appointment Details',
                              visitor.appointmentDetails ?? '',
                            ),
                          if (visitor.remarks != null &&
                              visitor.remarks != 'N/A')
                            _buildDetailRow('Remarks', visitor.remarks ?? ''),
                          if (visitor.vehicleType != null ||
                              visitor.vehicleRegistration != null)
                            _buildDetailRow(
                              'Vehicle',
                              '${visitor.vehicleType ?? 'N/A'} (${visitor.vehicleRegistration ?? 'N/A'})',
                            ),
                        ]),
                        if (visitor.host != null &&
                            visitor.host!['name'] != null &&
                            visitor.host!['name'] != 'N/A') ...[
                          const SizedBox(height: 12),
                          _buildDetailSection('Host Information', [
                            _buildDetailRow(
                              'Name',
                              visitor.host!['name'] ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Phone',
                              visitor.host!['phone'] ?? 'N/A',
                            ),
                            if (visitor.host!['email'] != null &&
                                visitor.host!['email'] != 'N/A')
                              _buildDetailRow(
                                'Email',
                                visitor.host!['email'] ?? '',
                              ),
                            if (visitor.host!['department'] != null &&
                                visitor.host!['department'] != 'N/A')
                              _buildDetailRow(
                                'Department',
                                visitor.host!['department'] ?? '',
                              ),
                            if (visitor.host!['position'] != null &&
                                visitor.host!['position'] != 'N/A')
                              _buildDetailRow(
                                'Position',
                                visitor.host!['position'] ?? '',
                              ),
                          ]),
                        ],
                        if (visitor.officeName != null &&
                            visitor.officeName != 'N/A') ...[
                          const SizedBox(height: 12),
                          _buildDetailSection('Office Information', [
                            _buildDetailRow(
                              'Office Name',
                              visitor.officeName ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Phone',
                              visitor.officePhone ?? 'N/A',
                            ),
                            if (visitor.officeEmail != null &&
                                visitor.officeEmail != 'N/A')
                              _buildDetailRow(
                                'Email',
                                visitor.officeEmail ?? '',
                              ),
                            if (visitor.officeDepartment != null &&
                                visitor.officeDepartment != 'N/A')
                              _buildDetailRow(
                                'Department',
                                visitor.officeDepartment ?? '',
                              ),
                            if (visitor.officeContactPerson != null &&
                                visitor.officeContactPerson != 'N/A')
                              _buildDetailRow(
                                'Contact Person',
                                visitor.officeContactPerson ?? '',
                              ),
                          ]),
                        ],
                        const SizedBox(height: 20),
                        if (visitor.checkOutTime == null)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _showCheckoutConfirmation(
                                  visitor,
                                  provider,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: kWarning,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              label: Text(
                                'Check Out Visitor',
                                style: GoogleFonts.afacad(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.afacad(
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.afacad(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.afacad(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckoutConfirmation(
    Visitor visitor,
    VisitorProvider provider,
  ) async {
    _dialogAnimationController.forward();
    return showDialog(
      context: context,
      builder:
          (context) => ScaleTransition(
            scale: _scaleAnimation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: _surface,
              elevation: 0,
              contentPadding: const EdgeInsets.all(24),
              title: Text(
                'Confirm Check Out',
                style: GoogleFonts.afacad(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _warn.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.logout_rounded, size: 44, color: _warn),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to check out ${visitor.name}?',
                    style: GoogleFonts.afacad(fontSize: 16, color: _muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _tile,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: _muted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Check-in: ${visitor.checkInTime?.format(context) ?? 'Not available'}',
                            style: GoogleFonts.afacad(
                              fontSize: 14.5,
                              color: _text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await provider.checkOutVisitor(visitor);
                      _confettiController.play();
                      _snack(
                        '${visitor.name} checked out successfully',
                        kSuccess,
                      );
                    } catch (e) {
                      _snack('Failed to check out: ${e.toString()}', kDanger);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kWarning,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Check Out',
                    style: GoogleFonts.afacad(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
    ).whenComplete(() => _dialogAnimationController.reset());
  }

  void _toggleDarkMode() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
}

extension on DateTime? {
  String format(BuildContext context) {
    if (this == null) return 'Not available';
    try {
      final localTime = this!.toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(localTime);
    } catch (e) {
      return 'Invalid date';
    }
  }
}
