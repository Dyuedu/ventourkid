import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../shared/widgets/app_back_leading.dart';
import '../../../../shared/widgets/parent_ui.dart';
import '../../domain/entities/parent_dashboard.dart';
import '../utils/parent_quick_action_ui.dart';

/// Full list of parent quick actions — opened from "Xem thêm".
class ParentMoreActionsPage extends StatelessWidget {
  const ParentMoreActionsPage({
    required this.actions,
    required this.onPressed,
    super.key,
  });

  final List<ParentQuickAction> actions;
  final ValueChanged<ParentQuickAction> onPressed;

  @override
  Widget build(BuildContext context) {
    return ParentPageScaffold(
      title: 'Tất cả thao tác',
      leading: buildAppBackLeading(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const ParentSectionHeader(
            title: 'Truy cập đầy đủ',
            subtitle: 'Chọn thao tác để mở nhanh từ khu vực phụ huynh.',
          ),
          const SizedBox(height: 16),
          ...actions.map(
            (action) {
              final accent = parentQuickActionAccent(action.kind);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ParentListTileCard(
                  title: action.label,
                  subtitle: parentQuickActionSubtitle(action.kind),
                  leading: ParentIconWell(
                    icon: parentQuickActionIcon(action.kind),
                    backgroundColor: accent.withValues(alpha: 0.12),
                    iconColor: accent,
                  ),
                  trailing: Icon(
                    Iconsax.arrow_right_3,
                    color: accent,
                    size: 20,
                  ),
                  onTap: () => onPressed(action),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
