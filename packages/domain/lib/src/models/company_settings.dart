/// Модель настроек КФХ
class CompanySettings {
  final int? id;
  final String companyName;
  final String? directorName;
  final String? inn;
  final String? ogrn;
  final String? bankAccount;
  final String? bankName;
  final String? legalAddress;
  final String? phone;
  final double defaultWorkDayHours;
  final double overtimeMultiplier;
  final double nightShiftMultiplier;

  CompanySettings({
    this.id,
    required this.companyName,
    this.directorName,
    this.inn,
    this.ogrn,
    this.bankAccount,
    this.bankName,
    this.legalAddress,
    this.phone,
    this.defaultWorkDayHours = 8.0,
    this.overtimeMultiplier = 1.5,
    this.nightShiftMultiplier = 1.2,
  });

  factory CompanySettings.fromMap(Map<String, dynamic> map) {
    return CompanySettings(
      id: map['id'] as int?,
      companyName: map['company_name'] as String,
      directorName: map['director_name'] as String?,
      inn: map['inn'] as String?,
      ogrn: map['ogrn'] as String?,
      bankAccount: map['bank_account'] as String?,
      bankName: map['bank_name'] as String?,
      legalAddress: map['legal_address'] as String?,
      phone: map['phone'] as String?,
      defaultWorkDayHours:
          (map['default_work_day_hours'] as num?)?.toDouble() ?? 8.0,
      overtimeMultiplier:
          (map['overtime_multiplier'] as num?)?.toDouble() ?? 1.5,
      nightShiftMultiplier:
          (map['night_shift_multiplier'] as num?)?.toDouble() ?? 1.2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_name': companyName,
      'director_name': directorName,
      'inn': inn,
      'ogrn': ogrn,
      'bank_account': bankAccount,
      'bank_name': bankName,
      'legal_address': legalAddress,
      'phone': phone,
      'default_work_day_hours': defaultWorkDayHours,
      'overtime_multiplier': overtimeMultiplier,
      'night_shift_multiplier': nightShiftMultiplier,
    };
  }

  CompanySettings copyWith({
    int? id,
    String? companyName,
    String? directorName,
    String? inn,
    String? ogrn,
    String? bankAccount,
    String? bankName,
    String? legalAddress,
    String? phone,
    double? defaultWorkDayHours,
    double? overtimeMultiplier,
    double? nightShiftMultiplier,
  }) {
    return CompanySettings(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      directorName: directorName ?? this.directorName,
      inn: inn ?? this.inn,
      ogrn: ogrn ?? this.ogrn,
      bankAccount: bankAccount ?? this.bankAccount,
      bankName: bankName ?? this.bankName,
      legalAddress: legalAddress ?? this.legalAddress,
      phone: phone ?? this.phone,
      defaultWorkDayHours: defaultWorkDayHours ?? this.defaultWorkDayHours,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      nightShiftMultiplier: nightShiftMultiplier ?? this.nightShiftMultiplier,
    );
  }

  @override
  String toString() => 'CompanySettings(id: $id, name: $companyName)';
}
