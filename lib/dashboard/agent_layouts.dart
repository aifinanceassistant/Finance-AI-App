import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../variations/models.dart';
import 'agent_catalog.dart';
import 'agent_session.dart';
import 'agent_store.dart';
import 'dash_colors.dart';

class AgentLayoutSwitcher extends StatelessWidget {
  const AgentLayoutSwitcher({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final AgentLayoutVariation selected;
  final ValueChanged<AgentLayoutVariation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.dashPanel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dashLine)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Layout preview — pick one',
              style: TextStyle(
                color: context.dashMute,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AgentLayoutVariation.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final v = AgentLayoutVariation.values[i];
                  final on = v == selected;
                  return Material(
                    color: on
                        ? AppColors.brand.withValues(alpha: 0.12)
                        : context.dashSurface,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: () => onSelect(v),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? AppColors.brand.withValues(alpha: 0.45)
                                : context.dashLine,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              v.icon,
                              size: 14,
                              color: on ? AppColors.brand : context.dashMute,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              v.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    on ? FontWeight.w800 : FontWeight.w600,
                                color: on ? AppColors.brand : context.dashInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 2),
            Text(
              selected.blurb,
              style: TextStyle(
                color: context.dashMute,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgentLayoutHost extends StatelessWidget {
  const AgentLayoutHost({
    super.key,
    required this.variation,
    required this.session,
  });

  final AgentLayoutVariation variation;
  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    if (session.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return switch (variation) {
      AgentLayoutVariation.web => AgentLayoutWeb(session: session),
      AgentLayoutVariation.drawer => AgentLayoutDrawer(session: session),
      AgentLayoutVariation.strip => AgentLayoutStrip(session: session),
    };
  }
}

// ── Shared sidebar (web AGENTS + Recents) ───────────────────────────────────

class AgentSidebarPanel extends StatelessWidget {
  const AgentSidebarPanel({
    super.key,
    required this.session,
    this.onPicked,
  });

  final AgentSession session;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.dashPanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Text(
              'AGENTS',
              style: TextStyle(
                color: context.dashMute,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                for (final a in session.roster)
                  _SidebarAgentTile(
                    agent: a,
                    selected: session.agentId == a.id &&
                        (session.active == null ||
                            session.active!.agentId == a.id),
                    onTap: () {
                      session.selectAgent(a.id);
                      onPicked?.call();
                    },
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'RECENTS',
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'New chat',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          // ignore: discarded_futures
                          session.newChat();
                          onPicked?.call();
                        },
                        icon: Icon(
                          Icons.edit_square,
                          size: 18,
                          color: context.dashMute,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.sortedThreads.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'No chats yet',
                      style: TextStyle(color: context.dashMute, fontSize: 12),
                    ),
                  )
                else
                  for (final t in session.sortedThreads)
                    _SidebarThreadTile(
                      thread: t,
                      agent: agentById(t.agentId, session.spaceId),
                      selected: session.active?.id == t.id,
                      onTap: () {
                        session.openThread(t);
                        onPicked?.call();
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAgentTile extends StatelessWidget {
  const _SidebarAgentTile({
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final AgentDef agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              AgentAvatar(agent: agent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  agent.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.dashInk,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
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

class _SidebarThreadTile extends StatelessWidget {
  const _SidebarThreadTile({
    required this.thread,
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final AgentChatThread thread;
  final AgentDef agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.brand.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              AgentAvatar(agent: agent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.dashInk,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
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

class _ChatChrome extends StatelessWidget {
  const _ChatChrome({
    required this.session,
    this.leading,
  });

  final AgentSession session;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final agent = session.agent;
    final title = session.active?.title ?? agent.handle;
    final subtitle = session.active == null ? agent.title : null;

    return Material(
      color: context.dashPanel,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.dashLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ?leading,
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.dashInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.dashMute,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'New chat',
              onPressed: session.newChat,
              icon: Icon(Icons.edit_square, color: context.dashInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web desktop: sidebar (agents + recents) | chat workspace.
class AgentLayoutWeb extends StatelessWidget {
  const AgentLayoutWeb({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.dashLine)),
            ),
            child: AgentSidebarPanel(session: session),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF7F7F8),
            child: Column(
              children: [
                _ChatChrome(session: session),
                Expanded(child: AgentChatPane(session: session)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full chat; menu opens agents + recents drawer.
class AgentLayoutDrawer extends StatelessWidget {
  const AgentLayoutDrawer({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F8),
      child: Column(
        children: [
          _ChatChrome(
            session: session,
            leading: IconButton(
              tooltip: 'Agents & history',
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: context.dashPanel,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (ctx) {
                    return SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.72,
                      child: AgentSidebarPanel(
                        session: session,
                        onPicked: () => Navigator.pop(ctx),
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.menu_rounded, color: context.dashInk),
            ),
          ),
          Expanded(child: AgentChatPane(session: session)),
        ],
      ),
    );
  }
}

/// Horizontal pixel-agent strip + chat.
class AgentLayoutStrip extends StatelessWidget {
  const AgentLayoutStrip({super.key, required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F8),
      child: Column(
        children: [
          _ChatChrome(
            session: session,
            leading: IconButton(
              tooltip: 'History',
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: context.dashPanel,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  builder: (ctx) {
                    return SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.55,
                      child: AgentSidebarPanel(
                        session: session,
                        onPicked: () => Navigator.pop(ctx),
                      ),
                    );
                  },
                );
              },
              icon: Icon(Icons.history_rounded, color: context.dashInk),
            ),
          ),
          Material(
            color: context.dashPanel,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.dashLine)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: session.roster.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final a = session.roster[i];
                  final on = session.agentId == a.id;
                  return InkWell(
                    onTap: () => session.selectAgent(a.id),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: on
                            ? a.accent.withValues(alpha: 0.12)
                            : context.dashSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: on
                              ? a.accent.withValues(alpha: 0.4)
                              : context.dashLine,
                        ),
                      ),
                      child: Row(
                        children: [
                          AgentAvatar(agent: a, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            a.handle,
                            style: TextStyle(
                              fontWeight:
                                  on ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                              color: context.dashInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(child: AgentChatPane(session: session)),
        ],
      ),
    );
  }
}
