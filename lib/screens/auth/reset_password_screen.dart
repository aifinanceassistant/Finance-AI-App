import 'package:flutter/material.dart';

import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_password.text != _confirm.text) {
      showAuthError(context, 'Passwords don’t match');
      return;
    }
    setState(() => _pending = true);
    final err = await AuthScope.read(context).updatePassword(_password.text);
    if (!mounted) return;
    setState(() => _pending = false);
    if (err != null) {
      showAuthError(context, err);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await goAfterAuth(context);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthScope.of(context).user?.email;
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: email == null
          ? 'Pick a new password to finish resetting your account.'
          : 'Signed in as $email. Pick a new password to finish.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPasswordField(
              controller: _password,
              label: 'New password',
              autofillHints: const [AutofillHints.newPassword],
              minLength: 8,
            ),
            const SizedBox(height: 14),
            AuthPasswordField(
              controller: _confirm,
              label: 'Confirm password',
              autofillHints: const [AutofillHints.newPassword],
              minLength: 8,
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(
              label: 'Update password',
              pending: _pending,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await goLoggedOut(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.mute),
              child: const Text('Cancel and sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
