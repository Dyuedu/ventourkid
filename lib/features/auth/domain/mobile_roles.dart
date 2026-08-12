/// Roles được phép đăng nhập trên ứng dụng mobile VentourKids.
const Set<String> kMobileAllowedRoles = {'PARENT', 'TEACHER', 'TOUR_GUIDE'};

/// Ưu tiên chọn home khi account có nhiều role (JWT `roles`).
const List<String> kMobileRolePriority = ['TOUR_GUIDE', 'TEACHER', 'PARENT'];

const Map<String, String> kRoleLabels = {
  'ADMIN': 'Quản trị viên',
  'SALES_STAFF': 'Nhân viên kinh doanh',
  'SCHOOL_REPRESENTATIVE': 'Đại diện nhà trường',
  'TEACHER': 'Giáo viên',
  'TOUR_MANAGER': 'Quản lý tour',
  'TOUR_OPERATOR_STAFF': 'Nhân viên điều hành tour',
  'PARENT': 'Phụ huynh',
  'TOUR_GUIDE': 'Hướng dẫn viên',
};

bool isMobileAllowedRole(String? role) {
  return role != null && kMobileAllowedRoles.contains(role);
}

bool hasMobileAllowedRole(Iterable<String> roles) {
  return roles.any(isMobileAllowedRole);
}

/// Chọn role mobile để điều hướng; nếu không có role được phép trả về role đầu (để báo lỗi).
String? resolveMobileSessionRole(Iterable<String> roles) {
  final list = roles
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty)
      .toList(growable: false);
  if (list.isEmpty) return null;
  for (final preferred in kMobileRolePriority) {
    if (list.contains(preferred)) return preferred;
  }
  return list.first;
}

/// Thông báo khi role không được dùng trên mobile (phải dùng cổng web).
String mobileRoleBlockedMessage(String? role) {
  final label = kRoleLabels[role];
  if (label == null || label.isEmpty) {
    return 'Tài khoản này không được phép đăng nhập trên ứng dụng di động. '
        'Vui lòng sử dụng cổng web VentourKids.';
  }
  return 'Tài khoản $label không được phép đăng nhập trên ứng dụng di động. '
      'Vui lòng sử dụng cổng web VentourKids.';
}

String homePathForMobileRole(String? role) {
  if (role == 'TEACHER') return '/teacher/dashboard';
  if (role == 'TOUR_GUIDE') return '/guide/dashboard';
  return '/parent/dashboard';
}
