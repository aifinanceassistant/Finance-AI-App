import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'magic_link_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = true;
  bool _pending = false;
  bool _oauthPending = false;
  bool _rememberLoaded = false;
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
    if (!_rememberLoaded) {
      _rememberLoaded = true;
      // ignore: discarded_futures
      auth.getRememberMe().then((value) {
        if (mounted) setState(() => _remember = value);
      });
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _pending = true);
    final err = await AuthScope.read(context).login(
      _email.text.trim(),
      _password.text,
      remember: _remember,
    );
    if (!mounted) return;
    setState(() => _pending = false);
    if (err != null) {
      showAuthError(context, err);
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to keep your finances on track.',
      footer: Text.rich(
        TextSpan(
          text: "Don't have an account? ",
          children: [
            TextSpan(
              text: 'Sign up',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
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
                mode: SocialAuthMode.login,
                pending: _oauthPending,
                onMagicLink: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MagicLinkScreen(
                        intent: MagicLinkIntent.login,
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
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      activeColor: AppColors.ink,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Remember me',
                      style: TextStyle(
                        color: AppColors.mute,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: 'Log in',
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
