// Shared client-side form field validators for dashboard dialogs.

String? requiredText(String? value, [String label = 'This field']) {
  if ((value ?? '').trim().isEmpty) return '$label is required.';
  return null;
}

/// Same rules as auth: non-empty, contains `@` and `.`.
String? emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your email';
  if (!text.contains('@') || !text.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

/// Phone: allow empty, or 7–15 digits after stripping non-digits.
String? optionalPhone(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  final digits = v.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7 || digits.length > 15) {
    return 'Enter a valid phone number.';
  }
  return null;
}

/// Last 4: empty is allowed; if provided must be exactly 4 digits.
String? optionalLastFour(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length != 4) return 'Enter exactly 4 digits.';
  return null;
}

String? positiveAmount(Object? value, [String label = 'Amount']) {
  final n = value is num
      ? value.toDouble()
      : double.tryParse((value?.toString() ?? '').trim());
  if (n == null || !n.isFinite || n <= 0) {
    return 'Enter a positive ${label.toLowerCase()}.';
  }
  return null;
}

String? nonNegativeAmount(Object? value, [String label = 'Amount']) {
  final raw = (value?.toString() ?? '').trim();
  if (raw.isEmpty && value is! num) return '$label is required.';
  final n = value is num ? value.toDouble() : double.tryParse(raw);
  if (n == null || !n.isFinite || n < 0) {
    return 'Enter a valid ${label.toLowerCase()}.';
  }
  return null;
}

/// Finite number (positive or negative). Empty / NaN fails.
String? finiteAmount(Object? value, [String label = 'Amount']) {
  final raw = (value?.toString() ?? '').trim();
  if (raw.isEmpty && value is! num) return '$label is required.';
  final n = value is num ? value.toDouble() : double.tryParse(raw);
  if (n == null || !n.isFinite) {
    return 'Enter a valid ${label.toLowerCase()}.';
  }
  return null;
}

/// Balance rules: IOU keeps sign; other types must be ≥ 0.
String? accountBalanceAmount(Object? value, String type) {
  if (type == 'IOU') return finiteAmount(value, 'Balance');
  return nonNegativeAmount(value, 'Balance');
}

/// Signed balance for local/API storage.
double signedAccountBalance(String type, double balance) {
  if (type == 'Credit') return -balance.abs();
  if (type == 'IOU') return balance;
  return balance.abs();
}

/// Magnitude sent to API (Credit/Cash/etc. positive; IOU keeps sign).
double apiAccountBalance(String type, double balance) {
  if (type == 'IOU') return balance;
  return balance.abs();
}

/// ISO date YYYY-MM-DD when provided.
String? optionalIsoDate(String? value, [String label = 'Date']) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
    return 'Enter a valid ${label.toLowerCase()}.';
  }
  final parsed = DateTime.tryParse(v);
  if (parsed == null) return 'Enter a valid ${label.toLowerCase()}.';
  return null;
}

String? requiredIsoDate(String? value, [String label = 'Date']) {
  final missing = requiredText(value, label);
  if (missing != null) return missing;
  return optionalIsoDate(value, label);
}

String? firstFieldError(Map<String, String?> errors) {
  for (final v in errors.values) {
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

bool hasFieldErrors(Map<String, String?> errors) =>
    firstFieldError(errors) != null;
