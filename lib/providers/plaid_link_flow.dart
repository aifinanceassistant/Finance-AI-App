import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../auth/auth_controller.dart';

/// Opens Plaid Link and exchanges the public token via FinanceAI APIs.
class PlaidLinkFlow {
  PlaidLinkFlow(this._auth);

  final AuthController _auth;

  Future<({String connectionId, String institutionName, int created, int updated})?>
      connect({
    required String portfolioId,
  }) =>
      _run(portfolioId: portfolioId);

  /// Re-authenticate an existing Plaid Item (update mode), then sync balances.
  Future<({String connectionId, String institutionName, int created, int updated})?>
      reconnect({
    required String portfolioId,
    required String connectionId,
  }) =>
      _run(portfolioId: portfolioId, connectionId: connectionId);

  Future<({String connectionId, String institutionName, int created, int updated})?>
      _run({
    required String portfolioId,
    String? connectionId,
  }) async {
    final isUpdate = connectionId != null && connectionId.isNotEmpty;
    final tokenBody = <String, dynamic>{'portfolioId': portfolioId};
    if (isUpdate) tokenBody['connectionId'] = connectionId;
    if (!kIsWeb && Platform.isAndroid) {
      tokenBody['androidPackageName'] = 'com.example.financeai_app';
    }

    final tokenRes = await _auth.apiDecode(
      'POST',
      '/api/providers/plaid/link-token',
      body: tokenBody,
    );
    if (tokenRes is! Map<String, dynamic>) {
      throw Exception('Could not start bank linking');
    }
    if (tokenRes['code'] == 'plaid_not_configured') {
      throw Exception(
        'Plaid is not configured yet. You can still add accounts manually.',
      );
    }
    final linkToken = tokenRes['linkToken'] as String?;
    if (linkToken == null || linkToken.isEmpty) {
      throw Exception(
        (tokenRes['error'] as String?) ?? 'Could not start bank linking',
      );
    }

    final publicToken = await _openLink(linkToken);
    if (publicToken == null) return null;

    if (isUpdate) {
      final synced = await _auth.apiDecode(
        'POST',
        '/api/providers/connections/$connectionId',
      );
      if (synced is! Map<String, dynamic>) {
        throw Exception('Could not finish reconnecting');
      }
      return (
        connectionId: connectionId,
        institutionName: (synced['institutionName'] as String?) ?? 'Bank',
        created: (synced['created'] as num?)?.toInt() ?? 0,
        updated: (synced['updated'] as num?)?.toInt() ?? 0,
      );
    }

    if (publicToken.isEmpty) return null;

    final exchanged = await _auth.apiDecode(
      'POST',
      '/api/providers/plaid/exchange',
      body: {
        'portfolioId': portfolioId,
        'publicToken': publicToken,
      },
    );
    if (exchanged is! Map<String, dynamic> || exchanged['connectionId'] == null) {
      throw Exception(
        (exchanged is Map && exchanged['error'] is String)
            ? exchanged['error'] as String
            : 'Could not finish linking',
      );
    }

    return (
      connectionId: exchanged['connectionId'] as String,
      institutionName: (exchanged['institutionName'] as String?) ?? 'Bank',
      created: (exchanged['created'] as num?)?.toInt() ?? 0,
      updated: (exchanged['updated'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String?> _openLink(String linkToken) async {
    final completer = Completer<String?>();
    StreamSubscription<LinkSuccess>? successSub;
    StreamSubscription<LinkExit>? exitSub;

    successSub = PlaidLink.onSuccess.listen((event) {
      if (!completer.isCompleted) {
        // Update mode may still deliver an empty public token; treat success
        // as completion with whatever token we got (including empty).
        completer.complete(event.publicToken);
      }
    });
    exitSub = PlaidLink.onExit.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: linkToken),
      );
      await PlaidLink.open();
      return await completer.future.timeout(
        const Duration(minutes: 15),
        onTimeout: () => null,
      );
    } finally {
      await successSub.cancel();
      await exitSub.cancel();
    }
  }
}
