import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum TxnStatus { succeeded, pending, failed }

enum ApprovalStatus { pending, approved, rejected }

enum MoneyMove { income, expense, transfer }

const kMoneyMoveLabels = ['Income', 'Expense', 'Transfer'];

String moneyMoveLabel(MoneyMove m) {
  switch (m) {
    case MoneyMove.income:
      return 'Income';
    case MoneyMove.expense:
      return 'Expense';
    case MoneyMove.transfer:
      return 'Transfer';
  }
}

MoneyMove inferMoneyMove(double amount, String category, [String? label]) {
  final cat = category.toLowerCase();
  final name = (label ?? '').toLowerCase();
  if (cat.contains('transfer') ||
      name.contains('transfer') ||
      name.contains(' → ') ||
      RegExp(r'\bto\b.+\b(savings|checking|reserve|fund)\b').hasMatch(name)) {
    return MoneyMove.transfer;
  }
  if (amount > 0 ||
      cat == 'income' ||
      cat.contains('payroll') ||
      cat.contains('clients') ||
      cat.contains('revenue')) {
    return MoneyMove.income;
  }
  return MoneyMove.expense;
}

class DemoTxn {
  DemoTxn({
    required this.id,
    required this.merchant,
    required this.category,
    required this.account,
    required this.amount,
    required this.date,
    required this.status,
    this.approvalStatus = ApprovalStatus.approved,
    this.dateIso,
    this.originalAmount,
    this.originalCurrency,
    MoneyMove? type,
  }) : type = type ?? inferMoneyMove(amount, category, merchant);

  final String id;
  final String merchant;
  final String category;
  final String account;
  /// USD-normalized signed amount.
  final double amount;
  final String date;
  /// ISO YYYY-MM-DD when loaded from API (for charts / sorting).
  final String? dateIso;
  final TxnStatus status;
  final ApprovalStatus approvalStatus;
  final MoneyMove type;
  final double? originalAmount;
  final String? originalCurrency;

  DemoTxn copyWith({
    String? id,
    String? merchant,
    String? category,
    String? account,
    double? amount,
    String? date,
    String? dateIso,
    TxnStatus? status,
    ApprovalStatus? approvalStatus,
    MoneyMove? type,
    double? originalAmount,
    String? originalCurrency,
  }) {
    return DemoTxn(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      account: account ?? this.account,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      dateIso: dateIso ?? this.dateIso,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      type: type ?? this.type,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
    );
  }
}

class DemoAccount {
  const DemoAccount({
    this.id,
    required this.bank,
    this.name,
    required this.type,
    required this.number,
    this.lastFour,
    required this.balance,
    this.originalBalance,
    this.originalCurrency,
    this.defaultCurrency,
    required this.status,
    required this.synced,
  });

  final String? id;
  final String bank;
  /// Nickname; falls back to [bank] in UI when null/empty.
  final String? name;
  final String type;
  final String number;
  /// Digits for reveal; derived from [number] when null.
  final String? lastFour;
  /// USD-normalized balance.
  final double balance;
  final double? originalBalance;
  final String? originalCurrency;
  final String? defaultCurrency;
  final TxnStatus status;
  final String synced;

  String get displayName {
    final n = name?.trim() ?? '';
    if (n.isNotEmpty && n != bank) return n;
    return bank;
  }

  String get nativeCurrency =>
      (originalCurrency ?? defaultCurrency ?? 'USD').toUpperCase();

  String get digits {
    final fromFour = (lastFour ?? '').replaceAll(RegExp(r'\D'), '');
    if (fromFour.length >= 4) return fromFour.substring(fromFour.length - 4);
    if (fromFour.isNotEmpty) return fromFour;
    final fromNumber = number.replaceAll(RegExp(r'\D'), '');
    if (fromNumber.length >= 4) {
      return fromNumber.substring(fromNumber.length - 4);
    }
    return fromNumber;
  }

  DemoAccount copyWith({
    String? id,
    String? bank,
    String? name,
    String? type,
    String? number,
    String? lastFour,
    double? balance,
    double? originalBalance,
    String? originalCurrency,
    String? defaultCurrency,
    TxnStatus? status,
    String? synced,
  }) {
    return DemoAccount(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      name: name ?? this.name,
      type: type ?? this.type,
      number: number ?? this.number,
      lastFour: lastFour ?? this.lastFour,
      balance: balance ?? this.balance,
      originalBalance: originalBalance ?? this.originalBalance,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      status: status ?? this.status,
      synced: synced ?? this.synced,
    );
  }
}

class DemoGoal {
  const DemoGoal({
    this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.originalTarget,
    this.originalCurrency,
    required this.due,
    required this.color,
    required this.note,
    this.criteria = const GoalCriteria(),
  });

  final String? id;
  final String name;
  /// USD-normalized target.
  final double target;
  /// USD progress from API (live SUM of matching transactions).
  final double saved;
  final double? originalTarget;
  final String? originalCurrency;
  final String due;
  final Color color;
  final String note;
  final GoalCriteria criteria;

  DemoGoal copyWith({
    String? id,
    String? name,
    double? target,
    double? saved,
    double? originalTarget,
    String? originalCurrency,
    String? due,
    Color? color,
    String? note,
    GoalCriteria? criteria,
  }) {
    return DemoGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      saved: saved ?? this.saved,
      originalTarget: originalTarget ?? this.originalTarget,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      due: due ?? this.due,
      color: color ?? this.color,
      note: note ?? this.note,
      criteria: criteria ?? this.criteria,
    );
  }
}

class GoalCriteria {
  const GoalCriteria({
    this.categoryIds = const [],
    this.accountIds = const [],
    this.types = const [],
  });

  final List<String> categoryIds;
  final List<String> accountIds;
  final List<String> types;

  Map<String, dynamic> toJson() => {
        'categoryIds': categoryIds,
        'accountIds': accountIds,
        'types': types,
      };

  static GoalCriteria fromJson(dynamic raw) {
    if (raw is! Map) return const GoalCriteria();
    List<String> list(dynamic v) {
      if (v is! List) return const [];
      return [
        for (final item in v)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ];
    }

    return GoalCriteria(
      categoryIds: list(raw['categoryIds'] ?? raw['category_ids']),
      accountIds: list(raw['accountIds'] ?? raw['account_ids']),
      types: [
        for (final t in list(raw['types']))
          if (t == 'income' || t == 'expense') t,
      ],
    );
  }
}

class DemoHolding {
  const DemoHolding({
    this.id,
    required this.name,
    required this.ticker,
    required this.type,
    required this.value,
    required this.cost,
    required this.change,
    this.currency,
    this.originalPrice,
  });

  final String? id;
  final String name;
  final String ticker;
  final String type;
  /// USD market value.
  final double value;
  /// USD cost basis.
  final double cost;
  final double change;
  final String? currency;
  final double? originalPrice;

  DemoHolding copyWith({
    String? id,
    String? name,
    String? ticker,
    String? type,
    double? value,
    double? cost,
    double? change,
    String? currency,
    double? originalPrice,
  }) {
    return DemoHolding(
      id: id ?? this.id,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      type: type ?? this.type,
      value: value ?? this.value,
      cost: cost ?? this.cost,
      change: change ?? this.change,
      currency: currency ?? this.currency,
      originalPrice: originalPrice ?? this.originalPrice,
    );
  }
}

class DemoRecurring {
  DemoRecurring({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.cadence,
    required this.next,
    required this.start,
    this.end = '',
    required this.account,
    this.status = TxnStatus.succeeded,
    this.originalAmount,
    this.originalCurrency,
    MoneyMove? type,
  }) : type = type ?? inferMoneyMove(amount, category, name);

  final String id;
  final String name;
  final String category;
  /// USD-normalized signed amount.
  final double amount;
  final String cadence;
  final String next;
  final String start;
  /// Empty string means ongoing / no end date.
  final String end;
  final String account;
  final TxnStatus status;
  final MoneyMove type;
  final double? originalAmount;
  final String? originalCurrency;

  String get endLabel => end.trim().isEmpty ? 'Ongoing' : end;

  DemoRecurring copyWith({
    String? id,
    String? name,
    String? category,
    double? amount,
    String? cadence,
    String? next,
    String? start,
    String? end,
    String? account,
    TxnStatus? status,
    MoneyMove? type,
    double? originalAmount,
    String? originalCurrency,
  }) {
    return DemoRecurring(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      cadence: cadence ?? this.cadence,
      next: next ?? this.next,
      start: start ?? this.start,
      end: end ?? this.end,
      account: account ?? this.account,
      status: status ?? this.status,
      type: type ?? this.type,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
    );
  }
}

class DemoCategory {
  const DemoCategory({
    required this.name,
    required this.amount,
    required this.pct,
    required this.color,
  });

  final String name;
  final double amount;
  final double pct;
  final Color color;
}

const spendSeries = [820.0, 940, 1100, 980, 1250, 1180, 1320, 1410, 1280, 1550, 1480, 1620];
const spendMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const reportMonths = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
const reportIncome = [4100.0, 4100, 4200, 4200, 4200, 4200];
const reportSpend = [2980.0, 3120, 3400, 3050, 3280, 3214];

const topCategories = [
  DemoCategory(name: 'Housing', amount: 1450, pct: 38, color: AppColors.accent),
  DemoCategory(name: 'Groceries', amount: 420, pct: 11, color: AppColors.brand),
  DemoCategory(name: 'Transport', amount: 210, pct: 5.5, color: Color(0xFF00D4AA)),
  DemoCategory(name: 'Dining', amount: 310, pct: 8, color: Color(0xFFFFC043)),
  DemoCategory(name: 'Subscriptions', amount: 89, pct: 2.3, color: Color(0xFFFF6B6B)),
];

const reportCategories = [
  DemoCategory(name: 'Housing', amount: 1450, pct: 45, color: AppColors.accent),
  DemoCategory(name: 'Groceries', amount: 420, pct: 13, color: AppColors.brand),
  DemoCategory(name: 'Dining', amount: 310, pct: 10, color: Color(0xFFFFC043)),
  DemoCategory(name: 'Transport', amount: 210, pct: 7, color: Color(0xFF00D4AA)),
  DemoCategory(name: 'Other', amount: 824, pct: 26, color: AppColors.softMute),
];

final demoTransactions = [
  DemoTxn(
    id: 'txn_1',
    merchant: 'Sephora',
    category: 'Beauty',
    account: 'N26 · ··4821',
    amount: -28.5,
    date: 'Mar 22',
    status: TxnStatus.succeeded,
    approvalStatus: ApprovalStatus.pending,
  ),
  DemoTxn(
    id: 'txn_2',
    merchant: 'Douglas',
    category: 'Beauty',
    account: 'Revolut · ··1190',
    amount: -14.9,
    date: 'Mar 12',
    status: TxnStatus.succeeded,
    approvalStatus: ApprovalStatus.pending,
  ),
  DemoTxn(
    id: 'txn_3',
    merchant: 'Rituals',
    category: 'Beauty',
    account: 'Wise · ··7742',
    amount: -4.6,
    date: 'Mar 5',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_4',
    merchant: 'Shell Station',
    category: 'Car',
    account: 'Monzo · ··9088',
    amount: -68.4,
    date: 'Mar 24',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_5',
    merchant: 'ParkNow',
    category: 'Car',
    account: 'Klarna · ··3301',
    amount: -12,
    date: 'Mar 20',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_6',
    merchant: 'ADAC',
    category: 'Car',
    account: 'N26 · ··4821',
    amount: -49,
    date: 'Mar 10',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_7',
    merchant: 'Car wash · WashTec',
    category: 'Car',
    account: 'Revolut · ··1190',
    amount: -18.5,
    date: 'Mar 8',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_8',
    merchant: 'TUV Nord',
    category: 'Car',
    account: 'Wise · ··7742',
    amount: -38.1,
    date: 'Mar 2',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_9',
    merchant: 'Toys R Us',
    category: 'Children',
    account: 'Monzo · ··9088',
    amount: -24.99,
    date: 'Mar 18',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_10',
    merchant: 'Scholastic Book Fair',
    category: 'Children',
    account: 'Klarna · ··3301',
    amount: -12.5,
    date: 'Mar 6',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_11',
    merchant: 'Zara',
    category: 'Clothing',
    account: 'N26 · ··4821',
    amount: -45,
    date: 'Mar 24',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_12',
    merchant: 'H&M',
    category: 'Clothing',
    account: 'Revolut · ··1190',
    amount: -22.5,
    date: 'Mar 15',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_13',
    merchant: 'Uniqlo',
    category: 'Clothing',
    account: 'Wise · ··7742',
    amount: -18,
    date: 'Mar 9',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_14',
    merchant: 'Thrift · Humana',
    category: 'Clothing',
    account: 'Monzo · ··9088',
    amount: -6.5,
    date: 'Mar 3',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_15',
    merchant: 'Dance studio · Pulse',
    category: 'Dance',
    account: 'Klarna · ··3301',
    amount: -35,
    date: 'Mar 16',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_16',
    merchant: 'Eventbrite · Salsa night',
    category: 'Dance',
    account: 'N26 · ··4821',
    amount: -18,
    date: 'Mar 7',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_17',
    merchant: 'UNICEF',
    category: 'Donations',
    account: 'Revolut · ··1190',
    amount: -40,
    date: 'Mar 14',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_18',
    merchant: 'Coursera',
    category: 'Education',
    account: 'Wise · ··7742',
    amount: -49,
    date: 'Mar 11',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_19',
    merchant: 'Bookstore · Dussmann',
    category: 'Education',
    account: 'Monzo · ··9088',
    amount: -22.8,
    date: 'Mar 4',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_20',
    merchant: 'CinemaxX',
    category: 'Entertainment',
    account: 'Klarna · ··3301',
    amount: -28,
    date: 'Mar 21',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_21',
    merchant: 'Steam',
    category: 'Entertainment',
    account: 'N26 · ··4821',
    amount: -19.99,
    date: 'Mar 17',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_22',
    merchant: 'Spotify',
    category: 'Entertainment',
    account: 'Revolut · ··1190',
    amount: -9.99,
    date: 'Mar 12',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_23',
    merchant: 'Netflix',
    category: 'Entertainment',
    account: 'Wise · ··7742',
    amount: -15.99,
    date: 'Yesterday',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_24',
    merchant: 'Disney+',
    category: 'Entertainment',
    account: 'Monzo · ··9088',
    amount: -8.99,
    date: 'Mar 8',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_25',
    merchant: 'Museum ticket',
    category: 'Entertainment',
    account: 'Klarna · ··3301',
    amount: -12,
    date: 'Mar 2',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_26',
    merchant: 'REWE Market',
    category: 'Groceries',
    account: 'N26 · ··4821',
    amount: -54.32,
    date: 'Today',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_27',
    merchant: 'Lidl',
    category: 'Groceries',
    account: 'Revolut · ··1190',
    amount: -41.67,
    date: 'Mar 20',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_28',
    merchant: 'Aldi',
    category: 'Groceries',
    account: 'Wise · ··7742',
    amount: -38.2,
    date: 'Mar 18',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_29',
    merchant: 'Bio Company',
    category: 'Groceries',
    account: 'Monzo · ··9088',
    amount: -27.4,
    date: 'Mar 15',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_30',
    merchant: 'REWE Market',
    category: 'Groceries',
    account: 'Klarna · ··3301',
    amount: -62.1,
    date: 'Mar 12',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_31',
    merchant: 'Weekly market',
    category: 'Groceries',
    account: 'N26 · ··4821',
    amount: -18.5,
    date: 'Mar 9',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_32',
    merchant: 'Lidl',
    category: 'Groceries',
    account: 'Revolut · ··1190',
    amount: -33.8,
    date: 'Mar 6',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_33',
    merchant: 'REWE Market',
    category: 'Groceries',
    account: 'Wise · ··7742',
    amount: -48.9,
    date: 'Mar 3',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_34',
    merchant: 'Getir',
    category: 'Groceries',
    account: 'Monzo · ··9088',
    amount: -22.4,
    date: 'Mar 1',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_35',
    merchant: 'Fitness First',
    category: 'Gym',
    account: 'Klarna · ··3301',
    amount: -79,
    date: 'Mar 1',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_36',
    merchant: 'Apotheke',
    category: 'Healthcare',
    account: 'N26 · ··4821',
    amount: -18.6,
    date: 'Mar 19',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_37',
    merchant: 'Dentist · Zahnarzt',
    category: 'Healthcare',
    account: 'Revolut · ··1190',
    amount: -32,
    date: 'Mar 11',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_38',
    merchant: 'Doctor co-pay',
    category: 'Healthcare',
    account: 'Wise · ··7742',
    amount: -11.4,
    date: 'Mar 5',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_39',
    merchant: 'IKEA',
    category: 'Home',
    account: 'Monzo · ··9088',
    amount: -86,
    date: 'Mar 16',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_40',
    merchant: 'Bauhaus',
    category: 'Home',
    account: 'Klarna · ··3301',
    amount: -38,
    date: 'Mar 7',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_41',
    merchant: 'Allianz · Home',
    category: 'Insurance',
    account: 'N26 · ··4821',
    amount: -210,
    date: 'Mar 1',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_42',
    merchant: 'Student loan · KfW',
    category: 'Loans',
    account: 'Revolut · ··1190',
    amount: -85,
    date: 'Mar 28',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_43',
    merchant: 'Barbershop',
    category: 'Personal Care',
    account: 'Wise · ··7742',
    amount: -22,
    date: 'Mar 13',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_44',
    merchant: 'DM Drogerie',
    category: 'Personal Care',
    account: 'Monzo · ··9088',
    amount: -14,
    date: 'Mar 4',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_45',
    merchant: 'Fressnapf',
    category: 'Pets',
    account: 'Klarna · ··3301',
    amount: -32.5,
    date: 'Mar 17',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_46',
    merchant: 'Vet clinic',
    category: 'Pets',
    account: 'N26 · ··4821',
    amount: -21.5,
    date: 'Mar 8',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_47',
    merchant: 'Bowling',
    category: 'Recreation',
    account: 'Revolut · ··1190',
    amount: -28,
    date: 'Mar 15',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_48',
    merchant: 'Board game cafe',
    category: 'Recreation',
    account: 'Wise · ··7742',
    amount: -22,
    date: 'Mar 9',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_49',
    merchant: 'Escape room',
    category: 'Recreation',
    account: 'Monzo · ··9088',
    amount: -25,
    date: 'Mar 2',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_50',
    merchant: 'Rent · Hauptstr.',
    category: 'Rent',
    account: 'Klarna · ··3301',
    amount: -1450,
    date: 'Mar 1',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_51',
    merchant: 'Cafe Central',
    category: 'Restaurants',
    account: 'N26 · ··4821',
    amount: -12.4,
    date: 'Mar 26',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_52',
    merchant: 'Vapiano',
    category: 'Restaurants',
    account: 'Revolut · ··1190',
    amount: -24.8,
    date: 'Mar 23',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_53',
    merchant: 'Sushi Circle',
    category: 'Restaurants',
    account: 'Wise · ··7742',
    amount: -38.5,
    date: 'Mar 20',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_54',
    merchant: 'Burgeramt',
    category: 'Restaurants',
    account: 'Monzo · ··9088',
    amount: -16.9,
    date: 'Mar 18',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_55',
    merchant: 'Delivery · Lieferando',
    category: 'Restaurants',
    account: 'Klarna · ··3301',
    amount: -22.4,
    date: 'Mar 15',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_56',
    merchant: 'Trattoria Roma',
    category: 'Restaurants',
    account: 'N26 · ··4821',
    amount: -48,
    date: 'Mar 12',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_57',
    merchant: 'Bakery · Zeit fur Brot',
    category: 'Restaurants',
    account: 'Revolut · ··1190',
    amount: -8.2,
    date: 'Mar 10',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_58',
    merchant: 'Thai Garden',
    category: 'Restaurants',
    account: 'Wise · ··7742',
    amount: -31.5,
    date: 'Mar 7',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_59',
    merchant: 'Mustafas Gemuse',
    category: 'Restaurants',
    account: 'Monzo · ··9088',
    amount: -7.5,
    date: 'Mar 5',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_60',
    merchant: 'Wine bar',
    category: 'Restaurants',
    account: 'Klarna · ··3301',
    amount: -42,
    date: 'Mar 2',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_61',
    merchant: 'Care package · Pflegedienst',
    category: 'Senior Care',
    account: 'N26 · ··4821',
    amount: -45,
    date: 'Mar 14',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_62',
    merchant: 'Pharmacy delivery',
    category: 'Senior Care',
    account: 'Revolut · ··1190',
    amount: -18.5,
    date: 'Mar 6',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_63',
    merchant: 'Amazon',
    category: 'Shops',
    account: 'Wise · ··7742',
    amount: -34.9,
    date: 'Mar 22',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_64',
    merchant: 'MediaMarkt',
    category: 'Shops',
    account: 'Monzo · ··9088',
    amount: -49,
    date: 'Mar 16',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_65',
    merchant: 'Amazon',
    category: 'Shops',
    account: 'Klarna · ··3301',
    amount: -18.7,
    date: 'Mar 11',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_66',
    merchant: 'Saturn',
    category: 'Shops',
    account: 'N26 · ··4821',
    amount: -27.5,
    date: 'Mar 8',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_67',
    merchant: 'Etsy',
    category: 'Shops',
    account: 'Revolut · ··1190',
    amount: -14.9,
    date: 'Mar 4',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_68',
    merchant: 'Decathlon',
    category: 'Sports',
    account: 'Wise · ··7742',
    amount: -42,
    date: 'Mar 19',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_69',
    merchant: 'Climbing gym day pass',
    category: 'Sports',
    account: 'Monzo · ··9088',
    amount: -18,
    date: 'Mar 10',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_70',
    merchant: 'Deutsche Bahn',
    category: 'Transportation',
    account: 'Klarna · ··3301',
    amount: -29.9,
    date: 'Today',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_71',
    merchant: 'BVG ticket',
    category: 'Transportation',
    account: 'N26 · ··4821',
    amount: -9.5,
    date: 'Mar 25',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_72',
    merchant: 'Uber',
    category: 'Transportation',
    account: 'Revolut · ··1190',
    amount: -18.2,
    date: 'Mar 21',
    status: TxnStatus.failed,
  ),
  DemoTxn(
    id: 'txn_73',
    merchant: 'BVG ticket',
    category: 'Transportation',
    account: 'Wise · ··7742',
    amount: -9.5,
    date: 'Mar 18',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_74',
    merchant: 'FlixBus',
    category: 'Transportation',
    account: 'Monzo · ··9088',
    amount: -24.9,
    date: 'Mar 14',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_75',
    merchant: 'Uber',
    category: 'Transportation',
    account: 'Klarna · ··3301',
    amount: -14.6,
    date: 'Mar 11',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_76',
    merchant: 'BVG monthly',
    category: 'Transportation',
    account: 'N26 · ··4821',
    amount: -86,
    date: 'Mar 1',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_77',
    merchant: 'Airbnb',
    category: 'Travel & Vacation',
    account: 'Revolut · ··1190',
    amount: -218,
    date: 'Mar 28',
    status: TxnStatus.pending,
  ),
  DemoTxn(
    id: 'txn_78',
    merchant: 'Vattenfall',
    category: 'Utilities',
    account: 'Wise · ··7742',
    amount: -112,
    date: 'Mar 22',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_79',
    merchant: 'Vodafone',
    category: 'Utilities',
    account: 'Monzo · ··9088',
    amount: -29.99,
    date: 'Mar 15',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_80',
    merchant: 'Stadtwerke water',
    category: 'Utilities',
    account: 'Klarna · ··3301',
    amount: -18.5,
    date: 'Mar 8',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_81',
    merchant: 'Internet · 1&1',
    category: 'Utilities',
    account: 'N26 · ··4821',
    amount: -7.51,
    date: 'Mar 3',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_82',
    merchant: 'Yoga class · Studio Flow',
    category: 'Yoga & Pilates',
    account: 'Revolut · ··1190',
    amount: -22,
    date: 'Mar 20',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_83',
    merchant: 'Pilates Reformer',
    category: 'Yoga & Pilates',
    account: 'Wise · ··7742',
    amount: -28,
    date: 'Mar 13',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_84',
    merchant: 'Salary · Acme GmbH',
    category: 'Income',
    account: 'Monzo · ··9088',
    amount: 4200,
    date: 'Yesterday',
    status: TxnStatus.succeeded,
  ),
  DemoTxn(
    id: 'txn_85',
    merchant: 'Transfer to Emergency fund',
    category: 'Transfer',
    account: 'N26 · ··4821',
    amount: -200,
    date: 'Mar 26',
    status: TxnStatus.succeeded,
    type: MoneyMove.transfer,
  ),
  DemoTxn(
    id: 'txn_86',
    merchant: 'Transfer · Revolut → Wise',
    category: 'Transfer',
    account: 'Revolut · ··1190',
    amount: -350,
    date: 'Mar 16',
    status: TxnStatus.succeeded,
    type: MoneyMove.transfer,
  ),
];

const demoAccounts = [
  DemoAccount(
    bank: 'N26',
    type: 'Checking',
    number: '····4821',
    balance: 4820.12,
    status: TxnStatus.succeeded,
    synced: '2 min ago',
  ),
  DemoAccount(
    bank: 'Revolut',
    type: 'Everyday',
    number: '····1190',
    balance: 2140.5,
    status: TxnStatus.succeeded,
    synced: '5 min ago',
  ),
  DemoAccount(
    bank: 'Wise',
    type: 'Multi-currency',
    number: '····7742',
    balance: 5519.6,
    status: TxnStatus.succeeded,
    synced: '12 min ago',
  ),
  DemoAccount(
    bank: 'Monzo',
    type: 'Spending',
    number: '····9088',
    balance: 312.4,
    status: TxnStatus.pending,
    synced: 'Syncing…',
  ),
  DemoAccount(
    bank: 'Klarna',
    type: 'Card',
    number: '····3301',
    balance: -89.99,
    status: TxnStatus.succeeded,
    synced: '1 hr ago',
  ),
];

/// Shared mutable account list for shell connect, Accounts, and Settings.
final ValueNotifier<List<DemoAccount>> accountsStore =
    ValueNotifier<List<DemoAccount>>(List<DemoAccount>.of(demoAccounts));

const demoGoals = [
  DemoGoal(
    name: 'Emergency fund',
    target: 10000,
    saved: 6400,
    due: 'Dec 2026',
    color: AppColors.accent,
    note: '6 months of expenses',
  ),
  DemoGoal(
    name: 'Summer trip',
    target: 2400,
    saved: 1180,
    due: 'Jul 2026',
    color: AppColors.brand,
    note: 'Portugal · family of 4',
  ),
  DemoGoal(
    name: 'New laptop',
    target: 1800,
    saved: 920,
    due: 'Sep 2026',
    color: Color(0xFF00D4AA),
    note: 'Work machine',
  ),
  DemoGoal(
    name: 'Baby fund',
    target: 5000,
    saved: 2750,
    due: 'Ongoing',
    color: Color(0xFFFFC043),
    note: 'Shared household goal',
  ),
];

const demoHoldings = [
  DemoHolding(
    name: 'Vanguard FTSE All-World',
    ticker: 'VWCE',
    type: 'ETF',
    value: 12480.4,
    cost: 10210,
    change: 8.2,
  ),
  DemoHolding(
    name: 'Apple Inc.',
    ticker: 'AAPL',
    type: 'Stock',
    value: 4320,
    cost: 3980,
    change: 2.1,
  ),
  DemoHolding(
    name: 'iShares Core MSCI World',
    ticker: 'IWDA',
    type: 'ETF',
    value: 8755.25,
    cost: 9100,
    change: -1.4,
  ),
  DemoHolding(
    name: 'Bitcoin',
    ticker: 'BTC',
    type: 'Crypto',
    value: 2180.5,
    cost: 1650,
    change: 12.6,
  ),
  DemoHolding(
    name: 'Cash · brokerage',
    ticker: 'USD',
    type: 'Cash',
    value: 640,
    cost: 640,
    change: 0,
  ),
];

final demoRecurring = [
  DemoRecurring(
    id: 'rec_1',
    name: 'Netflix',
    category: 'Subscriptions',
    amount: -15.99,
    cadence: 'Monthly',
    next: 'Apr 12',
    start: 'Jan 12, 2024',
    account: 'Wise · ··7742',
  ),
  DemoRecurring(
    id: 'rec_2',
    name: 'Spotify',
    category: 'Subscriptions',
    amount: -9.99,
    cadence: 'Monthly',
    next: 'Apr 8',
    start: 'Jun 8, 2023',
    account: 'Klarna · ··3301',
  ),
  DemoRecurring(
    id: 'rec_3',
    name: 'Rent · Hauptstr.',
    category: 'Housing',
    amount: -1450,
    cadence: 'Monthly',
    next: 'Apr 1',
    start: 'Mar 1, 2022',
    account: 'N26 · ··4821',
  ),
  DemoRecurring(
    id: 'rec_4',
    name: 'Vattenfall',
    category: 'Utilities',
    amount: -112,
    cadence: 'Monthly',
    next: 'Apr 22',
    start: 'Sep 22, 2023',
    end: 'Sep 21, 2026',
    account: 'N26 · ··4821',
  ),
  DemoRecurring(
    id: 'rec_5',
    name: 'Gym · Urban Sports',
    category: 'Health',
    amount: -49.9,
    cadence: 'Monthly',
    next: 'Apr 3',
    start: 'Apr 3, 2024',
    end: 'Apr 2, 2026',
    account: 'Revolut · ··1190',
  ),
  DemoRecurring(
    id: 'rec_6',
    name: 'Salary · Acme GmbH',
    category: 'Income',
    amount: 4200,
    cadence: 'Monthly',
    next: 'Apr 28',
    start: 'Feb 28, 2023',
    account: 'N26 · ··4821',
  ),
];

const kSupportedCurrencies = [
  'USD',
  'CAD',
  'EUR',
  'GBP',
  'AED',
  'SGD',
  'JPY',
  'INR',
  'MYR',
  'AUD',
  'CHF',
];

String money(num n, {bool signed = false, String? currency}) {
  final code = (currency ?? DisplayCurrency.code).toUpperCase();
  final converted = DisplayCurrency.convertFromUsd(n.toDouble(), code);
  final symbol = DisplayCurrency.symbolFor(code);
  final abs = converted.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (m) => '${m[1]},',
      );
  if (signed || converted < 0) {
    return converted < 0 ? '-$symbol$abs' : '+$symbol$abs';
  }
  return '$symbol$abs';
}

String moneyWhole(num n, {String? currency}) {
  final code = (currency ?? DisplayCurrency.code).toUpperCase();
  final converted = DisplayCurrency.convertFromUsd(n.toDouble(), code);
  final symbol = DisplayCurrency.symbolFor(code);
  final abs = converted.abs().round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );
  return converted < 0 ? '-$symbol$abs' : '$symbol$abs';
}

/// Format an amount that is already in [currency] (no FX).
String moneyNative(num n, String currency, {bool signed = false}) {
  final code = currency.trim().toUpperCase();
  final symbol = DisplayCurrency.symbolFor(code);
  final abs = n.abs().toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+\.)'),
        (m) => '${m[1]},',
      );
  if (signed || n < 0) {
    return n < 0 ? '-$symbol$abs' : '+$symbol$abs';
  }
  return '$symbol$abs';
}

/// Format original → display currency (primary). Falls back to USD→display.
String moneyFromOriginal(
  num originalAmount, {
  String? originalCurrency,
  bool signed = false,
}) {
  final from = (originalCurrency ?? 'USD').toUpperCase();
  final converted = DisplayCurrency.convertViaUsd(
    originalAmount.toDouble().abs(),
    from,
    DisplayCurrency.code,
  );
  final signedAmt = signed || originalAmount < 0
      ? (originalAmount < 0 ? -converted : converted)
      : converted;
  return moneyNative(
    signedAmt,
    DisplayCurrency.code,
    signed: signed || originalAmount < 0,
  );
}

/// Profile display currency + live FX rates for [money] formatting.
/// API amounts are USD-normalized; [convertFromUsd] applies the display rate.
class DisplayCurrency {
  DisplayCurrency._();

  static String _code = 'USD';
  static final Map<String, double> _ratesToUsd = {'USD': 1};

  static String get code => _code;

  static void setCode(String code) {
    final next = code.trim().toUpperCase();
    if (next.isEmpty) return;
    _code = next;
  }

  static void setRateToUsd(String code, double rate) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty || !rate.isFinite || rate <= 0) return;
    _ratesToUsd[c] = rate;
  }

  /// USD → display currency using cached rates (identity if rate missing).
  static double convertFromUsd(double amountUsd, [String? toCurrency]) {
    final to = (toCurrency ?? _code).toUpperCase();
    if (to == 'USD') return amountUsd;
    final rate = _ratesToUsd[to];
    if (rate == null || !rate.isFinite || rate <= 0) return amountUsd;
    return (amountUsd / rate * 100).round() / 100;
  }

  /// Cross-rate via USD (rates are USD-per-unit).
  static double convertViaUsd(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) {
    final from = fromCurrency.trim().toUpperCase();
    final to = toCurrency.trim().toUpperCase();
    if (from == to) return amount;
    final fromRate = from == 'USD' ? 1.0 : _ratesToUsd[from];
    final toRate = to == 'USD' ? 1.0 : _ratesToUsd[to];
    if (fromRate == null ||
        toRate == null ||
        !fromRate.isFinite ||
        !toRate.isFinite ||
        fromRate <= 0 ||
        toRate <= 0) {
      return amount;
    }
    return (amount * fromRate / toRate * 100).round() / 100;
  }

  static String symbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'INR':
        return '₹';
      case 'JPY':
        return '¥';
      case 'SGD':
        return 'S\$';
      case 'CHF':
        return 'CHF ';
      case 'AED':
        return 'د.إ';
      case 'MYR':
        return 'RM';
      case 'USD':
      default:
        return '\$';
    }
  }
}

/// Dual-line amount like web [ConvertedAmountDisplay].
class ConvertedAmountText extends StatelessWidget {
  const ConvertedAmountText({
    super.key,
    required this.amount,
    this.originalCurrency = 'USD',
    this.signed = false,
    this.isIncome = false,
    this.primaryStyle,
    this.secondaryStyle,
    this.textAlign = TextAlign.right,
  });

  /// Amount in [originalCurrency] (absolute for expenses unless [signed]).
  final double amount;
  final String originalCurrency;
  final bool signed;
  final bool isIncome;
  final TextStyle? primaryStyle;
  final TextStyle? secondaryStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final from = originalCurrency.trim().toUpperCase();
    final display = DisplayCurrency.code;
    final primary = moneyFromOriginal(
      isIncome ? amount.abs() : amount,
      originalCurrency: from,
      signed: signed || isIncome,
    );
    final showOriginal = from != display;
    return Column(
      crossAxisAlignment: textAlign == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          style: primaryStyle,
          textAlign: textAlign,
        ),
        if (showOriginal)
          Text(
            moneyNative(amount.abs(), from),
            style: secondaryStyle ??
                const TextStyle(
                  color: Color(0xFF8898AA),
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
            textAlign: textAlign,
          ),
      ],
    );
  }
}
