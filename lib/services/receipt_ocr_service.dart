import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/expense_model.dart';

/// On-device receipt OCR (ML Kit). Backend `/expenses/scan-receipt` is often a stub.
class ReceiptOcrService {
  ReceiptOcrService._();

  static final ReceiptOcrService instance = ReceiptOcrService._();

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<ScanReceiptResult> scanFile(String filePath) async {
    if (kIsWeb) {
      throw UnsupportedError('On-device receipt OCR is not available on web');
    }
    final input = InputImage.fromFilePath(filePath);
    final recognized = await _recognizer.processImage(input);
    final text = recognized.text.trim();
    if (text.isEmpty) {
      return const ScanReceiptResult();
    }
    return parseText(text);
  }

  /// Exposed for tests / unit parsing of raw OCR text.
  ScanReceiptResult parseText(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchant = _guessMerchant(lines);
    final date = _guessDate(rawText);
    final amount = _guessTotal(lines, rawText);
    final items = _guessItems(lines, amount);
    final currency = _guessCurrency(rawText);

    final title = merchant?.isNotEmpty == true
        ? merchant
        : (items.isNotEmpty ? items.first.name : null);

    return ScanReceiptResult(
      title: title,
      merchantName: merchant,
      amount: amount,
      expenseDate: date,
      currency: currency,
      items: items,
      raw: {
        'ocr_text': rawText,
        'source': 'on_device',
      },
    );
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  String? _guessMerchant(List<String> lines) {
    for (final line in lines.take(8)) {
      final s = line.trim();
      if (s.length < 2 || s.length > 48) continue;
      if (_isNoiseLine(s)) continue;
      if (_amountOnly(s)) continue;
      if (_looksLikeDate(s)) continue;
      if (_looksLikePhoneOrAddress(s)) continue;
      // Prefer lines with letters.
      if (!RegExp(r'[A-Za-z]').hasMatch(s)) continue;
      return s;
    }
    return null;
  }

  double? _guessTotal(List<String> lines, String full) {
    // Prefer labelled totals near the bottom.
    final totalPatterns = <RegExp>[
      RegExp(
        r'(?:grand\s*)?total(?:\s*due)?\s*[:\-]?\s*(?:bdt|tk|taka|usd|\$|€|£)?\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:amount\s*(?:due|paid)?|balance\s*due|net\s*amount|pay(?:able)?)\s*[:\-]?\s*(?:bdt|tk|taka|usd|\$)?\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:bdt|tk|taka|usd|\$)\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:total)?',
        caseSensitive: false,
      ),
    ];

    double? best;
    for (final line in lines.reversed) {
      for (final re in totalPatterns) {
        final m = re.firstMatch(line);
        if (m != null) {
          final v = _parseAmount(m.group(1));
          if (v != null && v > 0) return v;
        }
      }
    }

    // Fallback: largest reasonable money-looking number on the receipt.
    final moneyRe = RegExp(
      r'(?:(?:bdt|tk|taka|usd|\$)\s*)?([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+\.[0-9]{2})\b',
      caseSensitive: false,
    );
    for (final m in moneyRe.allMatches(full)) {
      final v = _parseAmount(m.group(1));
      if (v == null || v < 1) continue;
      if (v > 1000000) continue;
      if (best == null || v > best) best = v;
    }
    return best;
  }

  String? _guessDate(String full) {
    final patterns = <RegExp>[
      // 2026-08-07 or 2026/08/07
      RegExp(r'\b(20\d{2})[./\-](\d{1,2})[./\-](\d{1,2})\b'),
      // 07-08-2026 or 07/08/2026
      RegExp(r'\b(\d{1,2})[./\-](\d{1,2})[./\-](20\d{2})\b'),
      // Aug 7, 2026
      RegExp(
        r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(20\d{2})\b',
        caseSensitive: false,
      ),
      // 7 Aug 2026
      RegExp(
        r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(20\d{2})\b',
        caseSensitive: false,
      ),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(full);
      if (m == null) continue;
      final iso = _matchToIso(m, re);
      if (iso != null) return iso;
    }
    return null;
  }

  String? _matchToIso(RegExpMatch m, RegExp re) {
    final src = re.pattern;
    try {
      if (src.startsWith(r'\b(20')) {
        final y = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final d = int.parse(m.group(3)!);
        return _iso(y, mo, d);
      }
      if (src.contains(r'(20\d{2})\b') && src.startsWith(r'\b(\d{1,2})')) {
        // dd-mm-yyyy (assume day first — common on BD receipts)
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        return _iso(y, mo, d);
      }
      final months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      if (src.contains(r'(jan|feb')) {
        if (m.groupCount >= 3 &&
            months.containsKey(m.group(1)!.toLowerCase().substring(0, 3))) {
          final mo = months[m.group(1)!.toLowerCase().substring(0, 3)]!;
          final d = int.parse(m.group(2)!);
          final y = int.parse(m.group(3)!);
          return _iso(y, mo, d);
        }
        if (m.groupCount >= 3 &&
            months.containsKey(m.group(2)!.toLowerCase().substring(0, 3))) {
          final d = int.parse(m.group(1)!);
          final mo = months[m.group(2)!.toLowerCase().substring(0, 3)]!;
          final y = int.parse(m.group(3)!);
          return _iso(y, mo, d);
        }
      }
    } catch (_) {}
    return null;
  }

  String? _iso(int y, int mo, int d) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${mo.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  String? _guessCurrency(String full) {
    final lower = full.toLowerCase();
    if (lower.contains('bdt') ||
        lower.contains('taka') ||
        RegExp(r'\btk\b', caseSensitive: false).hasMatch(full)) {
      return 'BDT';
    }
    if (full.contains('€') || lower.contains('eur')) return 'EUR';
    if (full.contains('£') || lower.contains('gbp')) return 'GBP';
    if (full.contains(r'$') || lower.contains('usd')) return 'USD';
    if (lower.contains('inr') || full.contains('₹')) return 'INR';
    return null;
  }

  List<ExpenseItem> _guessItems(List<String> lines, double? total) {
    final items = <ExpenseItem>[];
    final itemRe = RegExp(
      r'^(.+?)\s+(?:x\s*\d+\s+)?'
      r'(?:bdt|tk|taka|usd|\$)?\s*'
      r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+\.[0-9]{2}|[0-9]+)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (_isNoiseLine(line) || _looksLikeDate(line)) continue;
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('subtotal') ||
          lower.contains('tax') ||
          lower.contains('vat') ||
          lower.contains('change') ||
          lower.contains('cash') ||
          lower.contains('card') ||
          lower.contains('balance')) {
        continue;
      }
      final m = itemRe.firstMatch(line);
      if (m == null) continue;
      final name = m.group(1)!.trim();
      final amount = _parseAmount(m.group(2));
      if (name.length < 2 || amount == null || amount <= 0) continue;
      if (_amountOnly(name)) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(name)) continue;
      // Skip if this looks like the grand total line.
      if (total != null && (amount - total).abs() < 0.01) continue;
      items.add(ExpenseItem(name: name, amount: amount));
      if (items.length >= 20) break;
    }
    return items;
  }

  double? _parseAmount(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s,]'), '');
    return double.tryParse(cleaned);
  }

  bool _amountOnly(String s) =>
      RegExp(r'^(?:bdt|tk|\$|usd)?\s*[0-9][0-9.,\s]*$', caseSensitive: false)
          .hasMatch(s);

  bool _looksLikeDate(String s) =>
      RegExp(r'\d{1,2}[./\-]\d{1,2}[./\-]\d{2,4}').hasMatch(s) ||
      RegExp(
        r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
        caseSensitive: false,
      ).hasMatch(s);

  bool _looksLikePhoneOrAddress(String s) {
    if (RegExp(r'\+?\d{8,}').hasMatch(s.replaceAll(RegExp(r'[\s\-]'), ''))) {
      return true;
    }
    final lower = s.toLowerCase();
    return lower.contains('road') ||
        lower.contains('street') ||
        lower.contains('www.') ||
        lower.contains('.com') ||
        lower.contains('@');
  }

  bool _isNoiseLine(String s) {
    final lower = s.toLowerCase();
    const noise = [
      'thank you',
      'thanks',
      'welcome',
      'receipt',
      'invoice',
      'tel',
      'phone',
      'gst',
      'tin',
      'vat no',
      '***',
      '---',
      '===',
    ];
    for (final n in noise) {
      if (lower.contains(n)) return true;
    }
    return s.length <= 1;
  }
}
