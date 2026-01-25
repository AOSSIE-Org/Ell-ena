import 'package:flutter/material.dart';

/// Unified Design Tokens for Create Screens
class UnifiedDesignTokens {
  // Colors
  static const Color backgroundColor = Color(0xFF1A1A1A);
  static const Color surfaceColor = Color(0xFF2D2D2D);
  static final Color primaryGreen = Colors.green.shade700;
  static final Color accentGreen = Colors.green.shade400;
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.grey.shade400;
  static final Color errorColor = Colors.red.shade400;
  static final Color hintColor = Colors.grey.shade400;

  // Spacing
  static const double sectionSpacing = 24.0;
  static const double fieldSpacing = 16.0;
  static const double labelSpacing = 8.0;

  // Border Radius
  static const double borderRadius = 12.0;

  // Typography
  static const TextStyle labelStyle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static TextStyle hintStyle = TextStyle(color: hintColor);
}

/// Unified Text Form Field with consistent styling
class UnifiedTextFormField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool isOptional;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final void Function(String)? onChanged;

  const UnifiedTextFormField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.validator,
    this.maxLines = 1,
    this.isOptional = false,
    this.keyboardType,
    this.prefixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: UnifiedDesignTokens.labelStyle,
            ),
            if (isOptional) ...[
              const SizedBox(width: 4),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: UnifiedDesignTokens.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: UnifiedDesignTokens.labelSpacing),
        
        // Text Field
        TextFormField(
          controller: controller,
          style: const TextStyle(color: UnifiedDesignTokens.textPrimary),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: UnifiedDesignTokens.hintStyle,
            filled: true,
            fillColor: UnifiedDesignTokens.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UnifiedDesignTokens.borderRadius),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: prefixIcon,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Unified Dropdown Field with consistent styling
class UnifiedDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final bool isOptional;
  final String? hintText;

  const UnifiedDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isOptional = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: UnifiedDesignTokens.labelStyle,
            ),
            if (isOptional) ...[
              const SizedBox(width: 4),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: UnifiedDesignTokens.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: UnifiedDesignTokens.labelSpacing),
        
        // Dropdown Container
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: UnifiedDesignTokens.surfaceColor,
            borderRadius: BorderRadius.circular(UnifiedDesignTokens.borderRadius),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: hintText != null
                  ? Text(
                      hintText!,
                      style: UnifiedDesignTokens.hintStyle,
                    )
                  : null,
              dropdownColor: UnifiedDesignTokens.surfaceColor,
              isExpanded: true,
              icon: Icon(
                Icons.arrow_drop_down,
                color: UnifiedDesignTokens.textSecondary,
              ),
              style: const TextStyle(color: UnifiedDesignTokens.textPrimary),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Unified Date/Time Picker Field
class UnifiedPickerField extends StatelessWidget {
  final String label;
  final String displayText;
  final IconData icon;
  final VoidCallback onTap;
  final bool isOptional;

  const UnifiedPickerField({
    super.key,
    required this.label,
    required this.displayText,
    required this.icon,
    required this.onTap,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: UnifiedDesignTokens.labelStyle,
            ),
            if (isOptional) ...[
              const SizedBox(width: 4),
              Text(
                '(Optional)',
                style: TextStyle(
                  color: UnifiedDesignTokens.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: UnifiedDesignTokens.labelSpacing),
        
        // Picker Container
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: UnifiedDesignTokens.surfaceColor,
              borderRadius: BorderRadius.circular(UnifiedDesignTokens.borderRadius),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: UnifiedDesignTokens.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  displayText,
                  style: TextStyle(
                    color: displayText.startsWith('Select')
                        ? UnifiedDesignTokens.textSecondary
                        : UnifiedDesignTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Unified Section Header
class UnifiedSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const UnifiedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: UnifiedDesignTokens.labelStyle.copyWith(fontSize: 18),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              color: UnifiedDesignTokens.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

/// Unified Action Button (Primary)
class UnifiedActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const UnifiedActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: UnifiedDesignTokens.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UnifiedDesignTokens.borderRadius),
          ),
          disabledBackgroundColor: Colors.grey,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Unified AppBar for Create Screens
AppBar unifiedCreateAppBar({
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    backgroundColor: UnifiedDesignTokens.surfaceColor,
    actions: actions,
  );
}
