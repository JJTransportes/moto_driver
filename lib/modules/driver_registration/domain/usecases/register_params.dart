class RegisterParams {
  final String fullName;
  final String cpf;
  final String rg;
  final String registration;
  final DateTime birthdate;
  final String email;
  final String initialPassword;
  final String? department;
  final String? phone;
  final String cnh;

  const RegisterParams({
    required this.fullName,
    required this.cpf,
    required this.rg,
    required this.registration,
    required this.birthdate,
    required this.email,
    required this.initialPassword,
    this.department,
    this.phone,
    required this.cnh,
  });
}
