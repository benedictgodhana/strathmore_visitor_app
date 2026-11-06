import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../providers/visitor_provider.dart';
import '../models/visitor.dart';

// ── Brand ───────────────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFF02338D);
const Color kPrimaryLight = Color(0xFF2A5CAA);
const Color kPrimaryDark = Color(0xFF001A4A);
const Color kGold = Color(0xFFCC9C4A);
const Color kGoldLight = Color(0xFFE5B96B);
const Color kBgDarkNavy = Color(0xFF070F24);
const Color kSuccess = Color(0xFF047857);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);
const int kDailyGoal = 50;
const String kAppVersion = '3.2.1';
const String kPrivacyNotice =
    'Visitor data is processed per institutional privacy policy and the '
    "Kenya Data Protection Act, 2019.";

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ConfettiController _confettiController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int todaysTotalCount = 0;
  int currentlyIn = 0;
  int checkedOutToday = 0;
  bool isDarkMode = false;
  String selectedTimeRange = 'Today';
  String? deviceGate;
  String? gateId;
  String? _token;
  bool _isRefreshing = false;
  DateTime? _lastSync;
  Color get _bg => isDarkMode ? const Color(0xFF060B1A) : Colors.white;
  Color get _surface => isDarkMode ? const Color(0xFF0D1730) : Colors.white;
  Color get _tile =>
      isDarkMode ? const Color(0xFF14213F) : const Color(0xFFE8EEFB);
  Color get _stroke =>
      isDarkMode ? Colors.white.withOpacity(0.08) : kPrimary.withOpacity(0.10);
  Color get _text => isDarkMode ? const Color(0xFFF1F5FF) : kPrimaryDark;
  Color get _muted =>
      isDarkMode ? const Color(0xFF8FA0C4) : const Color(0xFF5B6B85);
  Color get _accent => isDarkMode ? kGoldLight : kPrimary;
  Color get _ok => isDarkMode ? kSignalGreen : kSuccess;
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUserPreferences();
      await _loadTokenFromPreferences();
      if (_token == null && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        await _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedGate = prefs.getString('device_gate') ?? 'Main Gate';
    if (mounted) {
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
        deviceGate = loadedGate;
      });
    }
  }

  Future<void> _loadTokenFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = prefs.getString('token');
      gateId = prefs.getString('gate_id');
      deviceGate = prefs.getString('device_gate') ?? 'Gate A';
    });
  }

  void _toggleDarkMode() async {
    if (mounted) setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
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
      setState(() {
        _token = null;
        gateId = null;
      });
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.afacad(fontSize: 16)),
        backgroundColor: kDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_token == null || gateId == null || deviceGate == null) {
      if (mounted) {
        _showError('Authentication token or gate information missing');
        if (_token == null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      }
      return;
    }
    bool isValidTokenFormat(String token) {
      final parts = token.split('|');
      return parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;
    }

    if (!isValidTokenFormat(_token!)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('gate_id');
      if (mounted) {
        setState(() {
          _token = null;
          gateId = null;
        });
        _showError('Invalid authentication token. Please log in again.');
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    final visitorProvider = Provider.of<VisitorProvider>(
      context,
      listen: false,
    );
    try {
      visitorProvider.setAuthData(_token!, gateId!, deviceGate ?? 'Gate A');
      await visitorProvider.loadCheckedInVisitors();
      await visitorProvider.logVisitCount(timeRange: selectedTimeRange);
      if (mounted) {
        setState(() {
          todaysTotalCount = visitorProvider.todaysTotalCount.toInt();
          currentlyIn = visitorProvider.checkedInCount;
          checkedOutToday = visitorProvider.checkedOutCount;
          _isRefreshing = false;
          _lastSync = DateTime.now();
        });
        final prefs = await SharedPreferences.getInstance();
        if (todaysTotalCount >= (prefs.getInt('confettiThreshold') ?? 20)) {
          _confettiController.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        String errorMessage = 'Failed to refresh data: $e';
        if (e.toString().contains('Status 401') ||
            e.toString().contains('Authentication failed')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('gate_id');
          setState(() {
            _token = null;
            gateId = null;
          });
          errorMessage =
              'Session expired or invalid token. Please log in again.';
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
        _showError(errorMessage);
      }
    }
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value:
            isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
              backgroundColor: isDarkMode ? kGoldLight : kPrimary,
              foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
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
                            onRefresh: _refreshData,
                            color: Colors.white,
                            backgroundColor: kPrimary,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                              child:
                                  _token == null
                                      ? _buildNotAuthenticated()
                                      : _buildBody(),
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
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
    return Drawer(
      backgroundColor: kBgDarkNavy,
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
                    height: 76,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.universityName,
                    style: GoogleFonts.afacad(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACCESS CONTROL',
                    style: GoogleFonts.afacad(
                      color: kGoldLight,
                      fontSize: 12.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
            item(
              Icons.local_shipping_outlined,
              'Goods Gate Pass',
              () => _go('/goods-gate-pass'),
            ),
            item(Icons.settings_outlined, 'Settings', () => _go('/settings')),
            const Spacer(),
            SwitchListTile(
              value: isDarkMode,
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
                  fontWeight: FontWeight.w700,
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
    final notificationCount =
        Provider.of<VisitorProvider>(context).visitors.length;
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
            'Home',
            style: GoogleFonts.afacad(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () {},
                icon: Icon(Icons.notifications_rounded, color: _text, size: 28),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kDanger,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 3,
          child:
              _isRefreshing
                  ? LinearProgressIndicator(
                    color: kGoldLight,
                    backgroundColor: Colors.transparent,
                  )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          'Hi, ${deviceGate ?? 'Operator'}!',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.afacad(
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 2),
        Text(greeting, style: GoogleFonts.afacad(fontSize: 18, color: _muted)),
        const SizedBox(height: 12),
        _buildSearchBar(),
        const SizedBox(height: 10),
        _buildWelcomeCard(),
        const SizedBox(height: 12),
        _sectionHeader('Quick Actions'),
        const SizedBox(height: 4),
        _buildQuickActions(),
        const SizedBox(height: 8),
        _sectionHeader(
          selectedTimeRange == 'Today'
              ? "Today's Overview"
              : "$selectedTimeRange's Overview",
        ),
        const SizedBox(height: 8),
        _buildOverviewGrid(),
        const SizedBox(height: 12),
        _buildRecentVisitors(),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded, size: 16, color: _muted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$kPrivacyNotice · v$kAppVersion',
                textAlign: TextAlign.center,
                style: GoogleFonts.afacad(fontSize: 13.5, color: _muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ActionSpec(
        'New Visitor',
        'assets/images/new_visitor.png',
        kPrimary,
        '/visitor-registration',
      ),
      _ActionSpec(
        'Check Out',
        'assets/images/checkout.png',
        kGold,
        '/check-out',
      ),
      _ActionSpec(
        'All Visitors',
        'assets/images/visitors.png',
        kPrimaryLight,
        '/visitor-list',
      ),
      _ActionSpec(
        'Verify ID',
        'assets/images/id.png',
        kGoldLight,
        '/lost-id-verification',
      ),
      _ActionSpec(
        'Goods Pass',
        'assets/images/goods_pass.png',
        kSignalGreen,
        '/goods-gate-pass',
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 78,
      ),
      itemBuilder: (_, i) => _quickActionTile(actions[i]),
    );
  }

  Widget _quickActionTile(_ActionSpec a) {
    final tint = isDarkMode && a.color == kPrimary ? kGoldLight : a.color;
    return InkWell(
      onTap: () => _go(a.route),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              a.imagePath,
              fit: BoxFit.contain,
              color: tint,
              colorBlendMode: BlendMode.srcIn,
              errorBuilder:
                  (_, __, ___) =>
                      Icon(Icons.local_shipping_rounded, color: tint, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            a.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => _go('/visitor-search'),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _tile.withOpacity(isDarkMode ? 0.7 : 0.55),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _stroke, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: _muted, size: 26),
            const SizedBox(width: 10),
            Text(
              'Search visitors',
              style: GoogleFonts.afacad(fontSize: 18, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return GestureDetector(
      onTap: () => _go('/visitor-registration'),
      child: Container(
        height: 132,
        padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome!',
                    style: GoogleFonts.afacad(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Let's register your\nnext visitor.",
                    style: GoogleFonts.afacad(
                      fontSize: 17,
                      height: 1.2,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 132, child: _welcomeIllustration()),
          ],
        ),
      ),
    );
  }

  Widget _welcomeIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _tile),
        ),
        Image.asset(
          'assets/images/visitor-man.png',
          width: 132,
          height: 132,
          fit: BoxFit.contain,
          color: _accent,
          colorBlendMode: BlendMode.srcIn,
        ),
      ],
    );
  }

  Widget _buildOverviewGrid() {
    final goalProgress = (todaysTotalCount / kDailyGoal).clamp(0.0, 1.0);
    double share(int n) =>
        todaysTotalCount > 0 ? (n / todaysTotalCount).clamp(0.0, 1.0) : 0.0;
    final cards = [
      _OverviewSpec(
        Icons.groups_rounded,
        'Total Visitors',
        '$todaysTotalCount logged',
        'Goal progress',
        goalProgress,
        selected: true,
      ),
      _OverviewSpec(
        Icons.directions_walk_rounded,
        'Currently In',
        '$currentlyIn on site',
        'Share of total',
        share(currentlyIn),
      ),
      _OverviewSpec(
        Icons.logout_rounded,
        'Checked Out',
        '$checkedOutToday departed',
        'Share of total',
        share(checkedOutToday),
      ),
      _OverviewSpec(
        Icons.flag_rounded,
        'Daily Goal',
        '${(kDailyGoal - todaysTotalCount).clamp(0, kDailyGoal)} to go',
        'Remaining',
        1 - goalProgress,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 176,
      ),
      itemBuilder: (_, i) => _overviewCard(cards[i]),
    );
  }

  Widget _overviewCard(_OverviewSpec s) {
    final sel = s.selected;
    final bg = sel ? (isDarkMode ? kPrimaryLight : kPrimary) : _tile;
    final fg = sel ? Colors.white : _text;
    final sub = sel ? Colors.white70 : _muted;
    final barColor = sel ? Colors.white : _accent;
    final date = DateFormat('MMM d, yyyy').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  style: GoogleFonts.afacad(fontSize: 13.5, color: sub),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: 'Time range',
                icon: Icon(Icons.more_vert_rounded, size: 20, color: sub),
                onSelected: (r) {
                  setState(() => selectedTimeRange = r);
                  _refreshData();
                },
                itemBuilder:
                    (_) => [
                      for (final r in ['Today', 'This Week', 'This Month'])
                        PopupMenuItem(
                          value: r,
                          child: Text(
                            r,
                            style: GoogleFonts.afacad(
                              fontSize: 16,
                              fontWeight:
                                  r == selectedTimeRange
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Icon(s.icon, color: fg, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.afacad(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      Text(
                        s.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.afacad(fontSize: 14, color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.progressLabel,
                  style: GoogleFonts.afacad(fontSize: 13.5, color: sub),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: s.progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder:
                      (_, v, __) => Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                backgroundColor:
                                    sel
                                        ? Colors.white.withOpacity(0.25)
                                        : Colors.white,
                                valueColor: AlwaysStoppedAnimation(barColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(s.progress * 100).round()}%',
                    style: GoogleFonts.afacad(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: sub,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVisitors() {
    return Consumer<VisitorProvider>(
      builder: (context, visitorProvider, _) {
        final recent =
            visitorProvider.visitors
                .where((v) => v.gate == deviceGate || v.gateId == gateId)
                .take(5)
                .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Recent Check-Ins',
              trailing: 'View all',
              onTrailing: () => _go('/visitor-list'),
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: _tile,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, size: 44, color: _muted),
                    const SizedBox(height: 10),
                    Text(
                      'No recent visitors',
                      style: GoogleFonts.afacad(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    Text(
                      'Check-ins will appear here.',
                      style: GoogleFonts.afacad(fontSize: 15, color: _muted),
                    ),
                  ],
                ),
              )
            else
              for (final v in recent) _visitorRow(v),
          ],
        );
      },
    );
  }

  Widget _visitorRow(Visitor visitor) {
    final active = visitor.checkOutTime == null;
    final c = active ? _ok : _muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            () => Navigator.pushNamed(
              context,
              '/visitor-details',
              arguments: visitor,
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.withOpacity(0.6), width: 1.5),
                ),
                child: Image.asset(
                  'assets/images/user.png',
                  fit: BoxFit.contain,
                  color: c,
                  colorBlendMode: BlendMode.srcIn,
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
                    Text(
                      visitor.phoneNumber.isNotEmpty
                          ? visitor.phoneNumber
                          : 'No phone',
                      style: GoogleFonts.afacad(fontSize: 15, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? 'ON SITE' : 'OUT',
                  style: GoogleFonts.afacad(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title, {
    String? trailing,
    VoidCallback? onTrailing,
  }) {
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
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              trailing,
              style: GoogleFonts.afacad(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotAuthenticated() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _tile,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: _muted),
            const SizedBox(height: 16),
            Text(
              'Not Authenticated',
              style: GoogleFonts.afacad(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed:
                  () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  ),
              style: FilledButton.styleFrom(
                backgroundColor: isDarkMode ? kGoldLight : kPrimary,
                foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Go to Login',
                style: GoogleFonts.afacad(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSpec {
  final String title;
  final String imagePath;
  final Color color;
  final String route;
  _ActionSpec(this.title, this.imagePath, this.color, this.route);
}

class _OverviewSpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final bool selected;
  _OverviewSpec(
    this.icon,
    this.title,
    this.subtitle,
    this.progressLabel,
    this.progress, {
    this.selected = false,
  });
}