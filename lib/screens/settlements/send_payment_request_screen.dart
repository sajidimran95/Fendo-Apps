import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/group_member.dart';
import '../../models/group_model.dart';
import '../../services/auth_controller.dart';
import '../../services/groups_controller.dart';
import '../../services/settlements_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class SendPaymentRequestScreen extends StatefulWidget {
  const SendPaymentRequestScreen({super.key});

  @override
  State<SendPaymentRequestScreen> createState() =>
      _SendPaymentRequestScreenState();
}

class _SendPaymentRequestScreenState extends State<SendPaymentRequestScreen> {
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  final _message = TextEditingController();
  bool _loading = false;
  bool _booting = true;

  List<GroupModel> _groups = const [];
  GroupModel? _group;
  List<GroupMember> _members = const [];
  GroupMember? _debtor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await GroupsController.instance.loadGroups();
    if (!mounted) return;
    final groups = GroupsController.instance.groups;
    final selected = groups.isNotEmpty ? groups.first : null;
    setState(() {
      _groups = groups;
      _group = selected;
      _booting = false;
    });
    if (selected != null) await _loadMembers(selected.id);
  }

  Future<void> _loadMembers(int groupId) async {
    final members = await GroupsController.instance.getMembers(groupId);
    if (!mounted) return;
    final me = AuthController.instance.user?.id ?? 1;
    final others = members.where((m) => m.userId != me).toList();
    setState(() {
      _members = others;
      _debtor = others.isNotEmpty ? others.first : null;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _currency.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_group == null) {
      showApiError(context, ApiException(message: 'Select a group'));
      return;
    }
    if (_debtor == null) {
      showApiError(context, ApiException(message: 'Select who owes you'));
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      showApiError(context, ApiException(message: 'Enter a valid amount'));
      return;
    }

    setState(() => _loading = true);
    try {
      await SettlementsController.instance.createRequest(
        debtorId: _debtor!.userId,
        groupId: _group!.id,
        amount: amount,
        currency: _currency.text.trim().isEmpty ? 'USD' : _currency.text.trim(),
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
        debtorName: _debtor!.name,
        groupName: _group!.name,
      );
      if (!mounted) return;
      showApiMessage(context, 'Payment request sent');
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
    if (_booting) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mint),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            AppHeader(
              title: 'Request payment',
              subtitle: 'Ask someone to pay you',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group *',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_groups.isEmpty)
                    Text(
                      'Create a group first',
                      style: GoogleFonts.manrope(color: AppColors.coral),
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey('req-group-${_group?.id}'),
                      initialValue: _group?.id,
                      items: _groups
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                      onChanged: (id) async {
                        if (id == null) return;
                        setState(
                          () => _group = _groups.firstWhere((g) => g.id == id),
                        );
                        await _loadMembers(id);
                      },
                      decoration: const InputDecoration(),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Debtor *',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_members.isEmpty)
                    Text(
                      'No other members in this group',
                      style: GoogleFonts.manrope(color: AppColors.textMuted),
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey('req-debtor-${_debtor?.userId}'),
                      initialValue: _debtor?.userId,
                      items: _members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.userId,
                              child: Text(m.name),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(
                          () => _debtor =
                              _members.firstWhere((m) => m.userId == id),
                        );
                      },
                      decoration: const InputDecoration(),
                    ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _amount,
                    label: 'Amount *',
                    hint: '30.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _currency,
                    label: 'Currency',
                    hint: 'USD',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _message,
                    label: 'Message',
                    hint: 'optional',
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Send request',
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
