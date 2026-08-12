class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken']?.toString() ?? '';
    final refreshToken = json['refreshToken']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw const FormatException(
        'Authentication response contains empty tokens',
      );
    }
    return AuthTokensModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresIn: json['expiresIn'] is int
          ? json['expiresIn'] as int
          : int.tryParse(json['expiresIn']?.toString() ?? '') ?? 0,
    );
  }
}
