import 'models/payroll_result.dart';
import 'payroll.dart';
import 'repositories.dart';

/// Итог сохранения расчёта за месяц.
class PayrollMonthSave {
  /// Сохранено (записано или обновлено) расчётов.
  final int saved;

  /// Удалено прежних расчётов — сотрудник выпал из расчёта.
  final int removed;

  const PayrollMonthSave(this.saved, this.removed);
}

/// Расчёт ЗП поверх хранилища: загружает данные из репозиториев
/// и передаёт их в чистые функции из payroll.dart.
class PayrollService {
  final EmployeeRepository employees;
  final RateRepository rates;
  final TimesheetRepository timesheet;
  final PaymentRepository payments;
  final PayrollRepository payroll;

  PayrollService({
    required this.employees,
    required this.rates,
    required this.timesheet,
    required this.payments,
    required this.payroll,
  });

  /// Расчёт за месяц по табелю и истории ставок.
  Future<PayrollCalculation> calculateMonth(
    String employeeId,
    int year,
    int month,
  ) async {
    final employee = await employees.byId(employeeId);
    if (employee == null) throw StateError('Сотрудник не найден');
    final records = await timesheet.inPeriod(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 0),
      employeeId: employeeId,
    );
    return calculateMonthlySalary(
      employeeId: employeeId,
      year: year,
      month: month,
      records: records,
      rates: await rates.history(employeeId),
    );
  }

  /// Сотрудники, которым в месяце что-то выплачено.
  Future<Set<String>> paidInMonth(int year, int month) async => {
        for (final p in await payments.list(
          start: DateTime(year, month, 1),
          end: DateTime(year, month + 1, 0),
        ))
          p.employeeId,
      };

  /// Считает и сохраняет месяц — для всех сотрудников (включая уволенных)
  /// или только для [employeeId]. Сотрудник без начислений, выплат за
  /// месяц и входящего остатка ([payrollNeeded]) в расчёт не входит:
  /// расчёт не сохраняется, а прежний сохранённый удаляется.
  Future<PayrollMonthSave> saveMonth(
    int year,
    int month, {
    String? employeeId,
  }) async {
    final ids = employeeId != null
        ? [employeeId]
        : [
            for (final e in await employees.all())
              if (e.id != null) e.id!,
          ];
    final paid = await paidInMonth(year, month);
    final balances = await startingBalances(DateTime(year, month, 1));
    var saved = 0, removed = 0;
    for (final id in ids) {
      final calc = await calculateMonth(id, year, month);
      if (payrollNeeded(
          emptyPayroll: calc.isEmpty,
          paidInMonth: paid.contains(id),
          startingBalance: balances[id] ?? 0)) {
        await payroll.save(PayrollResult.fromCalculation(calc));
        saved++;
      } else {
        final old = await payroll.resultFor(id, year, month);
        if (old?.id != null) {
          await payroll.delete(old!.id!);
          removed++;
        }
      }
    }
    return PayrollMonthSave(saved, removed);
  }

  /// Сохранённые расчёты месяца для отчёта: без сотрудников, у которых в
  /// месяце нет ни начислений, ни выплат, ни входящего остатка (такие
  /// строки могли остаться от расчётов до 2026-09-26 — они исчезнут и из
  /// базы при пересчёте).
  Future<List<PayrollResult>> resultsForReport(int year, int month) async {
    final paid = await paidInMonth(year, month);
    final balances = await startingBalances(DateTime(year, month, 1));
    return [
      for (final r in await payroll.forMonth(year, month))
        if (payrollNeeded(
            emptyPayroll: r.isEmpty,
            paidInMonth: paid.contains(r.employeeId),
            startingBalance: balances[r.employeeId] ?? 0))
          r,
    ];
  }

  /// Входящий остаток на начало месяца [date]: начислено за прошлые месяцы
  /// минус выплачено до 1-го числа.
  Future<Map<String, double>> startingBalances(DateTime date) async =>
      combineBalances(
        accrued: await payroll.accruedBefore(date.year, date.month),
        paid: await payments.paidBefore(DateTime(date.year, date.month, 1)),
      );
}
