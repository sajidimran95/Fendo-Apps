import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../services/auth_controller.dart';
import '../../services/groups_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  late final TextEditingController _currency;
  final _emails = TextEditingController();
  String _type = 'friends';
  bool _simplify = true;
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
    final c = AuthController.instance.user?.currency.trim() ?? '';
    _currency = TextEditingController(
      text: c.isEmpty ? 'USD' : c.toUpperCase(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _emails.dispose();
    super.dispose();
  }

  List<String> get _parsedEmails => _emails.text
      .split(RegExp(r'[,;\s]+'))
      .map((e) => e.trim())
      .where((e) => e.contains('@'))
      .toList();

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      showApiError(context, ApiException(message: 'Enter a group name'));
      return;
    }

    setState(() => _loading = true);
    try {
      await GroupsController.instance.createGroup(
        name: _name.text.trim(),
        type: _type,
        currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
        simplifyDebts: _simplify,
        memberEmails: _parsedEmails,
      );
      if (!mounted) return;
      showApiMessage(context, 'Group created');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } catch (e) {
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
              title: 'New group',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(
                    controller: _name,
                    label: 'Group name',
                    hint: 'Bali Trip 2026',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _currency,
                    label: 'Currency',
                    hint: 'USD',
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
                  const SizedBox(height: 18),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Simplify debts',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Fewer payments to settle everyone',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _simplify,
                    activeThumbColor: AppColors.mint,
                    onChanged: (v) => setState(() => _simplify = v),
                  ),
                  const SizedBox(height: 8),
                  AuthTextField(
                    controller: _emails,
                    label: 'Invite emails (optional)',
                    hint: 'a@mail.com, b@mail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Create group',
                    loading: _loading,
                    onPressed: _loading ? null : _create,
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
