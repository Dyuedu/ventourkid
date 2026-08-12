class ProfileApiModel {
  const ProfileApiModel({
    required this.accountId,
    this.phoneNumber,
    this.email,
    this.fullName,
    this.roles = const [],
    this.status,
  });

  factory ProfileApiModel.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'];
    return ProfileApiModel(
      accountId: json['accountId']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      email: json['email']?.toString(),
      fullName: json['fullName']?.toString(),
      roles: rolesRaw is List
          ? rolesRaw.map((role) => role.toString()).toList(growable: false)
          : const [],
      status: json['status']?.toString(),
    );
  }

  final String accountId;
  final String? phoneNumber;
  final String? email;
  final String? fullName;
  final List<String> roles;
  final String? status;

  Map<String, dynamic> toUpdateJson({
    required bool includePhone,
  }) {
    return {
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (includePhone && phoneNumber != null) 'phoneNumber': phoneNumber,
    };
  }
}
