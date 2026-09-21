import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'form_validation.dart';
import 'screens/users_permissions_screen.dart';
import 'shimmer.dart';
import 'spaces.dart';
import 'spaces_scope.dart';
import 'ui.dart';

/// Horizontal space chips under the status bar.
class SpaceSwitcherBar extends StatelessWidget {
  const SpaceSwitcherBar({super.key});

  @override
  Widget build(BuildContext context) {
    final spaces = SpacesScope.of(context);
    if (spaces.loading) {
      return SizedBox(
        height: 44,
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
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: spaces.spaces.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == spaces.spaces.length) {
            return _AddChip(
              onTap: () => _promptCreate(context, spaces),
            );
          }
          final space = spaces.spaces[index];
          final selected = space.id == spaces.spaceId;
          return _SpaceChip(
            space: space,
            selected: selected,
            onTap: () => spaces.select(space.id),
            onLongPress: () => _promptManage(context, spaces, space),
          );
        },
      ),
    );
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
  });

  final Space space;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : const Color(0xFFF0F3F7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor:
                    selected ? Colors.white24 : const Color(0xFFE4E8EE),
                child: Text(
                  space.initial,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                space.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4E8EE)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: AppColors.mute),
              SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
