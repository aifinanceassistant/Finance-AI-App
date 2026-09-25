import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'demo_session.dart';
import 'landing/landing_variants.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LandingClassic(
        onStarted: () => _goRegister(context),
        onLogin: () => _goLogin(context),
        onDemo: () => _goDemo(context),
      ),
    );
  }

  void _goRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  void _goDemo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DemoSession()),
    );
  }
}
