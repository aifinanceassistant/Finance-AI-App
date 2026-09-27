import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../filter_sort.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../transactions_controller.dart';
import '../transactions_scope.dart';
import '../ui.dart';

const _filterFields = [
  FilterFieldDef(id: 'filename', label: 'Filename', type: FilterFieldType.text),
  FilterFieldDef(id: 'kind', label: 'Type', type: FilterFieldType.select),
  FilterFieldDef(
    id: 'transaction',
    label: 'Transaction',
    type: FilterFieldType.text,
  ),
];

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<TxnDocument> _docs = [];
  var _loading = true;
  String _search = '';
  List<FilterRule> _filterRules = [];
  List<SortRule> _sortRules = [];

  TransactionsController get _ctrl => TransactionsScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final spaceId = SpacesScope.of(context).spaceId;
    setState(() => _loading = true);
    final list = await _ctrl.listSpaceDocuments(spaceId);
    if (!mounted) return;
    setState(() {
      _docs = list;
      _loading = false;
    });
  }

  Object? _docValue(TxnDocument d, String field) {
    switch (field) {
      case 'filename':
        return d.filename;
      case 'kind':
        return d.kindLabel;
      case 'transaction':
        return d.transactionDescription ?? '';
      default:
        return '';
    }
  }

  List<String> _selectOptions(String field) {
    if (field != 'kind') return [];
    final kinds = <String>{};
    for (final d in _docs) {
      kinds.add(d.kindLabel);
    }
    return kinds.toList()..sort();
  }

  List<TxnDocument> get _filtered {
    final searched = applySearch(_docs, _search, _filterFields, _docValue);
    final filtered = applyFilters(searched, _filterRules, _docValue);
    return applySort(filtered, _sortRules, _docValue);
  }

  String _bytes(int? n) {
    if (n == null || n <= 0) return '';
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final subtitle = filtered.length == _docs.length
        ? '${filtered.length} file${filtered.length == 1 ? '' : 's'}'
        : '${filtered.length} of ${_docs.length} files';

    return DashModalScaffold(
      body: dashPullToRefresh(
        onRefresh: _load,
        backgroundColor: context.dashPanel,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            DashFeedChrome(
              title: 'Documents',
              subtitle: subtitle,
              showPrimary: false,
              filterBar: FilterSortBar(
                fields: _filterFields,
                rules: _filterRules,
                sorts: _sortRules,
                selectOptions: _selectOptions,
                defaultFilterField: 'filename',
                defaultSortField: 'filename',
                search: _search,
                onSearchChanged: (v) => setState(() => _search = v),
                searchHint: 'Search documents…',
                onRulesChanged: (rules) => setState(() => _filterRules = rules),
                onSortsChanged: (sorts) => setState(() => _sortRules = sorts),
                iconButtons: true,
                expandSearch: true,
              ),
            ),
            if (_loading)
              const DashLoadingBody(kpiCount: 0, listRows: 5)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
                        child: Text(
                          _docs.isEmpty
                              ? 'No documents yet. Attach receipts or invoices from a transaction.'
                              : 'No documents match these filters',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.dashMute,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final d in filtered)
                            _DocumentRow(
                              doc: d,
                              sizeLabel: _bytes(d.byteSize),
                              onOpen: d.url == null
                                  ? null
                                  : () async {
                                      final uri = Uri.tryParse(d.url!);
                                      if (uri == null) return;
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                              onDelete: () async {
                                final ok = await _ctrl.deleteDocument(d.id);
                                if (!mounted) return;
                                if (!ok) {
                                  toast(context, 'Could not remove document');
                                  return;
                                }
                                setState(
                                  () => _docs =
                                      _docs.where((x) => x.id != d.id).toList(),
                                );
                              },
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.sizeLabel,
    required this.onOpen,
    required this.onDelete,
  });

  final TxnDocument doc;
  final String sizeLabel;
  final VoidCallback? onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.dashLine)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                size: 18,
                color: context.dashSoftMute,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onOpen != null
                            ? AppColors.brand
                            : context.dashInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        doc.kindLabel,
                        if (doc.transactionDescription != null)
                          doc.transactionDescription!,
                        if (doc.transactionDate != null) doc.transactionDate!,
                        if (sizeLabel.isNotEmpty) sizeLabel,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.dashSoftMute,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: context.dashSoftMute,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
