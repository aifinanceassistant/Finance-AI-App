import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../dash_colors.dart';
import '../shimmer.dart';
import '../spaces_scope.dart';
import '../transactions_controller.dart';
import '../transactions_scope.dart';
import '../ui.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<TxnDocument> _docs = [];
  var _loading = true;

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

  String _bytes(int? n) {
    if (n == null || n <= 0) return '';
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dashWash,
      appBar: AppBar(
        backgroundColor: context.dashPanel,
        foregroundColor: context.dashInk,
        elevation: 0,
        title: const Text('Documents'),
      ),
      body: dashPullToRefresh(
        onRefresh: _load,
        backgroundColor: context.dashPanel,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  ShimmerBox(height: 72),
                  SizedBox(height: 10),
                  ShimmerBox(height: 72),
                  SizedBox(height: 10),
                  ShimmerBox(height: 72),
                ],
              )
            : _docs.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
                    children: [
                      Text(
                        'No documents yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.dashInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Attach receipts or invoices from a transaction detail sheet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.dashSoftMute,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: _docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = _docs[i];
                      final size = _bytes(d.byteSize);
                      return Material(
                        color: context.dashPanel,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: d.url == null
                              ? null
                              : () async {
                                  final uri = Uri.tryParse(d.url!);
                                  if (uri == null) return;
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.filename,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: d.url != null
                                              ? AppColors.brand
                                              : context.dashInk,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          d.kindLabel,
                                          if (d.transactionDescription != null)
                                            d.transactionDescription!,
                                          if (d.transactionDate != null)
                                            d.transactionDate!,
                                          if (size.isNotEmpty) size,
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
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final ok =
                                        await _ctrl.deleteDocument(d.id);
                                    if (!mounted) return;
                                    if (!ok) {
                                      toast(
                                        context,
                                        'Could not remove document',
                                      );
                                      return;
                                    }
                                    setState(
                                      () => _docs = _docs
                                          .where((x) => x.id != d.id)
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
