import 'package:flutter/material.dart';

import 'dash_colors.dart';
import 'dash_sheets.dart';
import 'table_export.dart';
import 'ui.dart';

/// Sheet to pick csv / excel / printable-html (web DownloadMenu parity).
Future<void> showDownloadMenu({
  required BuildContext context,
  required String filename,
  required String title,
  required List<List<String>> rows,
}) async {
  await showDashSheet<void>(
    context: context,
    title: 'Export',
    description: 'Download or share this table',
    builder: (ctx, _) {
      Future<void> run(String format) async {
        final export = TableExport(
          filename: filename,
          title: title,
          rows: rows,
        );
        final msg = await export.share(format: format);
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        toast(ctx, msg);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.table_chart_outlined, color: ctx.dashInk),
            title: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Spreadsheet-friendly', style: TextStyle(color: ctx.dashMute)),
            onTap: () => run('csv'),
          ),
          Divider(height: 1, color: ctx.dashLine),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.grid_on_outlined, color: ctx.dashInk),
            title: const Text('Excel', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('HTML .xls', style: TextStyle(color: ctx.dashMute)),
            onTap: () => run('excel'),
          ),
          Divider(height: 1, color: ctx.dashLine),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_outlined, color: ctx.dashInk),
            title: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'Printable HTML — open and print to PDF',
              style: TextStyle(color: ctx.dashMute),
            ),
            onTap: () => run('pdf'),
          ),
        ],
      );
    },
  );
}
