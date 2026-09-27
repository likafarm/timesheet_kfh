// Интерфейсы хранилища. Приложение работает только через них;
// реализация на drift — в пакете kfh_local_db.
//
// Удаление везде мягкое: запись помечается удалённой и пропадает
// из выборок, но остаётся в базе (нужно для синхронизации).

import 'models/company_settings.dart';
import 'models/employee.dart';
import 'models/employee_rate.dart';
import 'models/payment.dart';
import 'models/payroll_result.dart';
import 'models/timesheet_record.dart';

/// Нарушение уникальности: такая запись уже есть
/// (например, второй день табеля на ту же дату).
class DuplicateEntryException implements Exception {
  final String message;
  const DuplicateEntryException(this.message);

  @override
  String toString() => message;
}

abstract interface class EmployeeRepository {
  /// Сотрудники по ФИО; [activeOn] — только не уволенные на эту дату.
  Future<List<Employee>> all({DateTime? activeOn});
  Future<Employee?> byId(String id);

  /// Возвращает id нового сотрудника.
  Future<String> add(Employee employee);
  Future<void> update(Employee employee);

  /// Мягкое удаление без каскада: табель, ставки и выплаты остаются.
  Future<void> delete(String id);
}

abstract interface class RateRepository {
  /// Добавляет ставку; действующая ставка сотрудника закрывается датой
  /// «начало новой − 1 день». Возвращает id.
  Future<String> add(EmployeeRate rate);

  /// История ставок по дате начала.
  Future<List<EmployeeRate>> history(String employeeId);

  /// Ставка, действующая на [date].
  Future<EmployeeRate?> at(String employeeId, DateTime date);
}

abstract interface class TimesheetRepository {
  /// Возвращает id записи. Если на эту дату у сотрудника запись уже есть —
  /// [DuplicateEntryException].
  Future<String> add(TimesheetRecord record);
  Future<void> update(TimesheetRecord record);
  Future<void> delete(String id);

  Future<TimesheetRecord?> on(String employeeId, DateTime date);

  /// Записи за период включительно, новые сверху.
  Future<List<TimesheetRecord>> inPeriod(
    DateTime start,
    DateTime end, {
    String? employeeId,
  });
}

abstract interface class PaymentRepository {
  Future<String> add(Payment payment);
  Future<void> update(Payment payment);
  Future<void> delete(String id);

  /// Выплаты, новые сверху; [start] и [end] (оба сразу) — период
  /// включительно.
  Future<List<Payment>> list({
    String? employeeId,
    DateTime? start,
    DateTime? end,
  });

  /// Сумма выплат по сотрудникам строго до [date].
  Future<Map<String, double>> paidBefore(DateTime date);
}

abstract interface class PayrollRepository {
  /// Сохраняет расчёт за месяц (заменяет прежний). Возвращает id.
  Future<String> save(PayrollResult result);

  /// Мягкое удаление сохранённого расчёта (сотрудник выпал из расчёта).
  Future<void> delete(String id);
  Future<PayrollResult?> resultFor(String employeeId, int year, int month);
  Future<List<PayrollResult>> forMonth(int year, int month);

  /// Начислено по сотрудникам за месяцы строго до [year]-[month].
  Future<Map<String, double>> accruedBefore(int year, int month);
}

abstract interface class SettingsRepository {
  Future<CompanySettings> get();
  Future<void> save(CompanySettings settings);
}
