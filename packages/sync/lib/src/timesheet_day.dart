/// Табель одного дня с авторами отметок (`GET /timesheet/day`, 6.10) — для
/// напоминания: если за день уже внёс кто-то другой, вместо «заполните
/// табель» приходит «За сегодня табель внесён тем-то: …».
class DayMarkInfo {
  final String employeeUuid;
  final String employeeName;
  final String dayType;
  final double days;
  final String? workPlace;

  /// Кто последним менял отметку (null — неизвестно, например импорт).
  final String? userUuid;
  final String? userName;
  final String? userLogin;
  final DateTime? at;

  const DayMarkInfo({
    required this.employeeUuid,
    required this.employeeName,
    required this.dayType,
    required this.days,
    this.workPlace,
    this.userUuid,
    this.userName,
    this.userLogin,
    this.at,
  });

  factory DayMarkInfo.fromJson(Map<String, Object?> json) => DayMarkInfo(
    employeeUuid: json['employee_uuid'] as String,
    employeeName: json['employee_name'] as String? ?? '',
    dayType: json['day_type'] as String? ?? 'work',
    days: (json['days'] as num?)?.toDouble() ?? 1,
    workPlace: json['work_place'] as String?,
    userUuid: json['user_uuid'] as String?,
    userName: json['user_name'] as String?,
    userLogin: json['user_login'] as String?,
    at: DateTime.tryParse('${json['at']}'),
  );

  /// Кто внёс — для человека.
  String get author => userName ?? userLogin ?? 'неизвестно кто';
}

class TimesheetDayInfo {
  final DateTime date;

  /// Сколько сотрудников работает в этот день (принят, не уволен).
  final int activeEmployees;
  final List<DayMarkInfo> records;

  const TimesheetDayInfo({
    required this.date,
    required this.activeEmployees,
    required this.records,
  });

  factory TimesheetDayInfo.fromJson(Map<String, Object?> json) {
    final date = DateTime.parse(json['date'] as String);
    final records = json['records'];
    return TimesheetDayInfo(
      date: DateTime(date.year, date.month, date.day),
      activeEmployees: json['active_employees'] as int? ?? 0,
      records: [
        if (records is List)
          for (final r in records)
            if (r is Map<String, Object?>) DayMarkInfo.fromJson(r),
      ],
    );
  }

  /// Отметки, которые внёс не [userUuid], по авторам (порядок — как пришли).
  Map<String, List<DayMarkInfo>> byOthers(String userUuid) {
    final result = <String, List<DayMarkInfo>>{};
    for (final r in records) {
      if (r.userUuid == userUuid) continue;
      result.putIfAbsent(r.author, () => []).add(r);
    }
    return result;
  }

  /// Все работающие отмечены.
  bool get filled => records.length >= activeEmployees;
}

/// Итог отметок: «5 база, 2 поле, 1 больничный».
String describeMarks(Iterable<DayMarkInfo> marks) {
  final counts = <String, int>{};
  for (final m in marks) {
    final label = switch (m.dayType) {
      'work' when m.days == 0.5 => m.workPlace == 'field' ? '½ поле' : '½ база',
      'work' => m.workPlace == 'field' ? 'поле' : 'база',
      'sick' => 'больничный',
      'vacation' => 'отпуск',
      'dayoff' => 'выходной',
      _ => m.dayType,
    };
    counts[label] = (counts[label] ?? 0) + 1;
  }
  const order = [
    'база',
    'поле',
    '½ база',
    '½ поле',
    'больничный',
    'отпуск',
    'выходной',
  ];
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final ia = order.indexOf(a), ib = order.indexOf(b);
      return (ia < 0 ? order.length : ia).compareTo(ib < 0 ? order.length : ib);
    });
  return [for (final k in keys) '${counts[k]} $k'].join(', ');
}

/// Сообщение «табель внесён» для [userUuid]; null — другие ничего не
/// вносили (тогда — обычное напоминание, если день не заполнен).
({String title, String text})? enteredByOthersMessage(
  TimesheetDayInfo day,
  String userUuid,
) {
  final others = day.byOthers(userUuid);
  if (others.isEmpty) return null;
  final authors = others.keys.toList();
  final lines = [
    for (final MapEntry(key: author, value: marks) in others.entries)
      '$author: ${describeMarks(marks)}',
  ];
  return (
    title: authors.length == 1
        ? 'Табель за сегодня внесён: ${authors.single}'
        : 'Табель за сегодня внесён',
    text:
        '${lines.join('\n')}\n'
        'Отмечено ${day.records.length} из ${day.activeEmployees}',
  );
}
