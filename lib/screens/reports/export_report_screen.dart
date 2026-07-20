import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../models/report_model.dart';
import '../../services/reports_controller.dart';
import '../../theme/app_colors.dart';
import '../../utils/api_feedback.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/common/app_widgets.dart';

class ExportReportScreen extends StatefulWidget {
  const ExportReportScreen({super.key});

  @override
  State<ExportReportScreen> createState() => _ExportReportScreenState();
}

class _ExportReportScreenState extends State<ExportReportScreen> {
  String _format = 'csv';
  bool _loading = false;
  ReportExport? _export;

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      // Ensure personal report is loaded so demo export has data.
      await ReportsController.instance.loadPersonal();
      final result =
          await ReportsController.instance.export(format: _format);
      if (!mounted) return;
      setState(() => _export = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final content = _export?.content;
    if (content == null || content.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    showApiMessage(context, 'Export copied');
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
              title: 'Export',
              subtitle: 'CSV or JSON',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Format',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['csv', 'json'].map((f) {
                      final selected = _format == f;
                      return ChoiceChip(
                        label: Text(
                          f.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.forest
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _format = f),
                        selectedColor: AppColors.mintWash,
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Generate export',
                    loading: _loading,
                    onPressed: _loading ? null : _run,
                  ),
                  if (_export != null) ...[
                    const SizedBox(height: 20),
                    SoftTile(
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _export!.filename ??
                                      'fendo-report.${_export!.format}',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _copy,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 320),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _export!.content,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: AppColors.forestSoft,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
