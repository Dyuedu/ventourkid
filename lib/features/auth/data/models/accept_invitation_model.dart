class AcceptInvitationModel {
  const AcceptInvitationModel({
    required this.challengeToken,
    required this.expiresInSeconds,
    required this.phoneNumberMasked,
    this.fullName,
  });

  final String challengeToken;
  final int expiresInSeconds;
  final String phoneNumberMasked;
  final String? fullName;

  factory AcceptInvitationModel.fromJson(Map<String, dynamic> json) {
    final challengeToken = json['challengeToken']?.toString() ?? '';
    if (challengeToken.isEmpty) {
      throw const FormatException('Invitation accept response missing challengeToken');
    }
    return AcceptInvitationModel(
      challengeToken: challengeToken,
      expiresInSeconds: json['expiresInSeconds'] is int
          ? json['expiresInSeconds'] as int
          : int.tryParse(json['expiresInSeconds']?.toString() ?? '') ?? 900,
      phoneNumberMasked: json['phoneNumberMasked']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
    );
  }
}
