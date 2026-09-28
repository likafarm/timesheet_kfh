import 'api_client.dart';
import 'failures.dart';

/// Остаток сотрудника за месяц: на начало, начислено, выплачено, на конец.
class MonthBalance {
  final String employeeUuid;
  final String fullName;
  final double starting;
  final double accrued;
  final double paid;
  final double closing;

  const MonthBalance({
    required this.employeeUuid,
    required this.fullName,
    required this.starting,
    required this.accrued,
    required this.paid,
    required this.closing,
  });

  factory MonthBalance.fromJson(Object? json) {
    if (json is! Map) throw ServerFailure('неверная строка остатков');
    double n(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return MonthBalance(
      employeeUuid: '${json['employee_uuid']}',
      fullName: '${json['full_name']}',
      starting: n('starting'),
      accrued: n('accrued'),
      paid: n('paid'),
      closing: n('closing'),
    );
  }
}

/// Остатки сотрудника до и после пересчёта.
class BalanceChange {
  final MonthBalance before;
  final MonthBalance after;

  const BalanceChange(this.before, this.after);

  String get fullName => after.fullName;
}

/// Строки одного месяца: `(год, месяц, строки)`.
typedef MonthRows<T> = ({int year, int month, List<T> rows});

List<MonthRows<T>> _months<T>(Object? json, T Function(Object? row) row) {
  if (json is! List) throw ServerFailure('нет списка месяцев');
  return [
    for (final m in json)
      if (m is Map && m['year'] is int && m['month'] is int)
        (
          year: m['year'] as int,
          month: m['month'] as int,
          rows: [for (final e in (m['employees'] as List? ?? const [])) row(e)],
        ),
  ];
}

PeriodLockInfo? _lock(Object? json) => json is Map
    ? PeriodLockInfo(
        year: json['year'] as int? ?? 0,
        month: json['month'] as int? ?? 0,
        lockedByName: json['locked_by_name'] as String?,
        lockedAt: DateTime.tryParse('${json['locked_at']}'),
        note: json['note'] as String?,
      )
    : null;

/// Что изменит открытие месяца: по месяцам — у кого станут другими остаток
/// на начало, начисления или выплаты. Пусто — ничего не изменится.
class UnlockPreview {
  final int year;
  final int month;

  /// Закрытие, которое будет снято.
  final PeriodLockInfo? lock;
  final List<MonthRows<BalanceChange>> changes;

  const UnlockPreview({
    required this.year,
    required this.month,
    required this.lock,
    required this.changes,
  });

  factory UnlockPreview.fromJson(Map<String, Object?> json) => UnlockPreview(
    year: json['year'] as int,
    month: json['month'] as int,
    lock: _lock(json['lock']),
    changes: _months(json['changes'], (row) {
      if (row is! Map) throw ServerFailure('неверная строка изменений');
      return BalanceChange(
        MonthBalance.fromJson(row['before']),
        MonthBalance.fromJson(row['after']),
      );
    }),
  );
}

/// Снимок остатков, сохранённый сервером перед открытием месяца.
class PeriodSnapshot {
  final int id;
  final int year;
  final int month;
  final DateTime? createdAt;
  final String? createdByName;

  /// Закрытие, которое сняли.
  final PeriodLockInfo? lock;

  /// Остатки по месяцам до открытия (в списке снимков — пусто).
  final List<MonthRows<MonthBalance>> months;

  const PeriodSnapshot({
    required this.id,
    required this.year,
    required this.month,
    this.createdAt,
    this.createdByName,
    this.lock,
    this.months = const [],
  });

  factory PeriodSnapshot.fromJson(Object? json) {
    if (json is! Map) throw ServerFailure('неверный снимок');
    return PeriodSnapshot(
      id: json['id'] as int,
      year: json['year'] as int,
      month: json['month'] as int,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      createdByName: json['created_by_name'] as String?,
      lock: _lock(json['lock']),
      months: json['months'] == null
          ? const []
          : _months(json['months'], MonthBalance.fromJson),
    );
  }
}
