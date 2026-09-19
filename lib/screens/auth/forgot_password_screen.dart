import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _pending = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _pending = true);
    final err = await AuthScope.read(context).sendPasswordReset(_email.text.trim());
    if (!mounted) return;
    setState(() => _pending = false);
    if (err != null) {
      showAuthError(context, err);
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        title: 'Check your email',
        subtitle:
            'If an account exists for that address, we sent a link to reset your password.',
        footer: Text.rich(
          TextSpan(
            text: 'Remember it? ',
            children: [
              TextSpan(
                text: 'Log in',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E8EE)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.brand,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                _email.text.trim(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: 'Back to log in',
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => route.isFirst,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return AuthScaffold(
      title: 'Forgot password',
      subtitle: 'Enter the email you use for FinanceAI.',
      footer: Text.rich(
        TextSpan(
          text: 'Remember it? ',
          children: [
            TextSpan(
              text: 'Log in',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autofocus: true,
              validator: emailValidator,
            ),
            const SizedBox(height: 12),
            const Text(
              'We will email you a secure link to choose a new password.',
              style: TextStyle(
                color: AppColors.mute,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Send reset link',
              pending: _pending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
