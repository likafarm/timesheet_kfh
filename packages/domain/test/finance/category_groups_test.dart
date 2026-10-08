import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Группы статей (справочник) и совместимость с программами 1.18.
void main() {
  const cattle = FinCategoryGroup(
    id: 'g-cattle',
    type: CategoryType.expense,
    name: '01. Скот',
  );
  const staff = FinCategoryGroup(
    id: 'g-staff',
    type: CategoryType.expense,
    name: '03. Персонал',
    sortOrder: 3,
  );
  const income = FinCategoryGroup(
    id: 'g-main',
    type: CategoryType.income,
    name: '01. Скот',
  );
  final catalog = FinanceCatalog(groups: const [staff, cattle, income]);

  group('groupOf', () {
    test('по ссылке — даже если название-копия устарело', () {
      const c = FinCategory(
        id: 'c',
        type: CategoryType.expense,
        groupId: 'g-staff',
        group: 'Старое название',
        name: 'Рабочие',
      );
      expect(catalog.groupOf(c), staff);
    });

    test('без ссылки (запись 1.18) — по виду и названию', () {
      const c = FinCategory(
        id: 'c',
        type: CategoryType.income,
        group: '01. Скот',
        name: 'Мясо',
      );
      expect(catalog.groupOf(c), income);
      const unknown = FinCategory(
        id: 'c',
        type: CategoryType.expense,
        group: '99. Нет такой',
        name: 'Прочее',
      );
      expect(catalog.groupOf(unknown), isNull);
    });

    test('группы вида — по порядку, затем по названию', () {
      expect(catalog.groupsOf(CategoryType.expense), [cattle, staff]);
      expect(catalog.groupsOf(CategoryType.income), [income]);
    });
  });

  group('обмен: group_uuid у статьи', () {
    final table = syncTableByName('fin_categories')!;
    final groups = syncTableByName('fin_category_groups')!;
    Map<String, Object?> row({bool withGroup = true}) => {
      'legacy_id': null,
      'type': 'expense',
      if (withGroup) 'group_uuid': '0192a3b4-0000-7000-8000-000000000001',
      'group_name': '01. Скот',
      'name': 'Коровы',
      'direction_uuid': null,
      'allocation_key_uuid': null,
      'kind': 'current',
      'in_tax_book': true,
      'hidden': false,
      'sort_order': 0,
    };

    test('группы пишутся раньше статей', () {
      expect(
        syncTableOrder('fin_category_groups'),
        lessThan(syncTableOrder('fin_categories')),
      );
      expect(legacySyncTableNames, isNot(contains(groups.name)));
    });

    test('строка программы 1.18 без колонки — принимается с null', () {
      final data = validateSyncData(table, row(withGroup: false));
      expect(data.containsKey('group_uuid'), isTrue);
      expect(data['group_uuid'], isNull);
      expect(
        validateSyncData(table, row())['group_uuid'],
        '0192a3b4-0000-7000-8000-000000000001',
      );
    });

    test('другие колонки по-прежнему обязательны', () {
      expect(
        () => validateSyncData(table, row()..remove('group_name')),
        throwsA(isA<SyncFormatException>()),
      );
    });

    test('программе 1.18 колонку не отдают', () {
      expect(unknownColumnsFor(table, {'fin_categories'}), {'group_uuid'});
      expect(
        unknownColumnsFor(table, {'fin_categories', 'fin_category_groups'}),
        isEmpty,
      );
      expect(unknownColumnsFor(groups, {'fin_categories'}), isEmpty);
    });
  });

  group('tablesToCatchUp', () {
    final all = {for (final t in syncTables) t.name};

    test(
      'база до 1.19 — группы и статьи (их колонка появилась с группами)',
      () {
        expect(tablesToCatchUp(null, all), {
          'fin_category_groups',
          'fin_categories',
        });
      },
    );

    test('всё уже получает — ничего', () {
      expect(tablesToCatchUp(all, all), isEmpty);
    });

    test('новая таблица без связанных колонок — только она', () {
      final known = {...all}..remove('payroll_adjustments');
      expect(tablesToCatchUp(known, all), {'payroll_adjustments'});
    });
  });
}
