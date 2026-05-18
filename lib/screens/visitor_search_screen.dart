import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class VisitorSearchScreen extends StatefulWidget {
  const VisitorSearchScreen({super.key});

  @override
  State<VisitorSearchScreen> createState() => _VisitorSearchScreenState();
}

class _VisitorSearchScreenState extends State<VisitorSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchType = 'identification_number';
  String _selectedIdType = 'national_id';
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  String? _error;
  String? _token;

  final List<Map<String, String>> _idTypeOptions = [
    {'value': 'national_id', 'label': 'National ID'},
    {'value': 'passport_number', 'label': 'Passport Number'},
    {'value': 'birth_certificate_number', 'label': 'Birth Certificate'},
    {'value': 'driving_licence', 'label': 'Driving Licence'},
  ];

  final List<Map<String, String>> _searchTypeOptions = [
    {'value': 'identification_number', 'label': 'Search by ID Number'},
    {'value': 'name', 'label': 'Search by Name'},
  ];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('token');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchVisitor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _searchResults = [];
    });

    try {
      final searchValue = _searchController.text.trim();
      String url;
      Map<String, dynamic> requestBody;

      if (_searchType == 'identification_number') {
        // Use the search endpoint for ID search
        url = '${AppStrings.apiBaseUrl}/api/identification-types/search';
        requestBody = {
          'identification_type': _selectedIdType,
          'identification_number': searchValue,
        };
      } else {
        // Use the search-by-name endpoint for name search
        url =
            '${AppStrings.apiBaseUrl}/api/identification-types/search-by-name';
        requestBody = {'name': searchValue};
      }

      debugPrint('📤 Sending search request to: $url');
      debugPrint('📤 Request body: ${jsonEncode(requestBody)}');

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

      debugPrint(
        '📥 Search response: ${response.statusCode}, ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            if (_searchType == 'identification_number') {
              // ID search returns single visitor in 'visitor' field
              if (data['visitor'] != null) {
                _searchResults = [data['visitor']];
              } else {
                _error = 'No visitor found with this ID number';
              }
            } else {
              // Name search returns multiple visitors in 'visitors' array
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
          setState(() {
            _error = data['message'] ?? 'No visitors found';
          });
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Visitor',
          style: TextStyle(fontFamily: 'BrandonGrotesque'),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Search Type Selector
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children:
                                  _searchTypeOptions.map((type) {
                                    final isSelected =
                                        _searchType == type['value'];
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _searchType = type['value']!;
                                            _searchController.clear();
                                            _searchResults = [];
                                            _error = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? AppColors.primaryBlue
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              type['label']!,
                                              style: TextStyle(
                                                fontFamily: 'BrandonGrotesque',
                                                color:
                                                    isSelected
                                                        ? Colors.white
                                                        : Colors.grey.shade700,
                                                fontWeight:
                                                    isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
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

                          // ID Type Dropdown (only for ID search)
                          if (_searchType == 'identification_number') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedIdType,
                              decoration: InputDecoration(
                                labelText: 'ID Type',
                                labelStyle: const TextStyle(
                                  fontFamily: 'BrandonGrotesque',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items:
                                  _idTypeOptions.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type['value'],
                                      child: Text(
                                        type['label']!,
                                        style: const TextStyle(
                                          fontFamily: 'BrandonGrotesque',
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedIdType = val);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Search Input Field
                          TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText:
                                  _searchType == 'identification_number'
                                      ? 'ID Number'
                                      : 'Full Name',
                              hintText:
                                  _searchType == 'identification_number'
                                      ? 'Enter ID number (e.g., 12345678)'
                                      : 'Enter visitor name (at least 2 characters)',
                              labelStyle: const TextStyle(
                                fontFamily: 'BrandonGrotesque',
                              ),
                              hintStyle: TextStyle(
                                fontFamily: 'BrandonGrotesque',
                                color: Colors.grey.shade400,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: Icon(
                                _searchType == 'identification_number'
                                    ? Icons.badge
                                    : Icons.person,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            style: const TextStyle(
                              fontFamily: 'BrandonGrotesque',
                            ),
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
                          const SizedBox(height: 16),

                          // Search Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _searchVisitor,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'BrandonGrotesque',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Text('Search'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Error Message
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'BrandonGrotesque',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildVisitorCard(_searchResults[index]),
                        childCount: _searchResults.length,
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

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    // Extract tag information
    final Map<String, dynamic> tagData =
        visitor['tag'] is Map ? visitor['tag'] as Map<String, dynamic> : {};
    final String tagNumber = tagData['tag_number']?.toString() ?? '-';

    // Get values safely
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.primaryBlue,
            size: 28,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontFamily: 'BrandonGrotesque',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: $idNumber',
              style: const TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tag: $tagNumber',
                style: const TextStyle(
                  fontFamily: 'BrandonGrotesque',
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: const Chip(
          label: Text(
            'Visitor',
            style: TextStyle(fontFamily: 'BrandonGrotesque', fontSize: 11),
          ),
          backgroundColor: Colors.grey,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Information Section
                _buildSectionHeader(
                  'Personal Information',
                  Icons.person_outline,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Full Name', name),
                _buildInfoRow('ID Type', _getIdTypeLabel(identificationType)),
                _buildInfoRow('ID Number', idNumber),
                _buildInfoRow('Phone Number', phoneNumber),
                _buildInfoRow('Gender', gender),
                _buildInfoRow('Country', country),

                const SizedBox(height: 16),

                // Visit Information Section
                _buildSectionHeader('Visit Information', Icons.work_outline),
                const SizedBox(height: 8),
                _buildInfoRow('Gate', latestVisitGate),
                _buildInfoRow('Destination', latestVisitDestination),
                _buildInfoRow('Check-in Time', createdAt),
                _buildInfoRow('Last Updated', updatedAt),

                const SizedBox(height: 16),

                // Tag Information Section
                _buildSectionHeader('Tag Information', Icons.qr_code),
                const SizedBox(height: 8),
                _buildInfoRow('Tag Number', tagNumber),
                _buildInfoRow(
                  'Tag Status',
                  tagData['is_assigned'] == true ? 'Assigned' : 'Unassigned',
                ),

                // Remarks Section
                if (latestVisitRemarks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                    'Latest Visit Remarks',
                    Icons.comment_outlined,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      latestVisitRemarks,
                      style: const TextStyle(
                        fontFamily: 'BrandonGrotesque',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],

                if (visitorRemarks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('Visitor Remarks', Icons.note_outlined),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      visitorRemarks,
                      style: const TextStyle(
                        fontFamily: 'BrandonGrotesque',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'BrandonGrotesque',
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
            fontSize: 15,
          ),
        ),
        const Expanded(child: SizedBox()),
        Container(width: 40, height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'BrandonGrotesque',
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontSize: 13,
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
    return types[value] ?? value;
  }
}
