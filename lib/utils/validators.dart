class Validators {
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d{9,10}$').hasMatch(value.trim())) {
      return 'Enter a valid phone number (9-10 digits)';
    }
    return null;
  }

  static String? validateInternationalPhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final normalized = value.trim().replaceAll(RegExp(r'[^\d+]'), '');
    final digitsOnly = normalized.replaceAll('+', '');

    if (!RegExp(r'^\+?\d+$').hasMatch(normalized)) {
      return 'Enter a valid phone number';
    }

    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return 'Enter a valid phone number (7-15 digits)';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (!RegExp(r"^[A-Za-z\s-']+$").hasMatch(value.trim()) ||
        value.trim().split(' ').length < 1) {
      return 'Enter a valid name';
    }
    return null;
  }

  static String? validateCountry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Country is required';
    }
    return null;
  }

  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
