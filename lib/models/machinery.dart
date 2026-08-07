/// Модель техники/оборудования КФХ
class Machinery {
  final int? id;
  final String name;
  final String type; // 'tractor', 'combine', 'truck', 'implement'
  final String? registrationNumber;
  final double? fuelConsumptionPerHour;
  final bool isActive;
  final String? notes;

  Machinery({
    this.id,
    required this.name,
    this.type = 'tractor',
    this.registrationNumber,
    this.fuelConsumptionPerHour,
    this.isActive = true,
    this.notes,
  });

  factory Machinery.fromMap(Map<String, dynamic> map) {
    return Machinery(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'tractor',
      registrationNumber: map['registration_number'] as String?,
      fuelConsumptionPerHour: map['fuel_consumption_per_hour'] != null
          ? (map['fuel_consumption_per_hour'] as num).toDouble()
          : null,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'registration_number': registrationNumber,
      'fuel_consumption_per_hour': fuelConsumptionPerHour,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
    };
  }

  /// Название типа на русском
  String get typeName {
    switch (type) {
      case 'tractor':
        return 'Трактор';
      case 'combine':
        return 'Комбайн';
      case 'truck':
        return 'Грузовик';
      case 'implement':
        return 'Орудие/прицеп';
      default:
        return 'Прочее';
    }
  }

  Machinery copyWith({
    int? id,
    String? name,
    String? type,
    String? registrationNumber,
    double? fuelConsumptionPerHour,
    bool? isActive,
    String? notes,
  }) {
    return Machinery(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      fuelConsumptionPerHour:
          fuelConsumptionPerHour ?? this.fuelConsumptionPerHour,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'Machinery(id: $id, name: $name)';
}
