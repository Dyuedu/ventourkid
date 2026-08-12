import 'package:flutter/material.dart';

/// Canonical checklist keys seeded on operation plan VEHICLE_INSPECTION items.
class VehicleInspectionCheckItem {
  const VehicleInspectionCheckItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

const List<VehicleInspectionCheckItem> kVehicleInspectionChecklist =
    <VehicleInspectionCheckItem>[
      VehicleInspectionCheckItem(
        key: 'camera',
        title: 'Camera giám sát',
        subtitle: 'Camera trên xe hoạt động rõ, góc nhìn đủ phạm vi cabin.',
        icon: Icons.videocam_outlined,
      ),
      VehicleInspectionCheckItem(
        key: 'antiForgetAlarm',
        title: 'Cảnh báo chống bỏ quên',
        subtitle: 'Thiết bị/còi báo chống bỏ quên trẻ hoạt động bình thường.',
        icon: Icons.notifications_active_outlined,
      ),
      VehicleInspectionCheckItem(
        key: 'seatBelts',
        title: 'Dây đai & ghế ngồi',
        subtitle: 'Dây an toàn, ghế và điểm neo đạt chuẩn, không hư hỏng.',
        icon: Icons.airline_seat_recline_extra_outlined,
      ),
      VehicleInspectionCheckItem(
        key: 'vehicleManager',
        title: 'Người quản lý xe',
        subtitle: 'Có người chịu trách nhiệm quản lý xe trong suốt chuyến.',
        icon: Icons.badge_outlined,
      ),
      VehicleInspectionCheckItem(
        key: 'safeCapacity',
        title: 'Sĩ số trong sức chứa',
        subtitle: 'Số học sinh trên xe không vượt sức chứa cho phép.',
        icon: Icons.groups_outlined,
      ),
    ];
