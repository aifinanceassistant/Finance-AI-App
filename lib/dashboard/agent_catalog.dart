import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'agent_store.dart' show kGeneralAgentId;
import 'pixel_agent.dart';

export 'pixel_agent.dart' show PixelAgent, PixelAgentId;

class AgentDef {
  const AgentDef({
    required this.id,
    required this.sprite,
    required this.handle,
    required this.title,
    required this.role,
    required this.blurb,
    required this.accent,
    required this.starters,
    required this.replyTemplate,
  });

  final String id;
  final PixelAgentId sprite;
  final String handle;
  final String title;
  final String role;
  final String blurb;
  final Color accent;
  final List<String> starters;
  /// Use `{prompt}` placeholder.
  final String replyTemplate;

  String get label => '$handle · $title';

  String reply(String prompt) {
    final clipped =
        prompt.trim().length > 80 ? '${prompt.trim().substring(0, 80)}…' : prompt.trim();
    return replyTemplate.replaceAll('{prompt}', clipped);
  }
}

const generalAgent = AgentDef(
  id: kGeneralAgentId,
  sprite: PixelAgentId.ops,
  handle: 'FinanceAI',
  title: 'General chat',
  role: 'Open chat',
  blurb: 'Ask anything about your money — not tied to a specialist agent.',
  accent: Color(0xFF64748B),
  starters: [
    'Summarize my finances this month',
    'What should I focus on this week?',
    'Help me plan a spending reset',
  ],
  replyTemplate:
      'On “{prompt}”: here’s a calm read across your space — cash flow looks steady, a few categories deserve a closer look, and your goals still have room to fund. Want to dig deeper here, or switch to a specialist agent?',
);

const personalAgents = <AgentDef>[
  AgentDef(
    id: 'mira',
    sprite: PixelAgentId.coach,
    handle: 'Mira',
    title: 'Budget Coach',
    role: 'Budget Coach',
    blurb: 'Helping to keep monthly budgets honest and calm.',
    accent: AppColors.brand,
    starters: [
      'Where am I overspending this month?',
      'Suggest a tighter dining envelope',
      'How much can I save if I cut 10%?',
    ],
    replyTemplate:
        'Looking at your envelopes against “{prompt}” — Dining is a bit over while Groceries and Transport are still on track. I’d trim dining, park some into Savings, and leave a buffer. Want me to draft those envelope edits?',
  ),
  AgentDef(
    id: 'scout',
    sprite: PixelAgentId.detective,
    handle: 'Scout',
    title: 'Spend Detective',
    role: 'Merchants & anomalies',
    blurb: 'Flags odd charges and duplicate bills.',
    accent: Color(0xFF7C3AED),
    starters: [
      'Any unusual charges lately?',
      'Find duplicate subscriptions',
      'Explain last week’s Amazon total',
    ],
    replyTemplate:
        'I scanned recent merchants for “{prompt}”. A few things stand out — a forgotten trial and clustered same-day purchases. I can draft a rule or mark the trial for cancel.',
  ),
  AgentDef(
    id: 'vega',
    sprite: PixelAgentId.invest,
    handle: 'Vega',
    title: 'Invest Guide',
    role: 'Allocation & risk',
    blurb: 'Talks portfolios without the noise.',
    accent: Color(0xFF0D9488),
    starters: [
      'Is my allocation too aggressive?',
      'What should I do with idle cash?',
      'Summarize my investment mix',
    ],
    replyTemplate:
        'On “{prompt}”: your mix looks equity-heavy with a thin cash buffer. A calm next step is parking 1–2 months of expenses in cash, then rebalancing on the next paycheck. Not advice — just a framing.',
  ),
  AgentDef(
    id: 'atlas',
    sprite: PixelAgentId.goals,
    handle: 'Atlas',
    title: 'Goals Pilot',
    role: 'Targets & timelines',
    blurb: 'Turns goals into funded plans.',
    accent: Color(0xFFF59E0B),
    starters: [
      'Am I on track for vacation?',
      'How much weekly for the emergency fund?',
      'Prioritize my open goals',
    ],
    replyTemplate:
        'For “{prompt}”: keep current transfers going and prioritize the emergency fund unless a trip date is fixed. I can sketch weekly amounts next.',
  ),
  AgentDef(
    id: 'folio',
    sprite: PixelAgentId.tax,
    handle: 'Folio',
    title: 'Tax Notes',
    role: 'Categories & docs',
    blurb: 'Light tax hygiene for your books.',
    accent: Color(0xFFEF4444),
    starters: [
      'Which categories look deductible?',
      'What docs should I keep?',
      'Flag messy labels for tax season',
    ],
    replyTemplate:
        'Regarding “{prompt}”: keep Healthcare, Education, and Donations tidy, and avoid mixing personal shopping into those labels. Educational only — check with a tax pro.',
  ),
  AgentDef(
    id: 'flux',
    sprite: PixelAgentId.ops,
    handle: 'Flux',
    title: 'Ops Agent',
    role: 'Rules & automation',
    blurb: 'Sets rules, merges labels, cleans house.',
    accent: Color(0xFF64748B),
    starters: [
      'Propose merchant rules for groceries',
      'What should I archive?',
      'Clean up overlapping categories',
    ],
    replyTemplate:
        'On “{prompt}”: I’d add contains-rules for common merchants, then archive unused low-traffic labels. Say the word and I’ll stage those in Categories.',
  ),
];

List<AgentDef> agentsForSpace(String spaceId) => personalAgents;

AgentDef agentById(String id, String spaceId) {
  if (id == kGeneralAgentId) return generalAgent;
  for (final a in agentsForSpace(spaceId)) {
    if (a.id == id) return a;
  }
  return generalAgent;
}

/// Web agent avatar = pixel buddy sprite, optically centered in a square.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, required this.agent, this.size = 28});

  final AgentDef agent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: PixelAgent(id: agent.sprite, size: size),
      ),
    );
  }
}
