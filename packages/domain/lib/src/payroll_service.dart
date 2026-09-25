import 'payroll.dart';
import 'repositories.dart';

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

  /// Входящий остаток на начало месяца [date]: начислено за прошлые месяцы
  /// минус выплачено до 1-го числа.
  Future<Map<String, double>> startingBalances(DateTime date) async =>
      combineBalances(
        accrued: await payroll.accruedBefore(date.year, date.month),
        paid: await payments.paidBefore(DateTime(date.year, date.month, 1)),
      );
}
