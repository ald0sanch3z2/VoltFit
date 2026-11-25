
class AppUser {
  final String name;
  final String email;
  final String sex;
  final String salt;
  final String passwordHash;
  final bool biometricEnabled;

  const AppUser({
    required this.name,
    required this.email,
    required this.sex,
    required this.salt,
    required this.passwordHash,
    this.biometricEnabled = false,
  });

  AppUser copyWith({bool? biometricEnabled}) {
    return AppUser(
      name: name,
      email: email,
      sex: sex,
      salt: salt,
      passwordHash: passwordHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'sex': sex,
    'salt': salt,
    'passwordHash': passwordHash,
    'biometricEnabled': biometricEnabled,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      name: json['name'] as String,
      email: json['email'] as String,
      sex: json['sex'] as String,
      salt: json['salt'] as String,
      passwordHash: json['passwordHash'] as String,
      biometricEnabled: json['biometricEnabled'] == true,
    );
  }
}
