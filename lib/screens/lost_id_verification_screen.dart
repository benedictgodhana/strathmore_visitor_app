import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../components/custom_app_bar.dart';
import '../providers/visitor_provider.dart';

class IdentityVerificationScreen extends StatefulWidget {
  @override
  _IdentityVerificationScreenState createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _staffNoController = TextEditingController();
  String _verificationType = 'student'; // Default to student verification
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  Map<String, dynamic>? _identityData;
  List<Map<String, dynamic>> _recentVerifications = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  // Load saved data from SharedPreferences
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVerificationType = prefs.getString('verification_type');
      if (savedVerificationType != null) {
        setState(() {
          _verificationType = savedVerificationType;
        });
      }
      final savedStudentId = prefs.getString('last_student_id');
      final savedUsername = prefs.getString('last_username');
      final savedStaffNo = prefs.getString('last_staff_no');
      if (savedStudentId != null && _verificationType == 'student') {
        _studentIdController.text = savedStudentId;
      }
      if (savedUsername != null && _verificationType == 'username') {
        _usernameController.text = savedUsername;
      }
      if (savedStaffNo != null && _verificationType == 'staffNo') {
        _staffNoController.text = savedStaffNo;
      }
      await _loadRecentVerifications();
    } catch (e) {
      print('Error loading saved data: $e');
    }
  }

  // Save data to SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verification_type', _verificationType);
      if (_verificationType == 'student' && _studentIdController.text.isNotEmpty) {
        await prefs.setString('last_student_id', _studentIdController.text);
      }
      if (_verificationType == 'username' && _usernameController.text.isNotEmpty) {
        await prefs.setString('last_username', _usernameController.text);
      }
      if (_verificationType == 'staffNo' && _staffNoController.text.isNotEmpty) {
        await prefs.setString('last_staff_no', _staffNoController.text);
      }
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  // Save successful verification to history
  Future<void> _saveVerificationHistory(Map<String, dynamic> verificationData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      final newEntry = {
        'type': verificationData['type'],
        'id': verificationData['type'] == 'student' ? verificationData['studentId'] : verificationData['staffNo'],
        'name': verificationData['name'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      historyList.insert(0, jsonEncode(newEntry));
      if (historyList.length > 10) {
        historyList.removeRange(10, historyList.length);
      }
      await prefs.setStringList('verification_history', historyList);
    } catch (e) {
      print('Error saving verification history: $e');
    }
  }

  // Load recent verifications
  Future<void> _loadRecentVerifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('verification_history') ?? [];
      setState(() {
        _recentVerifications = historyList.map((entry) {
          final decoded = jsonDecode(entry);
          return <String, dynamic>{
            'display': '${decoded['type']} ID: ${decoded['id']} (${decoded['name']})',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading recent verifications: $e');
    }
  }

  // Clear all saved data
  Future<void> _clearAllSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('verification_type');
      await prefs.remove('last_student_id');
      await prefs.remove('last_username');
      await prefs.remove('last_staff_no');
      await prefs.remove('verification_history');
      setState(() {
        _recentVerifications.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All saved data cleared'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      print('Error clearing saved data: $e');
    }
  }

  Future<void> _verifyIdentity() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
        _identityData = null;
      });

      try {
        await _saveData();
        final visitorProvider = Provider.of<VisitorProvider>(context, listen: false);
        Map<String, dynamic> result;
        if (_verificationType == 'student') {
          result = await visitorProvider.verifyIdentity(studentId: _studentIdController.text);
        } else if (_verificationType == 'username') {
          result = await visitorProvider.verifyIdentity(username: _usernameController.text);
        } else {
          result = await visitorProvider.verifyIdentity(staffNo: _staffNoController.text);
        }

        if (result['success']) {
          final identityData = {
            'type': result['type'],
            if (result['type'] == 'student') ...{
              'studentId': result['studentId'],
              'name': result['name'] ?? 'Unknown',
              'surname': result['surname'] ?? 'N/A',
              'otherNames': result['otherNames'] ?? 'N/A',
              'gender': result['gender'] ?? 'N/A',
              'dateOfBirth': result['dateOfBirth'] ?? 'N/A',
              'courses': result['courses'] ?? 'N/A',
              'faculties': result['faculties'] ?? 'N/A',
              'email': result['email'] ?? 'N/A',
              'mobileNo': result['mobileNo'] ?? 'N/A',
              'feeBalance': result['feeBalance'] ?? 'N/A',
              'status': result['status'] ?? 'Active',
              'idExpiry': result['idExpiry'] ?? 'N/A',
            } else ...{
              'username': result['username'] ?? 'N/A',
              'staffNo': result['staffNo'] ?? 'N/A',
              'name': result['name'] ?? 'Unknown',
              'department': result['department'] ?? 'N/A',
              'status': result['status'] ?? 'Active',
            },
          };

          setState(() {
            _identityData = identityData;
            _successMessage = result['message'] ?? '${result['type']} verified successfully';
          });

          await _saveVerificationHistory(identityData);
          await _loadRecentVerifications();
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'Failed to verify ${_verificationType == 'student' ? 'student' : 'staff'}';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error verifying ${_verificationType == 'student' ? 'student ID' : 'staff'}: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildInfoCard() {
    if (_identityData == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                '${_identityData!['type']} Verified',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('Name:', _identityData!['name']),
          if (_identityData!['type'] == 'student') ...[
            _buildInfoRow('Student ID:', _identityData!['studentId']),
            _buildInfoRow('Courses:', _identityData!['courses']),
            _buildInfoRow('Faculties:', _identityData!['faculties']),
            
            _buildInfoRow('Status:', _identityData!['status']),
            _buildInfoRow('ID Expiry:', _identityData!['idExpiry']),
          ] else ...[
            _buildInfoRow('Username:', _identityData!['username']),
            _buildInfoRow('Department:', _identityData!['department']),
            _buildInfoRow('Status:', _identityData!['status']),
          ],
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _identityData!['type'] == 'student' ? _identityData!['studentId'] : _identityData!['staffNo']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Done',
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentVerifications() {
    if (_recentVerifications.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Verifications',
                style: GoogleFonts.lexend(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              TextButton(
                onPressed: _clearAllSavedData,
                child: Text(
                  'Clear All',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._recentVerifications.take(5).map((verification) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey[500]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        verification['display'],
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _studentIdController.clear();
      _usernameController.clear();
      _staffNoController.clear();
      _identityData = null;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _usernameController.dispose();
    _staffNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Identity Verification',
        color: Colors.white,
        backgroundColor: AppColors.primaryBlue,
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Settings', style: GoogleFonts.lexend()),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.delete_forever),
                        title: Text('Clear All Data', style: GoogleFonts.lexend()),
                        onTap: () {
                          Navigator.pop(context);
                          _clearAllSavedData();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ], onBack: () {  },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify Identity',
                  style: GoogleFonts.lexend(
                    fontSize: isSmallScreen ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select the verification type and enter the appropriate details.',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _verificationType,
                    decoration: InputDecoration(
                      labelText: 'Verification Type',
                      labelStyle: GoogleFonts.lexend(color: AppColors.primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'student', child: Text('Student ID', style: GoogleFonts.lexend())),
                      DropdownMenuItem(value: 'username', child: Text('Staff Username', style: GoogleFonts.lexend())),
                      DropdownMenuItem(value: 'staffNo', child: Text('Staff Number', style: GoogleFonts.lexend())),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _verificationType = value!;
                        _clearForm();
                      });
                      _saveData();
                    },
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_verificationType == 'student') ...[
                        Text(
                          'Student ID Number',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _studentIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter 6 or 7-digit ID (e.g., 123456)',
                            prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.error, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a student ID';
                            }
                            if (!RegExp(r'^\d{6,7}$').hasMatch(value)) {
                              return 'Student ID must be 6 or 7 digits';
                            }
                            return null;
                          },
                          onChanged: (value) => _saveData(),
                        ),
                      ] else if (_verificationType == 'username') ...[
                        Text(
                          'Staff Username',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _usernameController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Enter staff username',
                            prefixIcon: Icon(Icons.person, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.error, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                          onChanged: (value) => _saveData(),
                        ),
                      ] else ...[
                        Text(
                          'Staff Number',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _staffNoController,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Enter staff number',
                            prefixIcon: Icon(Icons.badge, color: AppColors.primaryBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.error, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a staff number';
                            }
                            return null;
                          },
                          onChanged: (value) => _saveData(),
                        ),
                      ],
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyIdentity,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Verify ${_verificationType}',
                                      style: GoogleFonts.lexend(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          if (_identityData != null) ...[
                            SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _clearForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Clear',
                                style: GoogleFonts.lexend(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.lexend(
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildInfoCard(),
                _buildRecentVerifications(),
                if (_identityData != null) ...[
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_identityData!['type']} is authorized to enter the premises',
                            style: GoogleFonts.lexend(
                              color: AppColors.success,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24),
                Center(
                  child: Text(
                    'For security use only • ${AppStrings.universityName}',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}