import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../dashboard/shell.dart';

/// Demo mode: same dashboard shell as signed-in users, backed by seed data
/// via [AuthController.fake] (controllers load `demo*` fixtures).
class DemoSession extends StatefulWidget {
  const DemoSession({super.key});

  static const demoUser = AuthUser(
    id: 'demo',
    email: 'alex@financeai.app',
    name: 'Alex Rivera',
    onboardingCompleted: true,
    subscriptionActive: true,
  );

  @override
  State<DemoSession> createState() => _DemoSessionState();
}

class _DemoSessionState extends State<DemoSession> {
  late final AuthController _auth = AuthController.fake(user: DemoSession.demoUser);

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _auth.init();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: const DashboardShell(),
    );
  }
}
