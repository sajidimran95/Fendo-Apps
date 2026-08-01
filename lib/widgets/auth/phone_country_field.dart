import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ip_country_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/country_dial_codes.dart';
import '../../utils/phone_number.dart';

/// Phone field with IP-detected country dial code (tap to change).
///
/// Dial code sits beside the [TextField] (not as `prefixIcon`) so IP/country
/// updates never rebuild the input and dismiss the keyboard.
class PhoneCountryField extends StatefulWidget {
  const PhoneCountryField({
    super.key,
    required this.controller,
    this.label = 'Mobile number',
    this.hint = '1712 345678',
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  State<PhoneCountryField> createState() => PhoneCountryFieldState();
}

class PhoneCountryFieldState extends State<PhoneCountryField> {
  final _ip = IpCountryService.instance;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ip.ensureLoaded();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Normalized E.164 using current dial code.
  String normalizedPhone() {
    return PhoneNumber.normalize(
      widget.controller.text,
      countryCode: _ip.dialCode,
    );
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final entries = kCountryNames.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                'Select country',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final dial = dialCodeForIso(e.key);
                    final selectedIso = e.key == _ip.iso;
                    return ListTile(
                      title: Text(
                        e.value,
                        style: GoogleFonts.manrope(
                          fontWeight:
                              selectedIso ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      trailing: Text(
                        '+$dial',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppColors.mintDim,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, e.key),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    _ip.setCountry(selected);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor ??
                Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textMuted.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ListenableBuilder(
                listenable: _ip,
                builder: (context, _) {
                  return InkWell(
                    onTap: _pickCountry,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _ip.dialPrefix,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forest,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: AppColors.textMuted,
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            margin: const EdgeInsets.only(left: 4),
                            color:
                                AppColors.textMuted.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.phone,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onFieldSubmitted,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                  decoration: const InputDecoration(
                    hintText: null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.fromLTRB(8, 14, 14, 14),
                  ).copyWith(hintText: widget.hint),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: _ip,
          builder: (context, _) {
            return Text(
              'Detected from your IP: ${_ip.countryName}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            );
          },
        ),
      ],
    );
  }
}
