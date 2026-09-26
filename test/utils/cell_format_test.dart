import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/utils/cell_format.dart';

ColumnInfo col(String name, {String type = 'TEXT', bool isDate = false}) =>
    ColumnInfo(
      name: name,
      type: type,
      notNull: false,
      isDate: isDate,
      isSync: false,
    );

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('formatCell', () {
    test('день ISO — дд.мм.гггг', () {
      expect(formatCell('2026-09-01'), '01.09.2026');
    });

    test('момент в UTC — по местному времени', () {
      final utc = DateTime.utc(2026, 9, 25, 22, 9, 19);
      final local = utc.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      expect(
        formatCell('2026-09-25T22:09:19.322533Z'),
        '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}',
      );
    });

    test('момент без зоны — как есть', () {
      expect(formatCell('2026-09-01T08:00:00.000'), '01.09.2026 08:00:00');
    });

    test('прочее без изменений, пусто — прочерк', () {
      expect(formatCell('Иванов Иван'), 'Иванов Иван');
      expect(formatCell(0.5), '0.5');
      expect(formatCell(null), '—');
    });
  });

  test('cellToInput: день — дд.мм.гггг', () {
    expect(cellToInput('2026-09-01'), '01.09.2026');
    expect(cellToInput(1500.0), '1500.0');
    expect(cellToInput(null), '');
  });

  group('parseCellInput', () {
    final date = col('date', isDate: true);

    test('дата дд.мм.гггг и ISO', () {
      expect(parseCellInput(date, '1.9.2026'), '2026-09-01');
      expect(parseCellInput(date, '01.09.2026'), '2026-09-01');
      expect(parseCellInput(date, '2026-09-01'), '2026-09-01');
    });

    test('несуществующая дата — ошибка', () {
      expect(() => parseCellInput(date, '30.02.2026'), throwsFormatException);
      expect(() => parseCellInput(date, 'вчера'), throwsFormatException);
    });

    test('числа: запятая как разделитель, ошибки формата', () {
      expect(parseCellInput(col('days', type: 'REAL'), '0,5'), 0.5);
      expect(
        parseCellInput(col('amount', type: 'REAL'), '12 345,67'),
        12345.67,
      );
      expect(parseCellInput(col('year', type: 'INTEGER'), '2026'), 2026);
      expect(
        () => parseCellInput(col('year', type: 'INTEGER'), '2026.5'),
        throwsFormatException,
      );
    });

    test('пусто — null, текст как есть', () {
      expect(parseCellInput(col('notes'), '  '), isNull);
      expect(parseCellInput(col('notes'), ' справка '), 'справка');
    });
  });
}
