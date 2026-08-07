import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../theme/app_colors.dart';

/// Turns raw/API/Firebase/JSON errors into short professional user text.
String professionalUserMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  String raw;
  if (error is ApiException) {
    raw = error.displayMessage;
  } else {
    raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      raw = raw.substring('Exception: '.length);
    }
  }
  return sanitizeUserMessage(raw, fallback: fallback);
}

String sanitizeUserMessage(
  String? input, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = (input ?? '').trim();
  if (raw.isEmpty) return fallback;

  final lower = raw.toLowerCase();

  // Phone already in use — never show generic "could not send OTP".
  if (_looksLikePhoneTaken(lower)) {
    return 'This number is already registered. Please log in.';
  }
  if (lower.contains('no account') ||
      lower.contains('user not found') ||
      lower.contains('account not found') ||
      (lower.contains('not found') && lower.contains('phone'))) {
    return 'No account found for this number.';
  }
  if (lower.contains('too many') ||
      lower.contains('quota') ||
      lower.contains('rate limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  // Keep real OTP / SMS / robot-check messages (do not hide Firebase errors).
  if (lower.contains('sms') ||
      lower.contains('robot check') ||
      lower.contains('tap resend') ||
      lower.contains('country code') ||
      lower.contains('sha-1') ||
      lower.contains('phone sign-in') ||
      lower.contains('timed out') ||
      lower.contains('missing initial state') ||
      lower.contains('unable to process request') ||
      lower.contains('internal error') ||
      lower.startsWith('sms failed') ||
      lower.contains('firebase internal')) {
    if (raw.length > 200) return raw.substring(0, 200);
    return raw;
  }

  // Hide technical / JSON / stack internals from other flows.
  final looksTechnical = raw.startsWith('{') ||
      raw.startsWith('[') ||
      lower.contains('google-services') ||
      lower.contains('sessionstorage') ||
      lower.contains('oauth') ||
      lower.contains('stack trace') ||
      lower.contains('dioexception') ||
      lower.contains('socketexception') ||
      lower.contains('statuscode') ||
      lower.contains('"errors"') ||
      RegExp(r'\berror code[:\s]*\d+', caseSensitive: false).hasMatch(raw) ||
      (RegExp(r'\[.*\]').hasMatch(raw) && lower.contains('error'));

  if (looksTechnical) {
    if (lower.contains('missing initial') ||
        lower.contains('unable to process request')) {
      return 'Robot check session expired. Return to the app and tap Resend once.';
    }
    if (lower.contains('phone') &&
        (lower.contains('invalid') || lower.contains('format'))) {
      return 'Please enter a valid mobile number.';
    }
    return fallback;
  }

  // Keep short, readable product messages.
  if (raw.length > 140) return fallback;
  return raw;
}

bool _looksLikePhoneTaken(String lower) {
  return lower.contains('already been taken') ||
      lower.contains('has already been taken') ||
      lower.contains('already registered') ||
      lower.contains('already exists') ||
      lower.contains('already in use') ||
      lower.contains('phone has been taken') ||
      (lower.contains('phone') &&
          (lower.contains('taken') ||
              lower.contains('exists') ||
              lower.contains('registered')));
}

/// True when API/error text means this phone is already registered.
bool isPhoneTakenMessage(Object error) {
  final raw = error is ApiException
      ? error.displayMessage.toLowerCase()
      : error.toString().toLowerCase();
  return _looksLikePhoneTaken(raw);
}

void showApiError(BuildContext context, Object error) {
  final msg = professionalUserMessage(error);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.coral,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showApiMessage(BuildContext context, String message) {
  final msg = sanitizeUserMessage(
    message,
    fallback: 'Done.',
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.forest,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
