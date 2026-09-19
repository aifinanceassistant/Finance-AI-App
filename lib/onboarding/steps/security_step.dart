import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
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
    if (_digits.any((c) => c.text.isEmpty)) return;
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            children: [
              const Text(
                'PROTECT YOUR LOGIN',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _setup ? 'Connect an authenticator' : 'Make stolen passwords useless',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _setup
                    ? 'Scan the code in your authenticator app, then enter the 6-digit code.'
                    : 'Add a one-time code from an authenticator app so a password alone cannot open FinanceAI.',
                style: const TextStyle(
                  color: AppColors.mute,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (!_setup) ...[
                _ChoiceCard(
                  title: 'Enable authenticator',
                  body: 'Recommended. Works with Google Authenticator, Authy, 1Password, and more.',
                  onTap: () => setState(() => _setup = true),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  title: 'Continue without 2FA',
                  body: 'You can turn this on later from settings.',
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
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 120,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SelectableText(
                        'NQU6B7LBKUAPXQX6YO7CVBXHQT774DPC',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(
                              text: 'NQU6B7LBKUAPXQX6YO7CVBXHQT774DPC',
                            ),
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
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E6EE),
                              ),
                            ),
                          ),
                          onChanged: (v) => _onDigit(i, v),
                          onTap: () => _digits[i].selection =
                              TextSelection(baseOffset: 0, extentOffset: _digits[i].text.length),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_setup)
          OnboardingActions(
            primaryLabel: 'Verify and continue',
            onPrimary: _complete,
            secondaryLabel: 'Skip for now',
            onSecondary: widget.onSkip,
          )
        else
          OnboardingActions(
            primaryLabel: 'Skip for now',
            onPrimary: widget.onSkip,
          ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E6EE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: const TextStyle(
                        color: AppColors.mute,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mute),
            ],
          ),
        ),
      ),
    );
  }
}
