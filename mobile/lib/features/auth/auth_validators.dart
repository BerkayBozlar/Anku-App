final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'E-posta zorunludur.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  return null;
}

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Parola zorunludur.';
  if (password.length < 8) return 'Parola en az 8 karakter olmalıdır.';
  return null;
}
