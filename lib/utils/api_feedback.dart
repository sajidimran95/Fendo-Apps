import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../theme/app_colors.dart';

void showApiError(BuildContext context, Object error) {
  final msg = error is ApiException
      ? error.displayMessage
      : 'Something went wrong';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.coral,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showApiMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.forest,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
