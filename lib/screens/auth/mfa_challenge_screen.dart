import 'package:flutter/material.dart';

import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// Shown when the session has a verified TOTP factor but is still aal1.
class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _code = TextEditingController();
  bool _pending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      showAuthError(
        context,
        'Enter the six-digit code from your authenticator',
      );
      return;
    }
    setState(() => _pending = true);
    final err = await AuthScope.read(context).verifyTotp(code);
    if (!mounted) return;
    setState(() => _pending = false);
    if (err != null) {
      _code.clear();
      showAuthError(context, err);
      return;
    }
    await goToDestination(context);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthScope.of(context).user?.email;
    return AuthScaffold(
      title: 'Two-step verification',
      subtitle: email == null
          ? 'Enter the code from your authenticator app to finish signing in.'
          : 'Signed in as $email. Enter the code from your authenticator app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'Authentication code',
            controller: _code,
            hint: '123456',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            autofocus: true,
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            label: 'Verify',
            pending: _pending,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          const Text(
            'Lost access to your authenticator? Contact support and we’ll verify your identity.',
            style: TextStyle(fontSize: 12, color: AppColors.mute, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await goLoggedOut(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.mute),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
