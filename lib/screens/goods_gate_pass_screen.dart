import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Brand (identical to HomeScreen) ──────────────────────────────────────
const Color kPrimary = Color(0xFF02338D);
const Color kPrimaryLight = Color(0xFF2A5CAA);
const Color kPrimaryDark = Color(0xFF001A4A);
const Color kGold = Color(0xFFCC9C4A);
const Color kGoldLight = Color(0xFFE5B96B);
const Color kBgDarkNavy = Color(0xFF070F24);
const Color kSuccess = Color(0xFF047857);
const Color kDanger = Color(0xFFB91C1C);
const Color kSignalGreen = Color(0xFF34D399);
const String kAppVersion = '3.2.1';
const String kPrivacyNotice =
    'Visitor data is processed per institutional privacy policy and the '
    "Kenya Data Protection Act, 2019.";

const String _gatePassEndpoint =
    'http://192.168.190.228:8084/api/v1/dynamic/gate-pass';

class GoodsGatePassScreen extends StatefulWidget {
  const GoodsGatePassScreen({super.key});

  @override
  State<GoodsGatePassScreen> createState() => _GoodsGatePassScreenState();
}

class _GoodsGatePassScreenState extends State<GoodsGatePassScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isDarkMode = false;
  bool _isLoading = true;
  String? _error;
  List<GatePass> _passes = [];

  // ── Theme tokens (identical to HomeScreen) ─────────────────────────────
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
      await _load();
    });
  }

  // ── Network ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse(_gatePassEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['success'] != true || decoded['data'] == null) {
        throw Exception('Unexpected response shape');
      }

      final rawList = decoded['data'] as List;
      final parsed = rawList
          .whereType<Map>()
          .map((m) => GatePass.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _passes = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleDarkMode() async {
    if (mounted) setState(() => isDarkMode = !isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
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
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: Colors.white,
                        backgroundColor: kPrimary,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 48),
                          child: _buildBody(),
                        ),
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

  // ── Drawer (identical to HomeScreen, minus Check Out) ──────────────────
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
                    'Strathmore University',
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
            item(Icons.grid_view_rounded, 'Home', _goHome),
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Top bar (identical to HomeScreen) ──────────────────────────────────
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
            'Goods Gate Pass',
            style: GoogleFonts.afacad(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
            icon: Icon(Icons.refresh_rounded, color: _text, size: 28),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 3,
          child:
              _isLoading
                  ? LinearProgressIndicator(
                    color: kGoldLight,
                    backgroundColor: Colors.transparent,
                  )
                  : null,
        ),
        const SizedBox(height: 8),
        _sectionHeader('Overview'),
        const SizedBox(height: 8),
        _buildOverviewGrid(),
        const SizedBox(height: 16),
        _sectionHeader('All Gate Passes'),
        const SizedBox(height: 8),
        if (_isLoading)
          _buildLoadingTile()
        else if (_error != null)
          _buildErrorTile()
        else if (_passes.isEmpty)
          _buildEmptyTile()
        else
          ..._passes.map((p) => _buildPassTile(p)),
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

  // ── Overview grid (mirrors HomeScreen's 2×2 _OverviewSpec) ─────────────
  Widget _buildOverviewGrid() {
    final total = _passes.length;
    final finalised =
        _passes.where((p) => p.status.toUpperCase() == 'FINALISED').length;
    final attachments =
        _passes.fold<int>(0, (sum, p) => sum + p.attachments.length);
    final items = _passes.fold<int>(0, (sum, p) => sum + p.items.length);

    final date = DateFormat('MMM d, yyyy').format(DateTime.now());

    final cards = [
      _PassStatSpec(
        Icons.receipt_long_rounded,
        'Total Passes',
        '$total recorded',
        '$finalised finalised',
        1.0,
        selected: true,
        date: date,
      ),
      _PassStatSpec(
        Icons.check_circle_rounded,
        'Finalised',
        '$finalised approved',
        'All passes',
        total > 0 ? finalised / total : 0.0,
        date: date,
      ),
      _PassStatSpec(
        Icons.inventory_2_rounded,
        'Items',
        '$items logged',
        'Across all passes',
        1.0,
        date: date,
      ),
      _PassStatSpec(
        Icons.attach_file_rounded,
        'Attachments',
        '$attachments files',
        'Supporting docs',
        1.0,
        date: date,
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

  Widget _overviewCard(_PassStatSpec s) {
    final sel = s.selected;
    final bg = sel ? (isDarkMode ? kPrimaryLight : kPrimary) : _tile;
    final fg = sel ? Colors.white : _text;
    final sub = sel ? Colors.white70 : _muted;
    final barColor = sel ? Colors.white : _accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              s.date,
              style: GoogleFonts.afacad(fontSize: 13.5, color: sub),
            ),
          ),
          const SizedBox(height: 6),
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
                  tween: Tween(begin: 0, end: s.progress.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder:
                      (_, v, __) => ClipRRect(
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

  // ── Loading / error / empty tiles (mirror _tile style) ─────────────────
  Widget _buildLoadingTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Fetching gate passes…',
            style: GoogleFonts.afacad(fontSize: 15, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: _muted),
          const SizedBox(height: 10),
          Text(
            'Could not load gate passes',
            style: GoogleFonts.afacad(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.afacad(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Try again',
              style: GoogleFonts.afacad(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: isDarkMode ? kGoldLight : kPrimary,
              foregroundColor: isDarkMode ? kPrimaryDark : Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.local_shipping_outlined, size: 44, color: _muted),
          const SizedBox(height: 10),
          Text(
            'No gate passes yet',
            style: GoogleFonts.afacad(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          Text(
            'Finalised gate passes will appear here.',
            style: GoogleFonts.afacad(fontSize: 15, color: _muted),
          ),
        ],
      ),
    );
  }

  // ── Pass tile (mirrors _visitorRow structure) ─────────────────────────
  Widget _buildPassTile(GatePass p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — avatar + name/email + status pill
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
                    color: _accent.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  p.userName.isNotEmpty
                      ? p.userName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.afacad(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.afacad(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    Text(
                      p.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.afacad(
                        fontSize: 15,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(p.status),
            ],
          ),
          const SizedBox(height: 12),

          // Meta row — date + department
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                Icons.schedule_rounded,
                DateFormat('d MMM · HH:mm').format(p.createdAt.toLocal()),
              ),
              if (p.departmentShortName.isNotEmpty)
                _metaChip(Icons.apartment_rounded, p.departmentShortName),
            ],
          ),

          // Items
          if (p.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...p.items.map(_buildItemRow),
          ],

          // Attachments
          if (p.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...p.attachments.map(_buildAttachmentRow),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(GatePassItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              item.numberOfItems?.toString() ?? '–',
              style: GoogleFonts.afacad(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.description.isNotEmpty)
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.afacad(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                if (item.serialNumber.isNotEmpty)
                  Text(
                    'SN: ${item.serialNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.afacad(
                      fontSize: 13,
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

  Widget _buildAttachmentRow(GatePassAttachment a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openAttachment(a),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    a.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.insert_drive_file_rounded,
                    size: 18,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.afacad(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      Text(
                        _formatBytes(a.sizeInBytes),
                        style: GoogleFonts.afacad(
                          fontSize: 13,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded, size: 18, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  Widget _statusPill(String status) {
    final isFinal = status.toUpperCase() == 'FINALISED';
    final c = isFinal ? _ok : kGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.afacad(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _muted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.afacad(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.afacad(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: _text,
      ),
    );
  }

  Future<void> _openAttachment(GatePassAttachment a) async {
    HapticFeedback.selectionClick();
    final rewritten = a.downloadUrl.replaceFirst(
      RegExp(r'https?://localhost'),
      'http://192.168.190.228',
    );
    final uri = Uri.tryParse(rewritten);
    if (uri == null) {
      _toast('Invalid attachment URL');
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open attachment');
    } catch (e) {
      _toast('Could not open attachment');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.afacad(fontSize: 16)),
        backgroundColor: kDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '–';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// ── Data models (unchanged) ─────────────────────────────────────────────
class GatePass {
  final String id;
  final DateTime createdAt;
  final String status;
  final String formName;
  final String userName;
  final String userEmail;
  final String department;
  final String departmentShortName;
  final List<GatePassItem> items;
  final List<GatePassAttachment> attachments;

  GatePass({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.formName,
    required this.userName,
    required this.userEmail,
    required this.department,
    required this.departmentShortName,
    required this.items,
    required this.attachments,
  });

  factory GatePass.fromJson(Map<String, dynamic> json) {
    final fr = (json['fields_responses'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final items = <GatePassItem>[];
    final rawItems = fr['Items'];
    if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key == 'footer') return;
            if (value is Map) {
              items.add(
                GatePassItem.fromJson(Map<String, dynamic>.from(value)),
              );
            }
          });
        }
      } catch (_) {}
    }

    final attachments = <GatePassAttachment>[];
    final rawAttachments = fr['attachments'];
    if (rawAttachments is List) {
      for (final a in rawAttachments) {
        if (a is Map) {
          attachments.add(
            GatePassAttachment.fromJson(Map<String, dynamic>.from(a)),
          );
        }
      }
    }

    return GatePass(
      id: json['id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      formName: json['form_name']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userEmail: json['user_email']?.toString() ?? '',
      department: fr['deparment']?.toString() ??
          fr['department']?.toString() ??
          '',
      departmentShortName: fr['department_short_name']?.toString() ?? '',
      items: items,
      attachments: attachments,
    );
  }
}

class GatePassItem {
  final int? numberOfItems;
  final String description;
  final String serialNumber;

  GatePassItem({
    required this.numberOfItems,
    required this.description,
    required this.serialNumber,
  });

  factory GatePassItem.fromJson(Map<String, dynamic> json) {
    final raw = json['number_of_items'];
    int? n;
    if (raw is int) n = raw;
    if (raw is String) n = int.tryParse(raw);
    return GatePassItem(
      numberOfItems: n,
      description: json['description']?.toString() ?? '',
      serialNumber: json['serial_number']?.toString() ?? '',
    );
  }
}

class GatePassAttachment {
  final String downloadUrl;
  final String name;
  final String description;
  final String mimeType;
  final int sizeInBytes;

  GatePassAttachment({
    required this.downloadUrl,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.sizeInBytes,
  });

  bool get isPdf => mimeType.toLowerCase().contains('pdf');

  factory GatePassAttachment.fromJson(Map<String, dynamic> json) {
    return GatePassAttachment(
      downloadUrl: json['download_url']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Attachment',
      description: json['description']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      sizeInBytes: int.tryParse(json['size_in_bytes']?.toString() ?? '0') ?? 0,
    );
  }
}

// ── Stat spec ───────────────────────────────────────────────────────────
class _PassStatSpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final bool selected;
  final String date;
  _PassStatSpec(
    this.icon,
    this.title,
    this.subtitle,
    this.progressLabel,
    this.progress, {
    this.selected = false,
    required this.date,
  });
}