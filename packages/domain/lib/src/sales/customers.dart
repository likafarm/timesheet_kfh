// packages/domain/lib/src/sales/customers.dart
//
// Покупатели (этап 11.3): отдельная таблица `customers`, а не новые поля
// контрагентов — программы до 1.22 не знают этих полей и при правке
// контрагента затёрли бы их; новую таблицу они просто не получают.
// Телефоны и адреса видят админ, бухгалтер и специалист по продажам,
// оператор покупателей не получает вовсе. Связь с контрагентом финансов
// (`counterpartyId`) заполняется при первой оплате (11.6) — так доходы
// по покупателю видны в отчётах финансов.

/// Как с покупателем связываются.
enum CustomerChannel {
  telegram('telegram', 'Telegram', 'ТГ'),
  whatsapp('whatsapp', 'WhatsApp', 'WA'),
  max('max', 'MAX', 'MAX'),
  vk('vk', 'ВКонтакте', 'ВК'),
  sms('sms', 'СМС', 'СМС'),
  phone('phone', 'Звонок', 'тел.'),
  other('other', 'Другое', 'другое');

  const CustomerChannel(this.code, this.title, this.short);
  final String code;
  final String title;
  final String short;

  static CustomerChannel? fromCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

class Customer {
  final String id;
  final String name;

  /// Телефон как ввели; для поиска и сравнения — [phoneDigits].
  final String? phone;
  final String? address;
  final CustomerChannel? channel;

  /// Имя или ник в мессенджере («Баба Яга», «Pevneva Larissa»).
  final String? contact;
  final String? notes;

  /// Контрагент финансов, на которого пишутся оплаты (11.6).
  final String? counterpartyId;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.channel,
    this.contact,
    this.notes,
    this.counterpartyId,
  });

  Customer copyWith({
    String? name,
    String? Function()? phone,
    String? Function()? address,
    CustomerChannel? Function()? channel,
    String? Function()? contact,
    String? Function()? notes,
    String? Function()? counterpartyId,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone == null ? this.phone : phone(),
    address: address == null ? this.address : address(),
    channel: channel == null ? this.channel : channel(),
    contact: contact == null ? this.contact : contact(),
    notes: notes == null ? this.notes : notes(),
    counterpartyId: counterpartyId == null
        ? this.counterpartyId
        : counterpartyId(),
  );
}

/// Цифры телефона без «+», пробелов и скобок; «8…» и «7…» из 11 цифр —
/// российский номер, приводится к «7…».
String phoneDigits(String? phone) {
  var d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('8')) d = '7${d.substring(1)}';
  if (d.length == 10 && d.startsWith('9')) d = '7$d';
  return d;
}

/// Телефон для показа: российский — «+7 910 915-60-68», иначе как ввели.
String formatPhone(String? phone) {
  final d = phoneDigits(phone);
  if (d.length == 11 && d.startsWith('7')) {
    return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)}-'
        '${d.substring(7, 9)}-${d.substring(9)}';
  }
  return (phone ?? '').trim();
}

/// Почему покупателя не записать; null — можно.
String? customerProblem(Customer c) {
  if (c.name.trim().isEmpty) return 'Укажите имя покупателя';
  final phone = c.phone?.trim() ?? '';
  if (phone.isNotEmpty && phoneDigits(phone).length < 5) {
    return 'Телефон — не меньше 5 цифр';
  }
  return null;
}

/// Проверка строки при приёме (сервер): то же, что окно программы.
String? customerRowProblem(Map<String, Object?> data) {
  if ('${data['name'] ?? ''}'.trim().isEmpty) return 'Укажите имя покупателя';
  return null;
}

String _key(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();

/// Покупатели по запросу [query]: часть имени, ника, адреса или цифры
/// телефона (от 3 цифр); пусто — все. По алфавиту.
List<Customer> searchCustomers(Iterable<Customer> customers, String query) {
  final q = _key(query);
  final digits = query.replaceAll(RegExp(r'\D'), '');
  final result = [
    for (final c in customers)
      if (q.isEmpty ||
          _key(c.name).contains(q) ||
          _key(c.contact ?? '').contains(q) ||
          _key(c.address ?? '').contains(q) ||
          (digits.length >= 3 && phoneDigits(c.phone).contains(digits)))
        c,
  ];
  result.sort((a, b) => _key(a.name).compareTo(_key(b.name)));
  return result;
}

/// Покупатель с тем же телефоном (кроме [exceptId]) — подсказка «уже
/// есть»; null — нет.
Customer? customerWithPhone(
  Iterable<Customer> customers,
  String? phone, {
  String? exceptId,
}) {
  final d = phoneDigits(phone);
  if (d.length < 5) return null;
  for (final c in customers) {
    if (c.id != exceptId && phoneDigits(c.phone) == d) return c;
  }
  return null;
}
