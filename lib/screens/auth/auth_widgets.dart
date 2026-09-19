import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Shared chrome for auth screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: AppColors.ink,
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom * 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.mute,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: 28),
                        DefaultTextStyle(
                          style: const TextStyle(
                            color: AppColors.mute,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          child: footer!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          validator: validator,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFB0B4BC),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFF7F9FB),
            contentPadding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E8EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E8EE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCC4444)),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint = '••••••••',
    this.autofillHints = const [AutofillHints.password],
    this.minLength,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Iterable<String> autofillHints;
  final int? minLength;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      obscureText: !_show,
      autofillHints: widget.autofillHints,
      textInputAction: TextInputAction.done,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Enter your password';
        if (widget.minLength != null && text.length < widget.minLength!) {
          return 'Use at least ${widget.minLength} characters';
        }
        return null;
      },
      suffix: IconButton(
        onPressed: () => setState(() => _show = !_show),
        icon: Icon(
          _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: const Color(0xFF8B8F98),
        ),
        tooltip: _show ? 'Hide password' : 'Show password',
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFE8ECF1))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'OR',
              style: TextStyle(
                color: Color(0xFFA0A4AD),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(child: Divider(color: Color(0xFFE8ECF1))),
        ],
      ),
    );
  }
}

enum SocialAuthMode { login, register }

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.mode,
    this.onMagicLink,
    this.onGoogle,
    this.onApple,
    this.pending = false,
  });

  final SocialAuthMode mode;
  final VoidCallback? onMagicLink;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool pending;

  String get _verb => mode == SocialAuthMode.login ? 'Continue' : 'Sign up';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onMagicLink != null) ...[
          _SocialButton(
            label: 'Email me a magic link',
            onPressed: pending ? null : onMagicLink,
            leading: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 10),
        ],
        _SocialButton(
          label: pending ? 'Redirecting…' : '$_verb with Google',
          onPressed: pending
              ? null
              : onGoogle ?? () => _toast(context, 'Google sign-in comes next'),
          leading: const _GoogleMark(),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: pending ? 'Redirecting…' : '$_verb with Apple',
          onPressed: pending
              ? null
              : onApple ?? () => _toast(context, 'Apple sign-in comes next'),
          leading: const Icon(Icons.apple, size: 20, color: Colors.white),
          filled: true,
        ),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.onPressed,
    required this.leading,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget leading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE4E8EE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

/// Official multicolor “G” — same paths as the web auth buttons.
class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18, size.height / 18);

    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final red = Paint()..color = const Color(0xFFEA4335);

    // Blue — top-right arm
    canvas.drawPath(
      Path()
        ..moveTo(17.64, 9.2)
        ..relativeCubicTo(0, -0.637, -0.057, -1.251, -0.164, -1.84)
        ..lineTo(9, 7.36)
        ..relativeLineTo(0, 3.481)
        ..relativeLineTo(4.844, 0)
        ..relativeCubicTo(-0.209, 1.125, -0.843, 2.078, -1.796, 2.717)
        ..relativeLineTo(0, 2.258)
        ..relativeLineTo(2.908, 0)
        ..relativeCubicTo(1.702, -1.567, 2.684, -3.874, 2.684, -6.615)
        ..close(),
      blue,
    );

    // Green — bottom
    canvas.drawPath(
      Path()
        ..moveTo(9, 18)
        ..relativeCubicTo(2.43, 0, 4.467, -0.806, 5.956, -2.18)
        ..relativeLineTo(-2.908, -2.259)
        ..relativeCubicTo(-0.806, 0.54, -1.837, 0.86, -3.048, 0.86)
        ..relativeCubicTo(-2.344, 0, -4.328, -1.584, -5.036, -3.711)
        ..lineTo(0.957, 10.71)
        ..relativeLineTo(0, 2.332)
        ..arcToPoint(
          const Offset(9, 18),
          radius: const Radius.circular(8.997),
          clockwise: false,
        )
        ..close(),
      green,
    );

    // Yellow — mid-left
    canvas.drawPath(
      Path()
        ..moveTo(3.964, 10.71)
        ..arcToPoint(
          const Offset(3.682, 9),
          radius: const Radius.circular(5.41),
          clockwise: true,
        )
        ..relativeCubicTo(0, -0.593, 0.102, -1.17, 0.282, -1.71)
        ..lineTo(3.964, 4.958)
        ..lineTo(0.957, 4.958)
        ..arcToPoint(
          const Offset(0, 9),
          radius: const Radius.circular(8.996),
          clockwise: false,
        )
        ..relativeCubicTo(0, 1.452, 0.348, 2.827, 0.957, 4.042)
        ..lineTo(3.964, 10.71)
        ..close(),
      yellow,
    );

    // Red — top
    canvas.drawPath(
      Path()
        ..moveTo(9, 3.58)
        ..relativeCubicTo(1.321, 0, 2.508, 0.454, 3.44, 1.345)
        ..relativeLineTo(2.582, -2.58)
        ..cubicTo(13.463, 0.891, 11.426, 0, 9, 0)
        ..arcToPoint(
          const Offset(0.957, 4.958),
          radius: const Radius.circular(8.997),
          clockwise: false,
        )
        ..lineTo(3.964, 7.29)
        ..cubicTo(4.672, 5.163, 6.656, 3.58, 9, 3.58)
        ..close(),
      red,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.pending = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: pending ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: pending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

String? emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your email';
  if (!text.contains('@') || !text.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}
