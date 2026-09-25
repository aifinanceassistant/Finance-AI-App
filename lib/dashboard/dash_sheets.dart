import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'dash_colors.dart';
import 'ui.dart';

Future<T?> showDashSheet<T>({
  required BuildContext context,
  required String title,
  String? description,
  required Widget Function(BuildContext context, void Function(VoidCallback fn) setSheetState) builder,
  List<Widget>? actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.dashPanel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ctx.dashLine,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: ctx.dashInk,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: ctx.dashMute,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                            color: ctx.dashMute,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: ctx.dashLine),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: builder(ctx, setSheetState),
                      ),
                    ),
                    if (actions != null && actions.isNotEmpty) ...[
                      Divider(height: 1, color: ctx.dashLine),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Row(
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(child: actions[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class DashFieldLabel extends StatelessWidget {
  const DashFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.dashMute,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DashTextField extends StatelessWidget {
  const DashTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.autofocus = false,
    this.obscureText = false,
    this.inputFormatters,
    this.errorText,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.danger),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        color: context.dashInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.dashSoftMute, fontSize: 14),
        errorText: hasError ? errorText : null,
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: context.dashPanel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? AppColors.danger : context.dashLine,
          ),
        ),
        enabledBorder: hasError
            ? errorBorder
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.dashLine),
              ),
        focusedBorder: hasError
            ? errorBorder.copyWith(
                borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
              )
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brand, width: 1.4),
              ),
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
    );
  }
}

class DashDropdown<T> extends StatelessWidget {
  const DashDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelOf,
  });

  final T? value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final resolved = value != null && items.contains(value) ? value as T : null;
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: resolved,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: context.dashMute, size: 20),
      dropdownColor: context.dashPanel,
      style: TextStyle(
        color: context.dashInk,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(
              labelOf(item),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.dashInk,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: context.dashElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.dashLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.dashLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brand),
        ),
      ),
    );
  }
}

Widget sheetCancelSave({
  required BuildContext context,
  required VoidCallback onSave,
  String saveLabel = 'Save',
}) {
  return Row(
    children: [
      Expanded(
        child: GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: AccentButton(label: saveLabel, onPressed: onSave),
      ),
    ],
  );
}
