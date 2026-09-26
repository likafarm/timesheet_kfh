/// Модель настроек КФХ
class CompanySettings {
  final String? id;
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

  CompanySettings copyWith({
    String? id,
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
