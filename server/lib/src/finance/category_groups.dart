import 'package:kfh_domain/kfh_domain.dart';
import 'package:uuid/uuid.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../sql.dart';
import '../sync/change_log.dart';
import '../sync/sync_rows.dart';

/// Группы статей (схема 4, сервер 0.10.0).
///
/// Программы 1.18 знают группу статьи только текстом (`group_name`) и
/// присылают статьи без ссылки `group_uuid`. Сервер находит для такой
/// статьи группу того же вида с тем же названием, а если её нет — заводит.
/// Записи сервера идут в журнал изменений (`edited_by = server`) и доходят
/// до программ обычной синхронизацией. Вызывающий держит [ChangeLog.lock].
class CategoryGroups {
  /// Кто записал (`edited_by`): у сервера нет id устройства.
  static const editor = 'server';

  final DateTime Function() _now;
  final _rows = const SyncRows();
  final _log = const ChangeLog();
  static const _uuid = Uuid();

  CategoryGroups({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final _groups = syncTableByName('fin_category_groups')!;
  static final _categories = syncTableByName('fin_categories')!;

  /// Живая группа вида [type] с названием [name]; нет — заводится.
  Future<String> groupFor(
    SqlExecutor sql,
    String type,
    String name, {
    String? userUuid,
    String? deviceId,
    String? requestId,
  }) async {
    final found = await _rows.live(
      sql,
      _groups,
      where: 'type = :t AND name = :n',
      params: {'t': type, 'n': name},
    );
    if (found.isNotEmpty) return found.first.uuid;
    final change = SyncChange(
      table: _groups.name,
      uuid: _uuid.v7(),
      updatedAt: _now().toUtc(),
      deleted: false,
      data: {
        'legacy_id': null,
        'type': type,
        'name': name,
        'sort_order': await _sortOrder(sql, type, name),
        'hidden': false,
      },
    );
    await _rows.insert(sql, _groups, change, editor);
    await _log.append(sql, _groups.name, change.uuid, deleted: false);
    await writeAudit(
      sql,
      action: 'category_group_auto',
      userUuid: userUuid,
      deviceId: deviceId,
      requestId: requestId,
      entity: _groups.name,
      entityUuid: change.uuid,
      newValue: change.data,
    );
    return change.uuid;
  }

  /// Порядок новой группы: номер в начале названия («03. Персонал» → 3),
  /// иначе — после последней группы этого вида.
  static Future<int> _sortOrder(
    SqlExecutor sql,
    String type,
    String name,
  ) async {
    final number = RegExp(r'^\s*(\d{1,6})').firstMatch(name);
    if (number != null) return int.parse(number.group(1)!);
    final r = await sql(
      'SELECT COALESCE(MAX(sort_order), 0) AS m FROM fin_category_groups '
      'WHERE deleted = 0 AND type = :t',
      {'t': type},
    );
    return r.rows.single.intOf('m') + 1;
  }

  /// Все живые статьи без группы получают её (новой версией записи).
  /// Возвращает число привязанных статей.
  Future<int> linkAll(SqlExecutor sql) async {
    final orphans = await _rows.live(
      sql,
      _categories,
      where: 'group_uuid IS NULL',
    );
    for (final c in orphans) {
      final group = await groupFor(
        sql,
        c.data['type'] as String,
        c.data['group_name'] as String,
      );
      final now = _now().toUtc();
      final change = SyncChange(
        table: _categories.name,
        uuid: c.uuid,
        // Новая версия должна быть позже прежней, даже если часы отстали.
        updatedAt: now.isAfter(c.updatedAt)
            ? now
            : c.updatedAt.add(const Duration(microseconds: 1)),
        deleted: false,
        data: {...c.data, 'group_uuid': group},
      );
      await _rows.update(sql, _categories, change, editor);
      await _log.append(sql, _categories.name, c.uuid, deleted: false);
      await writeAudit(
        sql,
        action: 'category_group_link',
        entity: _categories.name,
        entityUuid: c.uuid,
        oldValue: c.data,
        newValue: change.data,
      );
    }
    return orphans.length;
  }

  /// Вид группы [groupUuid] (null — группы нет или она удалена).
  Future<String?> typeOf(SqlExecutor sql, String groupUuid) async {
    final r = await sql(
      'SELECT type FROM fin_category_groups WHERE uuid = :u AND deleted = 0',
      {'u': groupUuid},
    );
    return r.rows.isEmpty ? null : r.rows.first.textOf('type');
  }
}
