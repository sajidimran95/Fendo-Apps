import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/app_currency.dart';
import '../../theme/app_colors.dart';

/// Dropdown of currency codes with symbols (BDT · ৳).
class CurrencyPickerField extends StatelessWidget {
  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Currency',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final code = AppCurrency.normalize(value);
    final options = AppCurrency.codes.contains(code)
        ? AppCurrency.codes
        : [code, ...AppCurrency.codes];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.forestSoft,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('currency-picker-$code'),
          initialValue: code,
          decoration: const InputDecoration(),
          items: options
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    AppCurrency.label(c),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(AppCurrency.normalize(v));
          },
        ),
      ],
    );
  }
}
