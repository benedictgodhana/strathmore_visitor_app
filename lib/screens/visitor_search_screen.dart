import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

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

class VisitorSearchScreen extends StatefulWidget {
  const VisitorSearchScreen({super.key});
  @override
  State<VisitorSearchScreen> createState() => _VisitorSearchScreenState();
}

class _VisitorSearchScreenState extends State<VisitorSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'identification_number';
  String _selectedIdType = 'national_id';
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _error;
  String? _token;
  bool _isDarkMode = false;
  bool _hasSearched = false;
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
  final List<Map<String, String>> _idTypeOptions = [
    {'value': 'national_id', 'label': 'National ID'},
    {'value': 'passport_number', 'label': 'Passport Number'},
    {'value': 'birth_certificate_number', 'label': 'Birth Certificate'},
    {'value': 'driving_licence', 'label': 'Driving Licence'},
  ];
  final List<Map<String, String>> _searchTypeOptions = [
    {'value': 'identification_number', 'label': 'By ID Number'},
    {'value': 'name', 'label': 'By Name'},
  ];
  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('token');
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _searchVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults = [];
      _hasSearched = true;
    });
    try {
      final searchValue = _searchController.text.trim();
      String url;
      Map<String, dynamic> requestBody;
      if (_searchType == 'identification_number') {
        url = '${AppStrings.apiBaseUrl}/api/identification-types/search';
        requestBody = {
          'identification_type': _selectedIdType,
          'identification_number': searchValue,
        };
      } else {
        url =
            '${AppStrings.apiBaseUrl}/api/identification-types/search-by-name';
        requestBody = {'name': searchValue};
      }
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            if (_searchType == 'identification_number') {
              if (data['visitor'] != null) {
                _searchResults = [data['visitor']];
              } else {
                _error = 'No visitor found with this ID number';
              }
            } else {
              if (data['visitors'] != null && data['visitors'].isNotEmpty) {
                _searchResults = List<Map<String, dynamic>>.from(
                  data['visitors'],
                );
              } else {
                _error = 'No visitors found matching the name';
              }
            }
          });
        }
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => _error = data['message'] ?? 'No visitors found');
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _error = errorData['message'] ?? 'Search failed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Network error: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPageHeader(),
                            const SizedBox(height: 12),
                            _buildSearchForm(),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _buildErrorBanner(_error!),
                            ],
                            if (_searchResults.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildResultsHeader(),
                              const SizedBox(height: 8),
                              for (final visitor in _searchResults)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildVisitorCard(visitor),
                                ),
                            ] else if (_hasSearched &&
                                _error == null &&
                                !_isLoading) ...[
                              const SizedBox(height: 14),
                              _buildNoResults(),
                            ],
                            const SizedBox(height: 20),
                            _buildComplianceFooter(),
                          ],
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
                    'RECORD SEARCH',
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
            'Search Records',
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

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find a record',
          style: GoogleFonts.afacad(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Look up visitor records by ID number or full name.',
          style: GoogleFonts.afacad(fontSize: 16, color: _muted),
        ),
      ],
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke, width: 1.2),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEARCH BY',
              style: GoogleFonts.afacad(
                fontSize: 12.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _tile.withOpacity(_isDarkMode ? 0.7 : 0.55),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children:
                    _searchTypeOptions.map((type) {
                      final isSelected = _searchType == type['value'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _searchType = type['value']!;
                              _searchController.clear();
                              _searchResults = [];
                              _error = null;
                              _hasSearched = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Center(
                              child: Text(
                                type['label']!,
                                style: GoogleFonts.afacad(
                                  fontSize: 15,
                                  color:
                                      isSelected
                                          ? (_isDarkMode
                                              ? kPrimaryDark
                                              : Colors.white)
                                          : _muted,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_searchType == 'identification_number') ...[
              Text(
                'ID TYPE',
                style: GoogleFonts.afacad(
                  fontSize: 12.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _tile.withOpacity(_isDarkMode ? 0.7 : 0.55),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedIdType,
                    isExpanded: true,
                    icon: Icon(Icons.expand_more_rounded, color: _muted),
                    dropdownColor: _surface,
                    borderRadius: BorderRadius.circular(14),
                    style: GoogleFonts.afacad(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                    items:
                        _idTypeOptions.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'],
                            child: Text(
                              type['label']!,
                              style: GoogleFonts.afacad(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _text,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIdType = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _searchType == 'identification_number'
                  ? 'ID NUMBER'
                  : 'FULL NAME',
              style: GoogleFonts.afacad(
                fontSize: 12.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _searchVisitor(),
              decoration: InputDecoration(
                hintText:
                    _searchType == 'identification_number'
                        ? 'Enter ID number (e.g., 12345678)'
                        : 'Enter visitor name (at least 2 characters)',
                hintStyle: GoogleFonts.afacad(color: _muted, fontSize: 16),
                filled: true,
                fillColor: _tile.withOpacity(_isDarkMode ? 0.7 : 0.55),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                prefixIcon: Icon(
                  _searchType == 'identification_number'
                      ? Icons.badge_outlined
                      : Icons.person_outline_rounded,
                  color: _muted,
                  size: 24,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: _accent, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: kDanger),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: kDanger, width: 1.5),
                ),
              ),
              style: GoogleFonts.afacad(fontSize: 17, color: _text),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return _searchType == 'identification_number'
                      ? 'Please enter an ID number'
                      : 'Please enter a name';
                }
                if (_searchType == 'name' && val.length < 2) {
                  return 'Please enter at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchVisitor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _isDarkMode ? kPrimaryDark : Colors.white,
                  disabledBackgroundColor: _accent.withOpacity(0.5),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                icon:
                    _isLoading
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.search_rounded, size: 22),
                label: Text(
                  _isLoading ? 'Searching…' : 'Search',
                  style: GoogleFonts.afacad(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kDanger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDanger.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kDanger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.afacad(
                color: kDanger,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Search Results',
          style: GoogleFonts.afacad(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _ok.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 14, color: _ok),
              const SizedBox(width: 5),
              Text(
                '${_searchResults.length} found',
                style: GoogleFonts.afacad(
                  fontSize: 12,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w800,
                  color: _ok,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _surface, shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded, size: 44, color: _muted),
          ),
          const SizedBox(height: 14),
          Text(
            'No Records Found',
            style: GoogleFonts.afacad(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different ID number, name, or ID type.',
            textAlign: TextAlign.center,
            style: GoogleFonts.afacad(fontSize: 15, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final Map<String, dynamic> tagData =
        visitor['tag'] is Map ? visitor['tag'] as Map<String, dynamic> : {};
    final String tagNumber = tagData['tag_number']?.toString() ?? '-';
    final String name = visitor['name']?.toString() ?? 'Unknown Visitor';
    final String idNumber = visitor['identification_number']?.toString() ?? '-';
    final String phoneNumber = visitor['phone_number']?.toString() ?? '-';
    final String gender = visitor['gender']?.toString() ?? 'Not specified';
    final String country = visitor['country']?.toString() ?? 'Not specified';
    final String identificationType =
        visitor['identification_type']?.toString() ?? '';
    final String latestVisitGate =
        visitor['latest_visit_gate']?.toString() ?? '-';
    final String latestVisitDestination =
        visitor['latest_visit_destination']?.toString() ?? '-';
    final String latestVisitRemarks =
        visitor['latest_visit_remarks']?.toString() ?? '';
    final String visitorRemarks = visitor['visitor_remarks']?.toString() ?? '';
    final String createdAt = visitor['created_at']?.toString() ?? '-';
    final String updatedAt = visitor['updated_at']?.toString() ?? '-';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          iconColor: _muted,
          collapsedIconColor: _muted,
          leading: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withOpacity(0.5), width: 1.5),
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
          title: Text(
            name,
            style: GoogleFonts.afacad(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _text,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 14, color: _muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'ID: $idNumber',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.afacad(fontSize: 14, color: _muted),
                  ),
                ),
                if (tagNumber != '-') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TAG $tagNumber',
                      style: GoogleFonts.afacad(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'VISITOR',
              style: GoogleFonts.afacad(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: _stroke)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Personal Information', [
                    _buildInfoRow('Full Name', name),
                    _buildInfoRow(
                      'ID Type',
                      _getIdTypeLabel(identificationType),
                    ),
                    _buildInfoRow('ID Number', idNumber),
                    _buildInfoRow('Phone Number', phoneNumber),
                    _buildInfoRow('Gender', gender),
                    _buildInfoRow('Country', country),
                  ]),
                  const SizedBox(height: 10),
                  _buildDetailSection('Visit Information', [
                    _buildInfoRow('Gate', latestVisitGate),
                    _buildInfoRow('Destination', latestVisitDestination),
                    _buildInfoRow('Check-in Time', createdAt),
                    _buildInfoRow('Last Updated', updatedAt),
                  ]),
                  const SizedBox(height: 10),
                  _buildDetailSection('Tag Information', [
                    _buildInfoRow('Tag Number', tagNumber),
                    _buildInfoRow(
                      'Tag Status',
                      tagData['is_assigned'] == true
                          ? 'Assigned'
                          : 'Unassigned',
                    ),
                  ]),
                  if (latestVisitRemarks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildRemarksBlock(
                      'Latest Visit Remarks',
                      latestVisitRemarks,
                    ),
                  ],
                  if (visitorRemarks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildRemarksBlock('Visitor Remarks', visitorRemarks),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.afacad(
              fontSize: 13,
              letterSpacing: 1.0,
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

  Widget _buildRemarksBlock(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.afacad(
              fontSize: 13,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.afacad(fontSize: 15, color: _text, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                fontWeight: FontWeight.w600,
                color: _muted,
                fontSize: 14.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.afacad(
                fontWeight: FontWeight.w700,
                color: _text,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getIdTypeLabel(String value) {
    const types = {
      'national_id': 'National ID',
      'passport_number': 'Passport Number',
      'birth_certificate_number': 'Birth Certificate',
      'driving_licence': 'Driving Licence',
    };
    return types[value] ?? (value.isEmpty ? 'N/A' : value);
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
}
