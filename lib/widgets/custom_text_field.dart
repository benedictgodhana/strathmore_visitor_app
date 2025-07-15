import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool? filled;
  final int maxLines;
  final void Function(String)? onChanged;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.keyboardType,
    required this.readOnly,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.filled,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        filled: filled ?? false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryBlue),
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}
