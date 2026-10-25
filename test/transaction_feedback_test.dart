import 'package:flutter_test/flutter_test.dart';
import 'package:financeai_app/auth/auth_controller.dart';
import 'package:financeai_app/dashboard/data.dart';
import 'package:financeai_app/dashboard/transactions_controller.dart';

class FailureController extends TransactionsController {
  FailureController() : super(AuthController.fake());
  final failures = <String>{};
  @override
  Future<DemoTxn?> patch(String id, Map<String, dynamic> body) async {
    if (failures.contains(id)) return null;
    return super.patch(id, body);
  }
}

void main() {
  test(
    'failed approval and settlement report failure and preserve original state',
    () async {
      final controller = FailureController();
      await controller.loadForSpace('fake-personal');
      final txn = controller.transactions.first;
      controller.failures.add(txn.id);
      expect(
        await controller.setApproval(txn.id, ApprovalStatus.approved),
        isFalse,
      );
      expect(await controller.markSettled(txn.id), isFalse);
      expect(controller.transactions.first.approvalStatus, txn.approvalStatus);
      expect(controller.transactions.first.status, txn.status);
    },
  );
  test('bulk settlement reports partial success and keeps failed transactions open', () async {
    final controller = FailureController();
    await controller.loadForSpace('fake-personal');
    final open = controller.transactions
        .where((t) => t.status != TxnStatus.succeeded)
        .toList();
    expect(open, isNotEmpty);
    controller.failures.add(open.first.id);
    final result = await controller.settleAll();
    expect(result.settled, open.length - 1);
    expect(result.failed, [open.first.merchant]);
    expect(
      controller.transactions.firstWhere((t) => t.id == open.first.id).status,
      open.first.status,
    );
  });
  test('failed detail update cannot be reported as saved', () async {
    final controller = FailureController();
    await controller.loadForSpace('fake-personal');
    final txn = controller.transactions.first;
    controller.failures.add(txn.id);
    expect(
      await controller.updateDetail(
        id: txn.id,
        category: txn.category,
        type: txn.type,
        reconciled: true,
      ),
      isFalse,
    );
  });
}
