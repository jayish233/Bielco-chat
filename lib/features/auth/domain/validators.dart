final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _usernameRe = RegExp(r'^[a-z0-9_]{3,20}$');

String? validateEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return 'Enter your email.';
  if (!_emailRe.hasMatch(v)) return 'Enter a valid email address.';
  return null;
}

String? validatePassword(String value) {
  final ok =
      value.length >= 8 &&
      value.contains(RegExp(r'[A-Za-z]')) &&
      value.contains(RegExp(r'[0-9]'));
  return ok ? null : 'Use 8+ characters with a letter and a number.';
}

/// 0–4: length ≥ 8, a digit, mixed case, a symbol or length ≥ 12.
int passwordStrength(String value) {
  if (value.isEmpty) return 0;
  var score = 0;
  if (value.length >= 8) score++;
  if (value.contains(RegExp(r'[0-9]'))) score++;
  if (value.contains(RegExp(r'[a-z]')) && value.contains(RegExp(r'[A-Z]'))) {
    score++;
  }
  if (value.contains(RegExp(r'[^A-Za-z0-9]')) || value.length >= 12) score++;
  return score;
}

String normalizeUsername(String value) {
  var v = value.trim();
  if (v.startsWith('@')) v = v.substring(1);
  return v.toLowerCase();
}

/// Expects an already-normalized username.
String? validateUsername(String value) => _usernameRe.hasMatch(value)
    ? null
    : 'Use 3–20 letters, numbers or underscores.';

String? validateDisplayName(String value) {
  final v = value.trim();
  if (v.isEmpty) return 'Enter your name.';
  if (v.length > 50) return 'Keep it under 50 characters.';
  return null;
}
