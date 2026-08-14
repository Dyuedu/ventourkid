import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/parent_dashboard.dart';

/// Icons aligned with guide dashboard (Iconsax + shared accent palette).
IconData parentQuickActionIcon(ParentQuickActionKind kind) {
  return switch (kind) {
    ParentQuickActionKind.linkChild => Iconsax.link_2,
    ParentQuickActionKind.childProfile => Iconsax.profile_2user,
    ParentQuickActionKind.documents => Iconsax.document_text,
    ParentQuickActionKind.authorizations => Iconsax.shield_tick,
    ParentQuickActionKind.tripInfo => Iconsax.map,
    ParentQuickActionKind.incidents => Iconsax.warning_2,
    ParentQuickActionKind.mediaUpload => Iconsax.gallery_add,
    ParentQuickActionKind.livestream => Iconsax.video_play,
    ParentQuickActionKind.postTourHistory => Iconsax.clock,
    ParentQuickActionKind.media => Iconsax.gallery,
    ParentQuickActionKind.newsfeed => Iconsax.activity,
    ParentQuickActionKind.trackingMap => Iconsax.location,
    ParentQuickActionKind.aiAssistant => Iconsax.message_question,
    ParentQuickActionKind.faceEnroll => Iconsax.scan,
  };
}

/// Accent colors matching guide primary action tiles.
Color parentQuickActionAccent(ParentQuickActionKind kind) {
  return switch (kind) {
    ParentQuickActionKind.linkChild => AppTheme.primary,
    ParentQuickActionKind.childProfile => AppTheme.primary,
    ParentQuickActionKind.documents => const Color(0xFF1E40AF),
    ParentQuickActionKind.authorizations => const Color(0xFF0F766E),
    ParentQuickActionKind.tripInfo => AppTheme.primary,
    ParentQuickActionKind.incidents => const Color(0xFFEA580C),
    ParentQuickActionKind.mediaUpload => const Color(0xFF1D4ED8),
    ParentQuickActionKind.livestream => AppTheme.accentRed,
    ParentQuickActionKind.postTourHistory => AppTheme.neutral700,
    ParentQuickActionKind.media => const Color(0xFF1D4ED8),
    ParentQuickActionKind.newsfeed => AppTheme.cta,
    ParentQuickActionKind.trackingMap => const Color(0xFF0F766E),
    ParentQuickActionKind.aiAssistant => const Color(0xFF1E40AF),
    ParentQuickActionKind.faceEnroll => AppTheme.primary,
  };
}

String parentQuickActionSubtitle(ParentQuickActionKind kind) {
  return switch (kind) {
    ParentQuickActionKind.linkChild => 'Liên kết học sinh với tài khoản',
    ParentQuickActionKind.childProfile => 'Xem thông tin học sinh đã liên kết',
    ParentQuickActionKind.documents => 'Giấy tờ tham gia chuyến đi',
    ParentQuickActionKind.authorizations => 'Quản lý đồng thuận dữ liệu',
    ParentQuickActionKind.tripInfo => 'Lịch trình và checkpoint hiện tại',
    ParentQuickActionKind.incidents => 'Xem hoặc gửi báo cáo sự cố',
    ParentQuickActionKind.mediaUpload => 'Gửi ảnh/video từ phụ huynh',
    ParentQuickActionKind.livestream => 'Xem livestream tour',
    ParentQuickActionKind.postTourHistory => 'Lịch sử sau khi tour đóng',
    ParentQuickActionKind.media => 'Timeline ảnh và video của con',
    ParentQuickActionKind.newsfeed => 'Bảng tin hoạt động chuyến đi',
    ParentQuickActionKind.trackingMap => 'Xe đang đi đâu · bản đồ theo dõi',
    ParentQuickActionKind.aiAssistant => 'Hỏi đáp với trợ lý VentourKid',
    ParentQuickActionKind.faceEnroll => 'Đăng ký khuôn mặt điểm danh',
  };
}

String parentQuickActionDefaultLabel(ParentQuickActionKind kind) {
  return switch (kind) {
    ParentQuickActionKind.linkChild => 'Liên kết con',
    ParentQuickActionKind.childProfile => 'Hồ sơ con',
    ParentQuickActionKind.documents => 'Giấy tờ',
    ParentQuickActionKind.authorizations => 'Ủy quyền',
    ParentQuickActionKind.tripInfo => 'Chuyến đi',
    ParentQuickActionKind.incidents => 'Sự cố',
    ParentQuickActionKind.mediaUpload => 'Gửi ảnh/video',
    ParentQuickActionKind.livestream => 'Livestream',
    ParentQuickActionKind.postTourHistory => 'Lịch sử',
    ParentQuickActionKind.media => 'Ảnh & video',
    ParentQuickActionKind.newsfeed => 'Bảng tin',
    ParentQuickActionKind.trackingMap => 'Theo dõi',
    ParentQuickActionKind.aiAssistant => 'Trợ lý AI',
    ParentQuickActionKind.faceEnroll => 'Khuôn mặt',
  };
}

/// Primary tiles shown on the dashboard (progressive disclosure).
const kParentPinnedQuickActionKinds = <ParentQuickActionKind>[
  ParentQuickActionKind.trackingMap,
  ParentQuickActionKind.media,
  ParentQuickActionKind.newsfeed,
  ParentQuickActionKind.incidents,
  ParentQuickActionKind.linkChild,
];

List<ParentQuickAction> parentAllQuickActions(
  List<ParentQuickAction> source,
) {
  final byKind = <ParentQuickActionKind, ParentQuickAction>{
    for (final action in source) action.kind: action,
  };

  ParentQuickAction resolve(ParentQuickActionKind kind) {
    return byKind[kind] ??
        ParentQuickAction(
          kind: kind,
          label: parentQuickActionDefaultLabel(kind),
        );
  }

  final ordered = <ParentQuickAction>[];
  final seen = <ParentQuickActionKind>{};

  void add(ParentQuickActionKind kind) {
    if (!seen.add(kind)) return;
    ordered.add(resolve(kind));
  }

  for (final kind in kParentPinnedQuickActionKinds) {
    add(kind);
  }
  for (final action in source) {
    add(action.kind);
  }
  for (final kind in ParentQuickActionKind.values) {
    add(kind);
  }
  return ordered;
}

List<ParentQuickAction> parentPinnedQuickActions(
  List<ParentQuickAction> source,
) {
  final all = parentAllQuickActions(source);
  return all
      .where((action) => kParentPinnedQuickActionKinds.contains(action.kind))
      .toList(growable: false);
}

List<ParentQuickAction> parentMoreQuickActions(
  List<ParentQuickAction> source,
) {
  final pinned = kParentPinnedQuickActionKinds.toSet();
  return parentAllQuickActions(source)
      .where((action) => !pinned.contains(action.kind))
      .toList(growable: false);
}
