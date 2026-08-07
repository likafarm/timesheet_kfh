/// Модель вида работы в КФХ
class WorkType {
  final int? id;
  final String name;
  final String category; // 'field', 'animal', 'repair', 'other'
  final double? defaultRateMultiplier;
  final String? notes;

  WorkType({
    this.id,
    required this.name,
    this.category = 'field',
    this.defaultRateMultiplier,
    this.notes,
  });

  factory WorkType.fromMap(Map<String, dynamic> map) {
    return WorkType(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String? ?? 'field',
      defaultRateMultiplier: map['default_rate_multiplier'] != null
          ? (map['default_rate_multiplier'] as num).toDouble()
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'default_rate_multiplier': defaultRateMultiplier,
      'notes': notes,
    };
  }

  /// Название категории на русском
  String get categoryName {
    switch (category) {
      case 'field':
        return 'Полевые работы';
      case 'animal':
        return 'Животноводство';
      case 'repair':
        return 'Ремонт';
      default:
        return 'Прочее';
    }
  }

  WorkType copyWith({
    int? id,
    String? name,
    String? category,
    double? defaultRateMultiplier,
    String? notes,
  }) {
    return WorkType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      defaultRateMultiplier:
          defaultRateMultiplier ?? this.defaultRateMultiplier,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'WorkType(id: $id, name: $name)';
}
