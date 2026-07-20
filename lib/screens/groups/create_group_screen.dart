import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  String _type = 'friends';
  bool _simplify = true;

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
  void dispose() {
    _name.dispose();
    super.dispose();
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
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Create group',
                    onPressed: () {
                      showStaticSnack(context, 'Group created (static)');
                      Navigator.pop(context);
                    },
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
