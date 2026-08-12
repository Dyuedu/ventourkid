import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';

/// Step 1 of invitation activation: validate SMS token and open set-password.
class AcceptInvitationPage extends ConsumerStatefulWidget {
  const AcceptInvitationPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<AcceptInvitationPage> createState() =>
      _AcceptInvitationPageState();
}

class _AcceptInvitationPageState extends ConsumerState<AcceptInvitationPage> {
  bool _loading = true;
  String? _errorCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _accept());
  }

  Future<void> _accept() async {
    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _errorCode = 'AUTH_INVITE_INVALID';
        _errorMessage = 'Liên kết kích hoạt không hợp lệ.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorCode = null;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authRepositoryProvider)
          .acceptInvitation(token: token);
      if (!mounted) return;
      context.go(
        '/invite/set-password',
        extra: {
          'challengeToken': result.challengeToken,
          'phoneNumberMasked': result.phoneNumberMasked,
          'fullName': result.fullName,
          'expiresInSeconds': result.expiresInSeconds,
        },
      );
    } on Object catch (error) {
      if (!mounted) return;
      final api = ApiException.maybeFrom(error);
      final details = api?.details;
      String? code;
      if (details is Map<String, dynamic>) {
        code = details['code']?.toString() ?? details['errorCode']?.toString();
      }
      setState(() {
        _loading = false;
        _errorCode = code;
        _errorMessage = error is AppFailure
            ? error.message
            : (api?.message ?? 'Không thể kích hoạt liên kết. Vui lòng thử lại.');
      });
    }
  }

  String get _friendlyTitle {
    switch (_errorCode) {
      case 'AUTH_INVITE_EXPIRED':
        return 'Liên kết đã hết hạn';
      case 'AUTH_INVITE_USED':
        return 'Liên kết đã được sử dụng';
      case 'AUTH_INVITE_REVOKED':
        return 'Liên kết đã bị thu hồi';
      default:
        return 'Không thể mở lời mời';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthMediaScaffold(
      child: AuthViewport(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHero(subtitle: 'Kích hoạt tài khoản'),
              const Spacer(),
              AuthVerificationCard(
                child: _loading
                    ? Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Đang xác thực lời mời…',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.neutral950,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _friendlyTitle,
                            style: textTheme.titleLarge?.copyWith(
                              color: AppTheme.neutral950,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ??
                                'Vui lòng liên hệ nhà trường để được gửi lại lời mời.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AuthActionButton(
                            label: 'Thử lại',
                            onPressed: _accept,
                          ),
                          const SizedBox(height: 8),
                          AuthActionButton(
                            label: 'Về đăng nhập',
                            onPressed: () => context.go('/login'),
                            filled: false,
                          ),
                        ],
                      ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
