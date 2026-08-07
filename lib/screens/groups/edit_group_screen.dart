import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/app_currency.dart';
import '../../models/group_model.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';
import '../../widgets/common/currency_picker_field.dart';

class EditGroupScreen extends StatefulWidget {
  const EditGroupScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  late final TextEditingController _name;
  late String _currency;
  late String _type;
  late bool _simplify;
  bool _loading = false;

  final _types = const [
    'apartment',
    'family',
    'vacation',
    'friends',
    'events',
    'business',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group.name);
    _currency = AppCurrency.normalize(widget.group.currency);
    _type = widget.group.type;
    _simplify = widget.group.simplifyDebts;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Name is required'));
      return;
    }
    setState(() => _loading = true);
    try {
      await GroupsController.instance.updateGroup(
        widget.group.id,
        name: _name.text.trim(),
        type: _type,
        currency: AppCurrency.normalize(_currency),
        simplifyDebts: _simplify,
      );
      if (!mounted) return;
      showApiMessage(context, 'Group updated');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Edit group',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(controller: _name, label: 'Group name'),
                  const SizedBox(height: 14),
                  CurrencyPickerField(
                    value: _currency,
                    onChanged: (c) => setState(() => _currency = c),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Type',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final selected = t == _type;
                      return ChoiceChip(
                        label: Text(t),
                        selected: selected,
                        onSelected: (_) => setState(() => _type = t),
                        selectedColor: AppColors.mintWash,
                        labelStyle: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Simplify debts',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                    value: _simplify,
                    activeThumbColor: AppColors.mint,
                    onChanged: (v) => setState(() => _simplify = v),
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Save changes',
                    loading: _loading,
                    onPressed: _loading ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
