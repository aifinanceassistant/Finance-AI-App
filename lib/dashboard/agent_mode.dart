import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dash_colors.dart';
import 'pixel_agent.dart';

const kAgentModePrefsKey = 'financeai-agent-mode';
const kAgentIdsPrefsKey = 'financeai-agent-ids';

Future<bool> readStoredAgentMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kAgentModePrefsKey) == '1';
}

Future<void> writeStoredAgentMode(bool on) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kAgentModePrefsKey, on ? '1' : '0');
}

Future<Map<String, String>> readStoredAgentIds() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kAgentIdsPrefsKey);
  if (raw == null || raw.isEmpty) return {};
  try {
    final map = <String, String>{};
    for (final part in raw.split('&')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      map[Uri.decodeComponent(part.substring(0, i))] =
          Uri.decodeComponent(part.substring(i + 1));
    }
    return map;
  } catch (_) {
    return {};
  }
}

Future<void> writeStoredAgentIds(Map<String, String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = ids.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
  await prefs.setString(kAgentIdsPrefsKey, encoded);
}

/// Plain pixel-agent icon in the top chrome — no blue chip / background.
class AgentModeToggle extends StatelessWidget {
  const AgentModeToggle({
    super.key,
    required this.on,
    required this.onToggle,
  });

  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: on ? 'Exit agent mode' : 'Agent mode',
      onPressed: onToggle,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: context.dashInk,
        shadowColor: Colors.transparent,
      ),
      icon: Opacity(
        opacity: on ? 1 : 0.72,
        child: const PixelAgent(id: PixelAgentId.coach, size: 24),
      ),
    );
  }
}
