final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'E-posta zorunludur.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  return null;
}

/// API'deki Identity parola kurallarıyla aynı.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Parola zorunludur.';
  if (password.length < 8) return 'Parola en az 8 karakter olmalıdır.';
  if (!password.contains(RegExp('[A-Z]'))) {
    return 'Parola en az bir büyük harf içermelidir.';
  }
  if (!password.contains(RegExp('[a-z]'))) {
    return 'Parola en az bir küçük harf içermelidir.';
  }
  if (!password.contains(RegExp('[0-9]'))) {
    return 'Parola en az bir rakam içermelidir.';
  }
  if (!password.contains(RegExp('[^A-Za-z0-9]'))) {
    return 'Parola en az bir özel karakter (! . * gibi) içermelidir.';
  }
  return null;
}
