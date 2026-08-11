class UserModel {
  final String mobileNumber;
  final String username;
  final String password;
  final DateTime registeredAt;

  UserModel({
    required this.mobileNumber,
    required this.username,
    required this.password,
    required this.registeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'mobileNumber': mobileNumber,
      'username': username,
      'password': password,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map) {
    return UserModel(
      mobileNumber: map['mobileNumber']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      registeredAt: map['registeredAt'] != null
          ? DateTime.tryParse(map['registeredAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
