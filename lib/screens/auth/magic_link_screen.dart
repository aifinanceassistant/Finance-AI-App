import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_navigation.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

enum MagicLinkIntent { login, register }

class MagicLinkScreen extends StatefulWidget {
  const MagicLinkScreen({
    super.key,
    required this.intent,
    this.initialEmail = '',
  });

  final MagicLinkIntent intent;
  final String initialEmail;

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends State<MagicLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _pending = false;
  bool _sent = false;
  AuthController? _auth;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

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
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _pending = true);
    final err = await AuthScope.read(context).sendMagicLink(_email.text.trim());
    if (!mounted) return;
    setState(() => _pending = false);
    if (err != null) {
      showAuthError(context, err);
      return;
    }
    setState(() => _sent = true);
  }

  String get _title {
    if (_sent) return 'Check your email';
    return widget.intent == MagicLinkIntent.login
        ? 'Log in with email'
        : 'Sign up with email';
  }

  String get _subtitle {
    if (_sent) {
      return 'We sent a sign-in link to ${_email.text.trim()}.';
    }
    return "We'll send a magic link. No password needed.";
  }

  String get _cta => 'Email me a magic link';

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _title,
      subtitle: _subtitle,
      footer: Text.rich(
        TextSpan(
          text: 'Prefer a password? ',
          children: [
            TextSpan(
              text: widget.intent == MagicLinkIntent.login
                  ? 'Log in the usual way'
                  : 'Sign up the usual way',
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
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4E8EE)),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.outgoing_mail,
                        color: AppColors.brand,
                        size: 36,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Open the link on this device within 15 minutes to finish.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mute,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AuthPrimaryButton(
                  label: 'Use a different email',
                  onPressed: () => setState(() => _sent = false),
                ),
              ],
            )
          : Form(
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
                    "We'll email a one-time link. Open it on this device to finish signing in. The link expires in 15 minutes.",
                    style: TextStyle(
                      color: AppColors.mute,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: _cta,
                    pending: _pending,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}
