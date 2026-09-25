import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const kGeneralAgentId = 'general';

class AgentChatMessage {
  const AgentChatMessage({
    required this.id,
    required this.role,
    required this.text,
  });

  final String id;
  final String role; // user | assistant
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
      };

  factory AgentChatMessage.fromJson(Map<String, dynamic> json) {
    return AgentChatMessage(
      id: (json['id'] as String?) ?? _newId('msg'),
      role: (json['role'] as String?) == 'assistant' ? 'assistant' : 'user',
      text: (json['text'] as String?) ?? '',
    );
  }
}

class AgentChatThread {
  AgentChatThread({
    required this.id,
    required this.spaceId,
    required this.agentId,
    required this.title,
    required this.updatedAt,
    this.pinned = false,
    List<AgentChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  final String spaceId;
  final String agentId;
  String title;
  int updatedAt;
  bool pinned;
  final List<AgentChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'spaceId': spaceId,
        'agentId': agentId,
        'title': title,
        'updatedAt': updatedAt,
        'pinned': pinned,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AgentChatThread.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    final msgs = <AgentChatMessage>[];
    if (rawMsgs is List) {
      for (final m in rawMsgs) {
        if (m is Map<String, dynamic>) {
          msgs.add(AgentChatMessage.fromJson(m));
        } else if (m is Map) {
          msgs.add(AgentChatMessage.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return AgentChatThread(
      id: (json['id'] as String?) ?? _newId('thread'),
      spaceId: (json['spaceId'] as String?) ?? '',
      agentId: (json['agentId'] as String?) ?? kGeneralAgentId,
      title: (json['title'] as String?) ?? 'New chat',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      pinned: json['pinned'] == true,
      messages: msgs,
    );
  }
}

String _newId(String prefix) {
  final rand = Random().nextInt(0xFFFF).toRadixString(16);
  return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$rand';
}

String titleFromMessages(List<AgentChatMessage> messages) {
  AgentChatMessage? first;
  for (final m in messages) {
    if (m.role == 'user') {
      first = m;
      break;
    }
  }
  if (first == null) return 'New chat';
  final t = first.text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return 'New chat';
  return t.length > 48 ? '${t.substring(0, 48)}…' : t;
}

/// Simulated assistant replies (mirrors web localStorage agent — no LLM).
String simulateAssistantReply(
  String prompt, {
  String? balanceSummary,
  String? goalSummary,
}) {
  final clipped = prompt.trim();
  final short = clipped.length > 80 ? '${clipped.substring(0, 80)}…' : clipped;
  final lower = clipped.toLowerCase();

  if (lower.contains('goal') || lower.contains('save') || lower.contains('fund')) {
    final ctx = goalSummary == null || goalSummary.isEmpty
        ? 'Your open goals still have room to fund'
        : goalSummary;
    return 'On “$short”: $ctx. A calm next step is picking one priority goal and '
        'automating a small weekly transfer. Want a draft plan?';
  }

  if (lower.contains('balance') ||
      lower.contains('net worth') ||
      lower.contains('cash') ||
      lower.contains('account')) {
    final ctx = balanceSummary == null || balanceSummary.isEmpty
        ? 'Balances look steady across linked accounts'
        : balanceSummary;
    return 'Looking at “$short” — $ctx. I can break this down by account type '
        'or flag idle cash if you want a closer pass.';
  }

  if (lower.contains('spend') ||
      lower.contains('budget') ||
      lower.contains('over')) {
    return 'On “$short”: cash flow looks manageable, though a couple of '
        'categories may deserve a closer look this month. Want me to suggest '
        'a tighter envelope, or summarize recent merchants?';
  }

  final bal = balanceSummary == null || balanceSummary.isEmpty
      ? null
      : balanceSummary;
  final goal = goalSummary == null || goalSummary.isEmpty ? null : goalSummary;
  final bits = [
    ?bal,
    ?goal,
  ];
  final ctx = bits.isEmpty
      ? 'cash flow looks steady and your goals still have room to fund'
      : bits.join(' · ');

  return 'On “$short”: here’s a calm read across your space — $ctx. '
      'Want to dig deeper here, or ask about balances, spending, or goals?';
}

class AgentChatStore {
  AgentChatStore._();

  static const _prefsKey = 'financeai-agent-threads';

  static Future<List<AgentChatThread>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return [];
      final parsed = jsonDecode(raw);
      if (parsed is! List) return [];
      final out = <AgentChatThread>[];
      for (final item in parsed) {
        if (item is Map<String, dynamic>) {
          out.add(AgentChatThread.fromJson(item));
        } else if (item is Map) {
          out.add(AgentChatThread.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<AgentChatThread> threads) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(threads.map((t) => t.toJson()).toList()),
      );
    } catch (_) {
      /* ignore */
    }
  }

  static Future<List<AgentChatThread>> threadsForSpace(String spaceId) async {
    final all = await loadAll();
    final filtered = all.where((t) => t.spaceId == spaceId).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return filtered;
  }

  static AgentChatThread createThread({
    required String spaceId,
    String agentId = kGeneralAgentId,
  }) {
    return AgentChatThread(
      id: _newId('thread'),
      spaceId: spaceId,
      agentId: agentId,
      title: 'New chat',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> upsert(AgentChatThread thread) async {
    final all = await loadAll();
    final idx = all.indexWhere((t) => t.id == thread.id);
    if (idx >= 0) {
      all[idx] = thread;
    } else {
      all.insert(0, thread);
    }
    await saveAll(all);
  }

  static Future<void> delete(String threadId) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == threadId);
    await saveAll(all);
  }
}
