import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/offline_attendance.dart';

class PreTripChecklistView extends StatelessWidget {
  const PreTripChecklistView({
    super.key,
    required this.checklist,
    required this.saving,
    required this.onChanged,
    required this.onSaveDraft,
    required this.onConfirm,
    this.confirmLabel = 'Xác nhận',
    this.confirmedConfirmLabel = 'Lưu & tiếp tục',
    this.onBack,
    this.backLabel = 'Quay lại',
  });

  final PreTripChecklist checklist;
  final bool saving;
  final void Function(String itemId, {bool? checked, String? note}) onChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final String confirmedConfirmLabel;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final requiredDone = checklist.requiredItemsDone;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fact_check_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Checklist trước chuyến đi',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            checklist.confirmed
                                ? 'Checklist đã xác nhận. Bạn vẫn có thể cập nhật tick hoặc ghi chú nếu cần.'
                                : 'Giáo viên cần xác nhận các mục bắt buộc trước khi điểm danh khuôn mặt.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!requiredDone) ...[
                  const SizedBox(height: 12),
                  _ChecklistMessageCard(
                    icon: Icons.warning_amber_rounded,
                    message:
                        'Còn mục bắt buộc chưa tick. Bạn có thể lưu nháp, nhưng giáo viên chưa thể điểm danh khuôn mặt.',
                    color: Colors.orange.shade800,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in checklist.items) ...[
          _PreTripChecklistTile(
            item: item,
            enabled: !saving,
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: saving ? null : onSaveDraft,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Lưu nháp'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: saving || !requiredDone ? null : onConfirm,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  checklist.confirmed ? confirmedConfirmLabel : confirmLabel,
                ),
              ),
            ),
          ],
        ),
        if (onBack != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: saving ? null : onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(backLabel),
          ),
        ],
      ],
    );
  }
}

class _PreTripChecklistTile extends StatelessWidget {
  const _PreTripChecklistTile({
    required this.item,
    required this.enabled,
    required this.onChanged,
  });

  final PreTripChecklistItem item;
  final bool enabled;
  final void Function(String itemId, {bool? checked, String? note}) onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: item.important && !item.checked
                ? Colors.orange.shade300
                : AppTheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.checked,
                  onChanged: enabled
                      ? (value) => onChanged(item.id, checked: value ?? false)
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (item.important) const _RequiredBadge(),
                          ],
                        ),
                        if (item.description?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!.trim(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey('pretrip-note-${item.id}'),
              enabled: enabled,
              initialValue: item.note ?? '',
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => onChanged(item.id, note: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Bắt buộc',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ChecklistMessageCard extends StatelessWidget {
  const _ChecklistMessageCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
