import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';
import 'magic_link_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _pending = false;
  bool _oauthPending = false;
  AuthController? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.read(context);
    if (!identical(_auth, auth)) {
      _auth?.removeListener(_onAuthChanged);
      _auth = auth;
      _auth!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    final auth = _auth;
    if (!mounted || auth == null || auth.isFake || !auth.isSignedIn) return;
    goAfterAuth(context);
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Privacy Policy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _pending = true);
    final result = await AuthScope.read(context).register(
      _email.text.trim(),
      _password.text,
      _name.text.trim(),
    );
    if (!mounted) return;
    setState(() => _pending = false);
    if (result.error != null) {
      showAuthError(context, result.error!);
      return;
    }
    if (result.needsEmailConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check your email to confirm your account, then come back to log in.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await goAfterAuth(context);
  }

  Future<void> _oauth(OAuthProvider provider) async {
    setState(() => _oauthPending = true);
    final auth = AuthScope.read(context);
    final err = await auth.signInWithOAuth(provider);
    if (!mounted) return;
    setState(() => _oauthPending = false);
    if (err != null) {
      showAuthError(context, err);
      return;
    }
    if (auth.isFake && auth.isSignedIn) {
      await goAfterAuth(context);
    }
  }

  void _showLegal(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.mute,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start budgeting with your household in a few minutes.',
      footer: Text.rich(
        TextSpan(
          text: 'Already have an account? ',
          children: [
            TextSpan(
              text: 'Log in',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
            ),
          ],
        ),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SocialAuthButtons(
                mode: SocialAuthMode.register,
                pending: _oauthPending,
                onMagicLink: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MagicLinkScreen(
                        intent: MagicLinkIntent.register,
                        initialEmail: _email.text.trim(),
                      ),
                    ),
                  );
                },
                onGoogle: () => _oauth(OAuthProvider.google),
                onApple: () => _oauth(OAuthProvider.apple),
              ),
              const AuthDivider(),
              AuthTextField(
                label: 'Full name',
                controller: _name,
                hint: 'Alex Rivera',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if ((value?.trim().isEmpty ?? true)) {
                    return 'Enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: emailValidator,
              ),
              const SizedBox(height: 14),
              AuthPasswordField(
                controller: _password,
                hint: 'At least 8 characters',
                autofillHints: const [AutofillHints.newPassword],
                minLength: 8,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: AppColors.ink,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: const TextStyle(
                          color: AppColors.mute,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showLegal(
                                    'Terms of Service',
                                    'FinanceAI terms will appear here. This is a placeholder for the mobile app.',
                                  ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showLegal(
                                    'Privacy Policy',
                                    'FinanceAI privacy details will appear here. This is a placeholder for the mobile app.',
                                  ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: 'Create account',
                pending: _pending,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
