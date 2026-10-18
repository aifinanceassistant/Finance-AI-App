import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Client-side table export (matches web download-menu: csv / excel / pdf-html).
class TableExport {
  TableExport({
    required this.filename,
    required this.title,
    required this.rows,
  });

  final String filename;
  final String title;
  /// First row = headers.
  final List<List<String>> rows;

  static String csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String toCsv() {
    return rows.map((r) => r.map(csvEscape).join(',')).join('\n');
  }

  String toExcelHtml() {
    final buf = StringBuffer()
      ..writeln('<html><head><meta charset="utf-8"><title>$title</title></head><body>')
      ..writeln('<table border="1" cellspacing="0" cellpadding="4">');
    for (var i = 0; i < rows.length; i++) {
      buf.write('<tr>');
      final tag = i == 0 ? 'th' : 'td';
      for (final cell in rows[i]) {
        final safe = cell
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        buf.write('<$tag>$safe</$tag>');
      }
      buf.writeln('</tr>');
    }
    buf.writeln('</table></body></html>');
    return buf.toString();
  }

  String toPrintableHtml() {
    final buf = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln('<title>$title</title>')
      ..writeln(
        '<style>body{font-family:system-ui,sans-serif;padding:24px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #e3e8ee;padding:8px;text-align:left;font-size:13px}th{background:#f6f9fc}</style>',
      )
      ..writeln('</head><body><h1>$title</h1><table>');
    for (var i = 0; i < rows.length; i++) {
      buf.write('<tr>');
      final tag = i == 0 ? 'th' : 'td';
      for (final cell in rows[i]) {
        final safe = cell
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        buf.write('<$tag>$safe</$tag>');
      }
      buf.writeln('</tr>');
    }
    buf
      ..writeln('</table></body></html>');
    return buf.toString();
  }

  Future<String> share({required String format}) async {
    final safeName = filename.replaceAll(RegExp(r'[^\w\-]+'), '_');
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: toCsv()));
      return 'Copied CSV to clipboard';
    }

    final dir = await getTemporaryDirectory();
    late final String path;
    late final String mime;
    late final String label;

    switch (format) {
      case 'excel':
        path = '${dir.path}/$safeName.xls';
        await File(path).writeAsString(toExcelHtml());
        mime = 'application/vnd.ms-excel';
        label = 'Excel';
        break;
      case 'pdf':
        path = '${dir.path}/$safeName.html';
        await File(path).writeAsString(toPrintableHtml());
        mime = 'text/html';
        label = 'Printable HTML (open & print to PDF)';
        break;
      default:
        path = '${dir.path}/$safeName.csv';
        await File(path).writeAsString(toCsv());
        mime = 'text/csv';
        label = 'CSV';
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: mime, name: path.split('/').last)],
        subject: title,
        text: title,
      ),
    );
    return 'Shared $label';
  }
}
