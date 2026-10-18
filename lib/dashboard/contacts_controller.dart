import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';

enum ContactKind { customer, vendor, both }

String contactKindLabel(ContactKind k) {
  switch (k) {
    case ContactKind.customer:
      return 'Customer';
    case ContactKind.vendor:
      return 'Vendor';
    case ContactKind.both:
      return 'Both';
  }
}

ContactKind contactKindFromJson(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'customer':
      return ContactKind.customer;
    case 'vendor':
      return ContactKind.vendor;
    default:
      return ContactKind.both;
  }
}

String contactKindToJson(ContactKind k) {
  switch (k) {
    case ContactKind.customer:
      return 'customer';
    case ContactKind.vendor:
      return 'vendor';
    case ContactKind.both:
      return 'both';
  }
}

/// Kind to use when creating a contact from an income/expense form.
ContactKind contactKindForMoneyMove(bool isIncome) =>
    isIncome ? ContactKind.customer : ContactKind.vendor;

class ContactRecord {
  const ContactRecord({
    required this.id,
    required this.portfolioId,
    required this.name,
    required this.kind,
    this.email,
    this.phone,
    this.notes,
    this.sortOrder = 0,
  });

  final String id;
  final String portfolioId;
  final String name;
  final ContactKind kind;
  final String? email;
  final String? phone;
  final String? notes;
  final int sortOrder;

  factory ContactRecord.fromJson(Map<String, dynamic> json) {
    return ContactRecord(
      id: json['id'] as String? ?? '',
      portfolioId: json['portfolioId'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      kind: contactKindFromJson(json['kind'] as String?),
      email: (json['email'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      notes: (json['notes'] as String?)?.trim(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  bool matchesKind(ContactKind? filter) {
    if (filter == null || filter == ContactKind.both) return true;
    if (kind == ContactKind.both) return true;
    return kind == filter;
  }
}

class ContactsController extends ChangeNotifier {
  ContactsController(this._auth);

  factory ContactsController.fake() {
    final c = ContactsController(AuthController.fake());
    c._items = [
      const ContactRecord(
        id: 'c1',
        portfolioId: 'fake-personal',
        name: 'Acme Corp',
        kind: ContactKind.vendor,
        email: 'billing@acme.example',
      ),
      const ContactRecord(
        id: 'c2',
        portfolioId: 'fake-personal',
        name: 'Jordan Lee',
        kind: ContactKind.customer,
        email: 'jordan@example.com',
      ),
    ];
    c._spaceId = 'fake-personal';
    c._loading = false;
    return c;
  }

  final AuthController _auth;

  List<ContactRecord> _items = [];
  String _spaceId = '';
  bool _loading = true;

  List<ContactRecord> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  String get spaceId => _spaceId;

  List<ContactRecord> forKind(ContactKind? kind) {
    final list = _items.where((c) => c.matchesKind(kind)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  ContactRecord? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> loadForSpace(String spaceId) async {
    _spaceId = spaceId;
    if (spaceId.isEmpty || spaceId == 'pending') {
      _items = [];
      _loading = false;
      notifyListeners();
      return;
    }
    if (_auth.isFake) {
      _items = ContactsController.fake()._items;
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final decoded = await _auth.apiDecode(
        'GET',
        '/api/contacts?portfolio_id=${Uri.encodeQueryComponent(spaceId)}',
      );
      final list = <ContactRecord>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(ContactRecord.fromJson(item));
          }
        }
      }
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      _items = list;
    } catch (e) {
      debugPrint('ContactsController.load: $e');
      _items = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<ContactRecord?> create({
    required String name,
    ContactKind kind = ContactKind.both,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _spaceId.isEmpty) return null;
    if (_auth.isFake) {
      final row = ContactRecord(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        portfolioId: _spaceId,
        name: trimmed,
        kind: kind,
        email: email?.trim(),
        phone: phone?.trim(),
        notes: notes?.trim(),
      );
      _items = [..._items, row]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
      return row;
    }
    final decoded = await _auth.apiDecode(
      'POST',
      '/api/contacts',
      body: {
        'portfolioId': _spaceId,
        'name': trimmed,
        'kind': contactKindToJson(kind),
        if (email != null) 'email': email.trim().isEmpty ? null : email.trim(),
        if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
        if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
      },
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = ContactRecord.fromJson(decoded);
    _items = [..._items, row]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    return row;
  }

  Future<ContactRecord?> update(
    String id, {
    String? name,
    ContactKind? kind,
    String? email,
    String? phone,
    String? notes,
  }) async {
    if (_auth.isFake) {
      final idx = _items.indexWhere((c) => c.id == id);
      if (idx < 0) return null;
      final cur = _items[idx];
      final row = ContactRecord(
        id: cur.id,
        portfolioId: cur.portfolioId,
        name: name?.trim().isNotEmpty == true ? name!.trim() : cur.name,
        kind: kind ?? cur.kind,
        email: email ?? cur.email,
        phone: phone ?? cur.phone,
        notes: notes ?? cur.notes,
        sortOrder: cur.sortOrder,
      );
      _items = [..._items]..[idx] = row;
      notifyListeners();
      return row;
    }
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (kind != null) body['kind'] = contactKindToJson(kind);
    if (email != null) body['email'] = email.trim().isEmpty ? null : email.trim();
    if (phone != null) body['phone'] = phone.trim().isEmpty ? null : phone.trim();
    if (notes != null) body['notes'] = notes.trim().isEmpty ? null : notes.trim();
    final decoded = await _auth.apiDecode(
      'PATCH',
      '/api/contacts/$id',
      body: body,
    );
    if (decoded is! Map<String, dynamic>) return null;
    final row = ContactRecord.fromJson(decoded);
    _items = [
      for (final c in _items)
        if (c.id == id) row else c,
    ];
    notifyListeners();
    return row;
  }

  Future<bool> remove(String id) async {
    if (_auth.isFake) {
      _items = _items.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    }
    final decoded = await _auth.apiDecode('DELETE', '/api/contacts/$id');
    if (decoded == null) return false;
    _items = _items.where((c) => c.id != id).toList();
    notifyListeners();
    return true;
  }
}
