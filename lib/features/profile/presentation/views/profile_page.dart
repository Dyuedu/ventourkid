import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../../auth/domain/mobile_roles.dart';
import '../../data/models/profile_api_model.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _role;
  String? _accountId;
  bool _loading = true;
  bool _saving = false;
  String? _successMessage;
  String? _errorMessage;

  bool get _isParent => _role == 'PARENT';
  bool get _isTeacher => _role == 'TEACHER';
  bool get _isTourGuide => _role == 'TOUR_GUIDE';
  bool get _canEditPhone => !_isParent;
  bool get _canEditEmail => !_isTeacher && !_isTourGuide;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final storage = ref.read(tokenStorageProvider);
      final profileDataSource = ref.read(profileRemoteDataSourceProvider);
      final results = await Future.wait([
        storage.getUserRole(),
        storage.getAccountId(),
        profileDataSource.getOwnProfile(),
      ]);

      if (!mounted) return;

      final role = results[0] as String?;
      final accountId = results[1] as String?;
      final profile = results[2] as ProfileApiModel;

      _role = role;
      _accountId = accountId;
      _fullNameController.text = profile.fullName?.trim() ?? '';
      _emailController.text = profile.email?.trim() ?? '';
      _phoneController.text = profile.phoneNumber?.trim() ?? '';
    } catch (_) {
      if (!mounted) return;
      _errorMessage = 'Không thể tải hồ sơ. Vui lòng thử lại.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập họ và tên.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final profileDataSource = ref.read(profileRemoteDataSourceProvider);
      final updated = await profileDataSource.updateOwnProfile(
        fullName: fullName,
        email: _canEditEmail && _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        phoneNumber: _canEditPhone ? _phoneController.text.trim() : null,
        includeEmail: _canEditEmail,
        includePhone: _canEditPhone,
      );

      if (!mounted) return;

      _fullNameController.text = updated.fullName?.trim() ?? fullName;
      _emailController.text = updated.email?.trim() ?? '';
      _phoneController.text = updated.phoneNumber?.trim() ?? '';

      setState(() {
        _successMessage = 'Đã cập nhật hồ sơ thành công.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể cập nhật hồ sơ. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _logout() async {
    final success = await ref.read(authViewModelProvider.notifier).logout();
    if (mounted && success) {
      context.go('/login');
    }
  }

  String get _roleLabel {
    final role = _role;
    if (role == null || role.isEmpty) return 'Chưa xác định';
    return kRoleLabels[role] ?? role;
  }

  String get _displayName {
    final name = _fullNameController.text.trim();
    if (name.isNotEmpty) return name;
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) return phone;
    return 'VentourKid User';
  }

  String get _initials {
    final name = _fullNameController.text.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name.length >= 2
          ? name.substring(0, 2).toUpperCase()
          : name[0].toUpperCase();
    }
    final phone = _phoneController.text.trim();
    if (phone.length >= 2) {
      return phone.substring(phone.length - 2);
    }
    final role = _role;
    if (role == 'PARENT') return 'PH';
    if (role == 'TEACHER') return 'GV';
    if (role == 'TOUR_GUIDE') return 'HD';
    return 'VK';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final fallback = homePathForMobileRole(_role);
    final textTheme = Theme.of(context).textTheme;

    return ParentPageScaffold(
      title: 'Hồ sơ',
      leading: buildAppBackLeading(context, fallbackRoute: fallback),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                ParentCard(
                  emphasized: true,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          _initials,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ParentStatusChip(
                              label: _roleLabel,
                              color: AppTheme.primary,
                              icon: Icons.badge_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const ParentSectionHeader(
                  title: 'Thông tin tài khoản',
                  subtitle: 'Cập nhật thông tin liên hệ của bạn.',
                ),
                const SizedBox(height: 12),
                if (_successMessage != null) ...[
                  ParentBanner(
                    text: _successMessage!,
                    tone: ParentBannerTone.success,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_errorMessage != null) ...[
                  ParentBanner(
                    text: _errorMessage!,
                    tone: ParentBannerTone.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                ],
                ParentCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        enabled: _canEditEmail,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: const OutlineInputBorder(),
                          helperText: _isTeacher
                              ? 'Email được gán khi kích hoạt tài khoản. Nếu cần thay đổi, liên hệ nhà trường.'
                              : _isTourGuide
                                  ? 'Email được gán khi tạo tài khoản. Nếu cần thay đổi, liên hệ điều phối tour.'
                                  : null,
                          suffixIcon: !_canEditEmail
                              ? const Icon(Icons.lock_outline)
                              : null,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        enabled: _canEditPhone,
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại',
                          border: const OutlineInputBorder(),
                          helperText: _isParent
                              ? 'SĐT phụ huynh được lấy từ danh sách học sinh. Nếu cần thay đổi, liên hệ nhà trường/điều phối tour.'
                              : null,
                          suffixIcon: _isParent
                              ? const Icon(Icons.lock_outline)
                              : null,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      if (_accountId != null && _accountId!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Mã tài khoản',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: AppTheme.surfaceLow,
                            suffixIcon: const Icon(Icons.lock_outline),
                          ),
                          child: Text(
                            _accountId!,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: authState.isLoggingOut ? null : _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    authState.isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
                  ),
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ParentBanner(
                    text: authState.errorMessage!,
                    tone: ParentBannerTone.danger,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
              ],
            ),
    );
  }
}
