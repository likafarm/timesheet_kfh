/// Модель участка/поля КФХ
class WorkSite {
  final int? id;
  final String name;
  final double? areaHectares;
  final String? cropType;
  final String? notes;

  WorkSite({
    this.id,
    required this.name,
    this.areaHectares,
    this.cropType,
    this.notes,
  });

  factory WorkSite.fromMap(Map<String, dynamic> map) {
    return WorkSite(
      id: map['id'] as int?,
      name: map['name'] as String,
      areaHectares: map['area_hectares'] != null
          ? (map['area_hectares'] as num).toDouble()
          : null,
      cropType: map['crop_type'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'area_hectares': areaHectares,
      'crop_type': cropType,
      'notes': notes,
    };
  }

  WorkSite copyWith({
    int? id,
    String? name,
    double? areaHectares,
    String? cropType,
    String? notes,
  }) {
    return WorkSite(
      id: id ?? this.id,
      name: name ?? this.name,
      areaHectares: areaHectares ?? this.areaHectares,
      cropType: cropType ?? this.cropType,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'WorkSite(id: $id, name: $name)';
}
