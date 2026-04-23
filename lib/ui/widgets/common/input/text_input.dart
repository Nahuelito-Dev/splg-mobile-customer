import 'package:flutter/material.dart';

class TextInput extends StatelessWidget {
  const TextInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.errorText,
    this.keyboardType,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.obscureText = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? hintText;
  final String? errorText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outline.withAlpha(70),
        ));

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        fillColor: Theme.of(context).colorScheme.surface,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: colorScheme.onSurface),
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: TextStyle(color: colorScheme.outline.withAlpha(70)),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        errorText: errorText,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
    );
  }
}
