// lib/utils/day_draft.dart
//
// Черновик ввода за день (6.10, решение владельца 2026-09-30): касание
// отметки меняет только черновик, в базу он попадает по «Сохранить» или
// после подтверждения при уходе с дня. Черновик переживает сворачивание и
// закрытие программы системой (DayDraftStore).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Отметка дня: тип, доля дня и место работы.
class DayMark {
  final String label;
  final String dayType;
  final double days;
  final String? workPlace;
  final Color color;

  const DayMark(
    this.label,
    this.dayType,
    this.days,
    this.workPlace,
    this.color,
  );

  bool matches(TimesheetRecord r) =>
      r.dayType == dayType &&
      (dayType != 'work' || (r.days == days && r.workPlace == workPlace));

  /// Запись табеля с этой отметкой.
  TimesheetRecord record(String employeeId, DateTime date) => TimesheetRecord(
    employeeId: employeeId,
    date: date,
    dayType: dayType,
    days: days,
    workPlace: workPlace,
  );

  static const all = [
    DayMark('База', 'work', 1, 'base', Color(0xFF2E7D32)),
    DayMark('Поле', 'work', 1, 'field', Color(0xFF558B2F)),
    DayMark('½ база', 'work', 0.5, 'base', Color(0xFF66BB6A)),
    DayMark('½ поле', 'work', 0.5, 'field', Color(0xFF9CCC65)),
    DayMark('Больничный', 'sick', 1, null, Color(0xFF1976D2)),
    DayMark('Отпуск', 'vacation', 1, null, Color(0xFF7B1FA2)),
    DayMark('Выходной', 'dayoff', 1, null, Color(0xFF757575)),
  ];

  /// Отметка записи (null — такой среди кнопок нет, например день без
  /// места работы).
  static DayMark? of(TimesheetRecord r) {
    for (final m in all) {
      if (m.matches(r)) return m;
    }
    return null;
  }

  /// Подпись записи для человека: «Поле», «—» (нет отметки).
  static String describe(TimesheetRecord? r) {
    if (r == null) return '—';
    final mark = of(r);
    if (mark != null) return mark.label;
    return switch (r.dayType) {
      'work' => r.days == 0.5 ? '½ дня' : 'Работа',
      _ => r.dayType,
    };
  }

  /// Ключ для сравнения: одинаковые отметки — одинаковый ключ.
  static String signature(TimesheetRecord? r) => r == null
      ? ''
      : '${r.dayType}|${r.dayType == 'work' ? r.days : 1}|'
            '${r.dayType == 'work' ? r.workPlace ?? '' : ''}';
}

/// Ответ окна «Сохранить отметки?» (телефон) и «Сохранить изменения за …?»
/// (групповой ввод Windows).
enum DraftDecision { save, discard, stay }

/// Правка черновика для окна подтверждения.
class DayDraftChange {
  final String employeeId;

  /// Новая отметка (null — отметку снять).
  final DayMark? mark;

  /// Что было, когда правку начали.
  final String before;

  /// Запись в базе с тех пор изменилась (например, пришла с сервера):
  /// что там сейчас. null — не менялась.
  final String? changedMeanwhile;

  const DayDraftChange({
    required this.employeeId,
    required this.mark,
    required this.before,
    this.changedMeanwhile,
  });

  String get after => mark?.label ?? 'отметка снята';
}

/// Несохранённые отметки одного дня.
class DayDraft {
  final DateTime date;

  /// Сотрудник → новая отметка (null — снять).
  final Map<String, DayMark?> _marks = {};

  /// Сотрудник → [DayMark.signature] записи, когда правку начали.
  final Map<String, String> _base = {};

  /// Сотрудник → подпись записи, когда правку начали.
  final Map<String, String> _baseLabel = {};

  DayDraft(DateTime date) : date = DateTime(date.year, date.month, date.day);

  bool get isEmpty => _marks.isEmpty;
  int get length => _marks.length;
  Iterable<String> get employeeIds => _marks.keys;

  bool changes(String employeeId) => _marks.containsKey(employeeId);

  /// Новая отметка сотрудника (есть только если [changes]).
  DayMark? markOf(String employeeId) => _marks[employeeId];

  /// Подпись записи на момент начала правки.
  String? beforeOf(String employeeId) => _baseLabel[employeeId];

  /// Отметить сотрудника: [mark] = null — снять отметку. [saved] — запись
  /// в базе сейчас. Отметка, совпавшая с записью в базе, правкой не
  /// считается.
  void set(String employeeId, DayMark? mark, TimesheetRecord? saved) {
    final savedSignature = DayMark.signature(saved);
    final newSignature = mark == null
        ? ''
        : DayMark.signature(mark.record(employeeId, date));
    if (newSignature == savedSignature) {
      discard(employeeId);
      return;
    }
    _base.putIfAbsent(employeeId, () => savedSignature);
    _baseLabel.putIfAbsent(employeeId, () => DayMark.describe(saved));
    _marks[employeeId] = mark;
  }

  void discard(String employeeId) {
    _marks.remove(employeeId);
    _base.remove(employeeId);
    _baseLabel.remove(employeeId);
  }

  void clear() {
    _marks.clear();
    _base.clear();
    _baseLabel.clear();
  }

  /// Запись в базе изменилась после начала правки: что там сейчас.
  String? changedMeanwhile(String employeeId, TimesheetRecord? saved) {
    final base = _base[employeeId];
    if (base == null || base == DayMark.signature(saved)) return null;
    return DayMark.describe(saved);
  }

  /// Правки для окна подтверждения; [saved] — записи дня в базе сейчас.
  List<DayDraftChange> list(Map<String, TimesheetRecord> saved) => [
    for (final MapEntry(key: id, value: mark) in _marks.entries)
      DayDraftChange(
        employeeId: id,
        mark: mark,
        before: _baseLabel[id] ?? '—',
        changedMeanwhile: changedMeanwhile(id, saved[id]),
      ),
  ];

  /// Что записать в базу: сотрудник → запись (null — снять отметку).
  Map<String, TimesheetRecord?> toRecords() => {
    for (final MapEntry(key: id, value: mark) in _marks.entries)
      id: mark?.record(id, date),
  };

  Map<String, Object?> toJson() => {
    'date': formatDateIso(date),
    'marks': {
      for (final MapEntry(key: id, value: mark) in _marks.entries)
        id: {
          'mark': mark == null ? null : DayMark.all.indexOf(mark),
          'base': _base[id],
          'before': _baseLabel[id],
        },
    },
  };

  static DayDraft? fromJson(Map<String, Object?> json) {
    final date = json['date'];
    final marks = json['marks'];
    if (date is! String || marks is! Map) return null;
    final draft = DayDraft(parseDateIso(date));
    for (final MapEntry(key: id, value: v) in marks.entries) {
      if (id is! String || v is! Map) continue;
      final index = v['mark'];
      if (index != null &&
          (index is! int || index < 0 || index >= DayMark.all.length)) {
        continue;
      }
      draft._marks[id] = index == null ? null : DayMark.all[index as int];
      draft._base[id] = v['base'] as String? ?? '';
      draft._baseLabel[id] = v['before'] as String? ?? '—';
    }
    return draft.isEmpty ? null : draft;
  }
}

/// Черновик дня на диске: переживает закрытие программы системой (например,
/// пока человек отвечал на звонок). Один на устройство.
class DayDraftStore {
  static const _key = 'kfh_day_draft';

  DayDraftStore._();

  static Future<DayDraft?> load() async {
    try {
      final text = (await SharedPreferences.getInstance()).getString(_key);
      if (text == null) return null;
      return DayDraft.fromJson(jsonDecode(text) as Map<String, Object?>);
    } catch (_) {
      // Нет хранилища (тесты) или испорченная запись — черновика нет.
      return null;
    }
  }

  static Future<void> save(DayDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (draft.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(draft.toJson()));
      }
    } catch (_) {
      // Не сохранился на диск — останется в памяти.
    }
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}
