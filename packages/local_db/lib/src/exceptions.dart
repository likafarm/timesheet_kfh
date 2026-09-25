/// Нарушение уникальности: такая запись уже есть
/// (например, второй день табеля на ту же дату).
class DuplicateEntryException implements Exception {
  final String message;
  const DuplicateEntryException(this.message);

  @override
  String toString() => message;
}
