import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'shell.dart';
import 'variant_style.dart';

/// Shell chrome. When [hideBottomNav] is true (agent mode), only [spaceBar] + body.
class DashNavChrome extends StatelessWidget {
  const DashNavChrome({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.style,
    required this.body,
    this.spaceBar,
    this.hideBottomNav = false,
  });

  final DashTab selected;
  final ValueChanged<DashTab> onSelect;
  final DashVariantStyle style;
  final Widget body;
  final Widget? spaceBar;
  final bool hideBottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: style.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            ?spaceBar,
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: hideBottomNav
          ? null
          : NotchBottomNav(
              selected: selected,
              onSelect: onSelect,
              style: style,
            ),
    );
  }
}

IconData dashTabIcon(DashTab tab) => switch (tab) {
      DashTab.home => Icons.home_outlined,
      DashTab.transactions => Icons.receipt_long_outlined,
      DashTab.categories => Icons.label_outline_rounded,
      DashTab.accounts => Icons.account_balance_outlined,
      DashTab.more => Icons.grid_view_outlined,
    };

IconData dashTabIconFilled(DashTab tab) => switch (tab) {
      DashTab.home => Icons.home_rounded,
      DashTab.transactions => Icons.receipt_long_rounded,
      DashTab.categories => Icons.label_rounded,
      DashTab.accounts => Icons.account_balance_rounded,
      DashTab.more => Icons.grid_view_rounded,
    };

String dashTabLabel(DashTab tab, DashVariantStyle style) => switch (tab) {
      DashTab.home => 'Home',
      DashTab.transactions => style.navLabel,
      DashTab.categories => 'Categories',
      DashTab.accounts => 'Accounts',
      DashTab.more => 'More',
    };

/// Home sits in-row like other tabs; when selected it rises into a notch circle.
class NotchBottomNav extends StatelessWidget {
  const NotchBottomNav({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.style,
  });

  final DashTab selected;
  final ValueChanged<DashTab> onSelect;
  final DashVariantStyle style;

  static const _order = <DashTab>[
    DashTab.transactions,
    DashTab.categories,
    DashTab.home,
    DashTab.accounts,
    DashTab.more,
  ];

  void _select(DashTab tab) {
    if (tab == selected) return;
    HapticFeedback.selectionClick();
    onSelect(tab);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.navBackground,
      elevation: 10,
      shadowColor: const Color(0x280F172A),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (final tab in _order)
                    Expanded(
                      child: tab == DashTab.home
                          ? _NotchHomeItem(
                              selected: selected == DashTab.home,
                              onSelect: () => _select(DashTab.home),
                              style: style,
                            )
                          : _NotchSideItem(
                              tab: tab,
                              selected: selected,
                              onSelect: _select,
                              style: style,
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotchHomeItem extends StatefulWidget {
  const _NotchHomeItem({
    required this.selected,
    required this.onSelect,
    required this.style,
  });

  final bool selected;
  final VoidCallback onSelect;
  final DashVariantStyle style;

  @override
  State<_NotchHomeItem> createState() => _NotchHomeItemState();
}

class _NotchHomeItemState extends State<_NotchHomeItem>
    with TickerProviderStateMixin {
  /// Matches the previous always-elevated notch FAB.
  static const double _fabSize = 60;
  static const double _fabTop = -22;

  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.selected ? 1 : 0,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final Animation<double> _riseCurve = CurvedAnimation(
    parent: _rise,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant _NotchHomeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _rise.forward();
      _pulse.forward(from: 0);
    } else if (!widget.selected && oldWidget.selected) {
      _rise.reverse();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.style.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSelect,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _pulse]),
        builder: (context, child) {
          final r = _riseCurve.value.clamp(0.0, 1.0);
          final t = _pulse.value;

          // Crossfade: row item ↔ floating FAB so both end states match peers / old FAB.
          final rowOpacity = (1 - r * 1.35).clamp(0.0, 1.0);
          final fabOpacity = ((r - 0.15) / 0.85).clamp(0.0, 1.0);
          final glow = 0.35 * fabOpacity + 0.25 * math.sin(t * math.pi) * fabOpacity;
          final blur = 16.0 + 10.0 * t * fabOpacity;
          final scale = 1 + 0.12 * math.sin(t * math.pi) * fabOpacity;
          // Rise from in-row icon center (~19) up to the old FAB top (-22).
          final top = 19.0 + (_fabTop - 19.0) * r;
          final fabScale = 0.4 + 0.6 * r;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Exact same structure as `_NotchSideItem` when collapsed.
              Opacity(
                opacity: rowOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 30,
                      width: 36,
                      child: Icon(
                        Icons.home_outlined,
                        color: AppColors.mute,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Home',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mute,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const SizedBox(height: 2.5),
                  ],
                ),
              ),
              if (fabOpacity > 0)
                Positioned(
                  top: top,
                  child: Opacity(
                    opacity: fabOpacity,
                    child: Transform.scale(
                      scale: scale * fabScale,
                      child: SizedBox(
                        width: _fabSize,
                        height: _fabSize,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (t > 0 && t < 1 && fabOpacity > 0.7)
                              Opacity(
                                opacity: (1 - t).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 1 + t * 1.2,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Container(
                              width: _fabSize,
                              height: _fabSize,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(
                                      alpha: glow.clamp(0.0, 0.7),
                                    ),
                                    blurRadius: blur,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotchSideItem extends StatefulWidget {
  const _NotchSideItem({
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.style,
  });

  final DashTab tab;
  final DashTab selected;
  final ValueChanged<DashTab> onSelect;
  final DashVariantStyle style;

  @override
  State<_NotchSideItem> createState() => _NotchSideItemState();
}

class _NotchSideItemState extends State<_NotchSideItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool get _on => widget.tab == widget.selected;

  @override
  void didUpdateWidget(covariant _NotchSideItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasOn = oldWidget.tab == oldWidget.selected;
    if (_on && !wasOn) {
      _fx.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.style.primary;
    final color = _on ? primary : AppColors.mute;

    return InkWell(
      onTap: () => widget.onSelect(widget.tab),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fx,
        builder: (context, child) {
          final t = _fx.value;
          final scale = 1 + 0.1 * math.sin(t * math.pi);

          return Transform.scale(
            scale: scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 30,
                  width: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (t > 0 && t < 1)
                        Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 1 + t * 1.4,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutBack,
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                          _on
                              ? dashTabIconFilled(widget.tab)
                              : dashTabIcon(widget.tab),
                          key: ValueKey('${widget.tab.name}-$_on'),
                          color: color,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: _on ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                  child: Text(
                    dashTabLabel(widget.tab, widget.style),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  height: 2.5,
                  width: _on ? 22 : 0,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
