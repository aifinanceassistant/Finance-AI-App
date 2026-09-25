import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'accounts_scope.dart';
import 'agent_catalog.dart';
import 'agent_store.dart';
import 'data.dart';
import 'goals_scope.dart';
import 'spaces_scope.dart';
import 'ui.dart';

/// Shared agent-mode session (threads, agent selection, send).
class AgentSession extends ChangeNotifier {
  AgentSession();

  String agentId = kGeneralAgentId;
  AgentChatThread? active;
  List<AgentChatThread> threads = [];
  bool loading = true;
  bool awaitingReply = false;
  String? loadedSpace;
  final compose = TextEditingController();
  final scroll = ScrollController();

  BuildContext? _ctx;

  void attach(BuildContext context) {
    _ctx = context;
    final id = spaceId;
    if (loadedSpace != null && loadedSpace != id) {
      active = null;
      agentId = kGeneralAgentId;
      // ignore: discarded_futures
      reload();
    } else if (loadedSpace == null) {
      // ignore: discarded_futures
      reload();
    }
  }

  String get spaceId {
    final id = _ctx == null ? null : SpacesScope.maybeOf(_ctx!)?.spaceId;
    if (id != null && id.isNotEmpty) return id;
    return 'local';
  }

  List<AgentDef> get roster {
    final list = agentsForSpace(spaceId);
    return [generalAgent, ...list];
  }

  AgentDef get agent => agentById(agentId, spaceId);

  List<AgentChatThread> get sortedThreads {
    final list = [...threads]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return list;
  }

  @override
  void dispose() {
    compose.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final id = spaceId;
    loading = true;
    notifyListeners();
    final list = await AgentChatStore.threadsForSpace(id);
    loadedSpace = id;
    threads = list;
    loading = false;
    if (active != null) {
      final match = list.where((t) => t.id == active!.id);
      active = match.isEmpty ? null : match.first;
      if (active != null) agentId = active!.agentId;
    }
    notifyListeners();
  }

  void selectAgent(String id) {
    agentId = id;
    active = null;
    notifyListeners();
  }

  Future<void> newChat() async {
    final thread = AgentChatStore.createThread(
      spaceId: spaceId,
      agentId: agentId,
    );
    await AgentChatStore.upsert(thread);
    threads = [thread, ...threads];
    active = thread;
    notifyListeners();
  }

  void openThread(AgentChatThread thread) {
    active = thread;
    agentId = thread.agentId;
    notifyListeners();
  }

  void clearActive() {
    active = null;
    notifyListeners();
  }

  Future<void> togglePin(AgentChatThread thread) async {
    thread.pinned = !thread.pinned;
    thread.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await AgentChatStore.upsert(thread);
    await reload();
  }

  Future<void> deleteThread(AgentChatThread thread) async {
    await AgentChatStore.delete(thread.id);
    threads = threads.where((t) => t.id != thread.id).toList();
    if (active?.id == thread.id) active = null;
    notifyListeners();
    final ctx = _ctx;
    if (ctx != null && ctx.mounted) toast(ctx, 'Chat deleted');
  }

  String? _balanceSummary() {
    final ctx = _ctx;
    if (ctx == null) return null;
    final accounts = AccountsScope.maybeOf(ctx)?.accounts;
    if (accounts == null || accounts.isEmpty) return null;
    final total = accounts.fold<double>(0, (s, a) => s + a.balance);
    final n = accounts.length;
    return n == 1
        ? 'You’re sitting on ${money(total)} in 1 account'
        : 'You’re sitting on ${money(total)} across $n accounts';
  }

  String? _goalSummary() {
    final ctx = _ctx;
    if (ctx == null) return null;
    final goals = GoalsScope.maybeOf(ctx)?.goals;
    if (goals == null || goals.isEmpty) return null;
    final g = goals.first;
    final pct = g.target <= 0 ? 0 : ((g.saved / g.target) * 100).round();
    return '${g.name} is $pct% funded (${money(g.saved)} of ${money(g.target)})';
  }

  Future<void> send([String? preset]) async {
    final text = (preset ?? compose.text).trim();
    if (text.isEmpty || awaitingReply) return;

    var thread = active;
    if (thread == null) {
      thread = AgentChatStore.createThread(
        spaceId: spaceId,
        agentId: agentId,
      );
      threads = [thread, ...threads];
      active = thread;
    }

    thread.messages.add(
      AgentChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}-u',
        role: 'user',
        text: text,
      ),
    );
    thread.title = titleFromMessages(thread.messages);
    thread.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (preset == null) compose.clear();
    awaitingReply = true;
    notifyListeners();
    await AgentChatStore.upsert(thread);
    _scrollToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 700));

    var reply = agent.reply(text);
    final bal = _balanceSummary();
    final goal = _goalSummary();
    if (bal != null || goal != null) {
      final bits = [if (bal != null) bal, if (goal != null) goal].join('. ');
      reply = '$reply\n\n$bits.';
    }

    thread.messages.add(
      AgentChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}-a',
        role: 'assistant',
        text: reply,
      ),
    );
    thread.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await AgentChatStore.upsert(thread);
    awaitingReply = false;
    threads = [thread, ...threads.where((t) => t.id != thread!.id)];
    active = thread;
    notifyListeners();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }
}

/// Shared chat message list + composer used by layouts.
class AgentChatPane extends StatelessWidget {
  const AgentChatPane({
    super.key,
    required this.session,
    this.showHeader = false,
    this.empty,
  });

  final AgentSession session;
  final bool showHeader;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final active = session.active;
    if (active == null) {
      return empty ?? AgentEmptyPane(session: session);
    }
    return Column(
      children: [
        if (showHeader) AgentChatHeader(session: session),
        Expanded(child: AgentMessageList(session: session, thread: active)),
        AgentComposer(session: session),
      ],
    );
  }
}

class AgentChatHeader extends StatelessWidget {
  const AgentChatHeader({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    final agent = session.agent;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.panelDark
            : AppColors.panel,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.lineDark
                : AppColors.line,
          ),
        ),
      ),
      child: Row(
        children: [
          AgentAvatar(agent: agent, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.active?.title ?? agent.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.inkDark
                    : AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgentEmptyPane extends StatelessWidget {
  const AgentEmptyPane({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    final agent = session.agent;
    final ink = Theme.of(context).brightness == Brightness.dark
        ? AppColors.inkDark
        : AppColors.ink;
    final mute = Theme.of(context).brightness == Brightness.dark
        ? AppColors.muteDark
        : AppColors.mute;
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppColors.panelDark
        : AppColors.panel;
    final line = Theme.of(context).brightness == Brightness.dark
        ? AppColors.lineDark
        : AppColors.line;

    final starters = [
      ...agent.starters.take(2),
      'Generate a photo of this month’s spend story',
      'Generate an infographic of my top categories',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AgentAvatar(agent: agent, size: 48),
        ),
        const SizedBox(height: 18),
        Text(
          'Hey, I’m ${agent.handle}!',
          style: TextStyle(
            color: ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          agent.title.toUpperCase(),
          style: TextStyle(
            color: mute.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          agent.blurb,
          style: TextStyle(color: mute, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 28),
        for (final s in starters)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => session.send(s),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: line),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AgentMessageList extends StatelessWidget {
  const AgentMessageList({
    super.key,
    required this.session,
    required this.thread,
  });

  final AgentSession session;
  final AgentChatThread thread;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).brightness == Brightness.dark
        ? AppColors.inkDark
        : AppColors.ink;
    final mute = Theme.of(context).brightness == Brightness.dark
        ? AppColors.muteDark
        : AppColors.mute;

    return ListView.builder(
      controller: session.scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: thread.messages.length + (session.awaitingReply ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= thread.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AgentAvatar(agent: session.agent, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thinking…',
                  style: TextStyle(
                    color: mute,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          );
        }
        final m = thread.messages[i];
        final mine = m.role == 'user';
        if (mine) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    m.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AgentAvatar(agent: session.agent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: ink,
                      fontSize: 15,
                      height: 1.65,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AgentComposer extends StatelessWidget {
  const AgentComposer({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceDark
        : AppColors.surface;
    final panel = Theme.of(context).brightness == Brightness.dark
        ? AppColors.panelDark
        : AppColors.panel;
    final line = Theme.of(context).brightness == Brightness.dark
        ? AppColors.lineDark
        : AppColors.line;

    return Material(
      color: panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: session.compose,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => session.send(),
                decoration: InputDecoration(
                  hintText: 'Ask ${session.agent.handle}…',
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: session.awaitingReply ? null : () => session.send(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.brand.withValues(alpha: 0.35),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
