import 'package:flutter/material.dart';

import 'accounts_scope.dart';
import 'agent_layouts.dart';
import 'agent_session.dart';
import 'goals_scope.dart';
import 'spaces_scope.dart';

/// Full-screen agent experience — locked to Drawer layout.
class AgentModeSurface extends StatefulWidget {
  const AgentModeSurface({super.key});

  @override
  State<AgentModeSurface> createState() => _AgentModeSurfaceState();
}

class _AgentModeSurfaceState extends State<AgentModeSurface> {
  late final AgentSession _session = AgentSession();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SpacesScope.maybeOf(context);
    AccountsScope.maybeOf(context);
    GoalsScope.maybeOf(context);
    _session.attach(context);

    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        return AgentLayoutDrawer(session: _session);
      },
    );
  }
}
