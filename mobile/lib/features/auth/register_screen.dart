import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_validators.dart';
import 'session_controller.dart';

/// Öğrenci hesabı oluşturur, ardından aynı bilgilerle giriş yapar.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final email = _email.text.trim();
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            fullName: _fullName.text.trim(),
            email: email,
            password: _password.text,
          );
      await ref
          .read(sessionProvider.notifier)
          .login(email: email, password: _password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Öğrenci hesabı oluştur')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(
                        labelText: 'Ad soyad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Ad soyad zorunludur.'
                          : null,
                    ),
                    gap,
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: validateEmail,
                    ),
                    gap,
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(
                        labelText: 'Parola',
                        helperText: 'En az 8 karakter; büyük ve küçük harf, rakam, özel karakter',
                        helperMaxLines: 2,
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      validator: validateNewPassword,
                    ),
                    gap,
                    TextFormField(
                      controller: _passwordAgain,
                      decoration: const InputDecoration(
                        labelText: 'Parola (tekrar)',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => value != _password.text
                          ? 'Parolalar eşleşmiyor.'
                          : null,
                    ),
                    if (_error != null) ...[
                      gap,
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kayıt ol'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
