import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = 0.55 + (_ctrl.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF4).withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class KpiShimmer extends StatelessWidget {
  const KpiShimmer({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: DashPanel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 72, height: 10),
                      SizedBox(height: 12),
                      ShimmerBox(width: 96, height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ListShimmer extends StatelessWidget {
  const ListShimmer({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DashPanel(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120, height: 14),
                        SizedBox(height: 8),
                        ShimmerBox(width: 160, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            for (var i = 0; i < rows; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const ShimmerBox(width: 36, height: 36, borderRadius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(
                            width: 100 + (i % 3) * 24.0,
                            height: 12,
                          ),
                          const SizedBox(height: 8),
                          ShimmerBox(
                            width: 140 + (i % 2) * 30.0,
                            height: 10,
                          ),
                        ],
                      ),
                    ),
                    const ShimmerBox(width: 56, height: 12),
                  ],
                ),
              ),
              if (i < rows - 1)
                const Divider(height: 1, color: AppColors.line),
            ],
          ],
        ),
      ),
    );
  }
}

/// Page body: keep header outside; swap this in while loading.
class DashLoadingBody extends StatelessWidget {
  const DashLoadingBody({
    super.key,
    this.kpiCount = 3,
    this.listRows = 6,
  });

  final int kpiCount;
  final int listRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (kpiCount > 0) KpiShimmer(count: kpiCount),
        ListShimmer(rows: listRows),
      ],
    );
  }
}
