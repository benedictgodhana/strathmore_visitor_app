class Validators {
  static var validatePhoneNumber;

  static var validateCountry;

  static var validateRequired;

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? validateIdNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your ID number';
    }
    if (value.length < 5) {
      return 'Please enter a valid ID number';
    }
    return null;
  }

  static String? validateCompany(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your company/organization';
    }
    return null;
  }

  static String? validatePurpose(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter the purpose of your visit';
    }
    if (value.length < 10) {
      return 'Please provide more details about your visit';
    }
    return null;
  }
}
