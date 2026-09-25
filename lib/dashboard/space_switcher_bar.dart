import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dash_colors.dart';
import 'form_validation.dart';
import 'screens/users_permissions_screen.dart';
import 'shimmer.dart';
import 'spaces.dart';
import 'spaces_scope.dart';
import 'ui.dart';

/// Horizontal space chips under the status bar.
///
/// Optional [trailing] actions (search, notifications) sit to the right of the
/// chip scroller so chrome stays one row.
class SpaceSwitcherBar extends StatelessWidget {
  const SpaceSwitcherBar({super.key, this.trailing});

  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final spaces = SpacesScope.of(context);
    final actions = trailing;
    final chips = _buildChips(context, spaces);

    if (actions == null || actions.isEmpty) {
      return chips;
    }

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(child: chips),
          ...actions,
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildChips(BuildContext context, SpacesController spaces) {
    if (spaces.loading) {
      return SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, _) => const Align(
            alignment: Alignment.centerLeft,
            child: ShimmerBox(width: 88, height: 28, borderRadius: 999),
          ),
        ),
      );
    }
    if (spaces.spaces.isEmpty) {
      return const SizedBox(height: 48);
    }

    if (spaces.spaces.length > 1) {
      final active = spaces.spaces.firstWhere(
        (s) => s.id == spaces.spaceId,
        orElse: () => spaces.spaces.first,
      );
      return SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SpaceChip(
              space: active,
              selected: true,
              showChevron: true,
              onTap: () => _openPicker(context, spaces),
              onLongPress: () => _promptManage(context, spaces, active),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16, 0, trailing == null ? 16 : 4, 0),
        itemCount: spaces.spaces.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == spaces.spaces.length) {
            return Align(
              alignment: Alignment.center,
              child: _AddChip(
                onTap: () => _promptCreate(context, spaces),
              ),
            );
          }
          final space = spaces.spaces[index];
          final selected = space.id == spaces.spaceId;
          return Align(
            alignment: Alignment.center,
            child: _SpaceChip(
              space: space,
              selected: selected,
              onTap: () => spaces.select(space.id),
              onLongPress: () => _promptManage(context, spaces, space),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    SpacesController spaces,
  ) async {
    final result = await showModalBottomSheet<({String action, Space? space})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.dashSurface,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Spaces',
                    style: TextStyle(
                      color: sheetContext.dashMute,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final s in spaces.spaces)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: s.id == spaces.spaceId
                          ? AppColors.brand
                          : sheetContext.dashLine,
                      child: Text(
                        s.initial,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: s.id == spaces.spaceId
                              ? Colors.white
                              : sheetContext.dashInk,
                        ),
                      ),
                    ),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(s.type),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.id == spaces.spaceId)
                          const Icon(
                            Icons.check_rounded,
                            color: AppColors.brand,
                          ),
                        IconButton(
                          tooltip: 'Manage',
                          icon: const Icon(Icons.more_horiz_rounded),
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            (action: 'manage', space: s),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      (action: 'select', space: s),
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add space'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    (action: 'add', space: null),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || result == null) return;
    final space = result.space;
    switch (result.action) {
      case 'select':
        if (space != null && space.id != spaces.spaceId) {
          await spaces.select(space.id);
        }
      case 'manage':
        if (space != null) await _promptManage(context, spaces, space);
      case 'add':
        await _promptCreate(context, spaces);
    }
  }

  Future<void> _promptCreate(
    BuildContext context,
    SpacesController spaces,
  ) async {
    if (!spaces.canCreateSpace) {
      toast(
        context,
        'Space limit reached (${spaces.spaces.length}/${spaces.selfEntitlements.maxSpaces}). Upgrade your plan.',
      );
      return;
    }

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add space'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Side project',
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name == null) return;
    if (name.isEmpty) {
      if (context.mounted) {
        toast(context, requiredText(name, 'Space name')!);
      }
      return;
    }
    final lower = name.toLowerCase();
    final type = RegExp(
      r'\b(corp|inc|llc|ltd|gmbh|company|studio|labs|agency|media)\b',
    ).hasMatch(lower)
        ? 'Business'
        : 'Personal';
    final created = await spaces.create(name: name, type: type);
    if (created == null && context.mounted) {
      toast(context, 'Could not create space');
    }
  }

  Future<void> _promptManage(
    BuildContext context,
    SpacesController spaces,
    Space space,
  ) async {
    final isActive = space.id == spaces.spaceId;
    final canRename = isActive
        ? (spaces.isOwner || spaces.can('settings', 'write'))
        : (space.isOwner == true || space.role == 'owner');
    final canDelete = isActive
        ? spaces.canDeleteSpace
        : (space.canDeleteSpace == true || space.isOwner == true);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(space.name),
                subtitle: Text(space.type),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Members'),
                onTap: () => Navigator.pop(context, 'members'),
              ),
              if (canRename)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename'),
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
              if (canDelete && spaces.spaces.length > 1)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    if (action == 'members') {
      if (space.id != spaces.spaceId) {
        await spaces.select(space.id);
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SpacesScope(
            controller: spaces,
            child: const UsersPermissionsScreen(),
          ),
        ),
      );
    } else if (action == 'rename') {
      final controller = TextEditingController(text: space.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Rename space'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (name != null && name.isNotEmpty) {
        await spaces.rename(space.id, name);
      } else if (name != null && name.isEmpty && context.mounted) {
        toast(context, requiredText(name, 'Space name')!);
      }
    } else if (action == 'delete') {
      await spaces.remove(space.id);
    }
  }
}

class _SpaceChip extends StatelessWidget {
  const _SpaceChip({
    required this.space,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.showChevron = false,
  });

  final Space space;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final selectedBg = context.isDark ? AppColors.brand : AppColors.ink;
    final unselectedBg =
        context.isDark ? context.dashPanel : const Color(0xFFF0F3F7);
    final avatarBg = selected
        ? Colors.white.withValues(alpha: 0.22)
        : (context.isDark ? context.dashLine : const Color(0xFFE4E8EE));
    final fg = selected ? Colors.white : context.dashInk;

    return Material(
      color: selected ? selectedBg : unselectedBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    space.initial,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    space.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: fg,
                    ),
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.dashPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.dashLine),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 34,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: context.dashMute,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: context.dashMute,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
