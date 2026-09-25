import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_scope.dart';
import '../../theme/app_theme.dart';
import '../onboarding_layout.dart';
import '../onboarding_shell.dart';

class SecurityStep extends StatefulWidget {
  const SecurityStep({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  State<SecurityStep> createState() => _SecurityStepState();
}

class _SecurityStepState extends State<SecurityStep> {
  bool _setup = false;
  bool _verified = false;
  bool _enrolling = false;
  bool _verifying = false;
  TotpEnrollment? _enrollment;
  String? _error;
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _beginSetup() async {
    setState(() {
      _setup = true;
      _error = null;
    });
    if (_enrollment != null || _enrolling) return;
    setState(() => _enrolling = true);
    final res = await AuthScope.read(context).startTotpEnrollment();
    if (!mounted) return;
    setState(() {
      _enrolling = false;
      _enrollment = res.enrollment;
      _error = res.error == null ? null : 'Couldn’t start setup: ${res.error}';
    });
  }

  void _clearDigits() {
    for (final c in _digits) {
      c.clear();
    }
    _focus.first.requestFocus();
  }

  void _onDigit(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit.isEmpty) {
      _digits[index].clear();
      return;
    }
    _digits[index].text = digit.characters.last;
    if (index < 5) {
      _focus[index + 1].requestFocus();
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final enrollment = _enrollment;
    if (enrollment == null || _verifying) return;
    if (_digits.any((c) => c.text.isEmpty)) {
      setState(() => _error = 'Enter all six digits from your authenticator.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    final err = await AuthScope.read(context).verifyTotp(
      _digits.map((c) => c.text).join(),
      factorId: enrollment.factorId,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _verifying = false;
        _error = err;
      });
      _clearDigits();
      return;
    }
    setState(() => _verified = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.brand, size: 48),
            SizedBox(height: 12),
            Text(
              'Authenticator connected',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return OnboardingStepScaffold(
      eyebrow: 'PROTECT YOUR LOGIN',
      title: _setup
          ? 'Connect an authenticator'
          : 'Make stolen passwords useless',
      subtitle: _setup
          ? 'Scan the code in your authenticator app, then enter the 6-digit code.'
          : 'Add a one-time code from an authenticator app so a password alone cannot open FinanceAI.',
      body: [
        if (!_setup) ...[
          OnboardingChoiceTile(
            label: 'Enable authenticator',
            body: 'Recommended. Works with Google Authenticator, Authy, 1Password, and more.',
            selected: false,
            onTap: _beginSetup,
          ),
          OnboardingChoiceTile(
            label: 'Continue without 2FA',
            body: 'You can turn this on later from settings.',
            selected: false,
            onTap: widget.onSkip,
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E6EE)),
            ),
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _enrollment != null
                      ? QrImageView(
                          data: _enrollment!.uri,
                          size: 150,
                          backgroundColor: Colors.white,
                        )
                      : _enrolling
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: AppColors.mute,
                        ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'On this phone? Copy the key into your authenticator app instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mute, fontSize: 12),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _enrollment?.secret ?? '',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enrollment == null
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: _enrollment!.secret),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Secret copied'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: const Text('Copy setup key'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enter 6-digit code',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                SizedBox(
                  width: 46,
                  child: TextField(
                    controller: _digits[i],
                    focusNode: _focus[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E6EE)),
                      ),
                    ),
                    enabled: _enrollment != null && !_verifying,
                    onChanged: (v) => _onDigit(i, v),
                    onTap: () => _digits[i].selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _digits[i].text.length,
                    ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFC44B4B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ],
      actions: _setup
          ? OnboardingActions(
              primaryLabel: _verifying ? 'Verifying…' : 'Verify and continue',
              onPrimary: _verifying ? () {} : _complete,
              secondaryLabel: 'Skip for now',
              onSecondary: widget.onSkip,
            )
          : OnboardingActions(
              primaryLabel: 'Skip for now',
              onPrimary: widget.onSkip,
            ),
    );
  }
}
