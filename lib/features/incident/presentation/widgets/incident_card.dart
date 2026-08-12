import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/incident_report.dart';
import '../widgets/incident_status_badge.dart';
import '../../domain/entities/incident_severity.dart';

/// Card widget for displaying an incident summary in the list.
class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, this.readOnly = false});

  final IncidentReport incident;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isCritical = incident.severity == IncidentSeverity.critical;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: () {
            final query = readOnly ? '?readOnly=true' : '';
            context.push('/incident/${incident.id}$query');
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isCritical
                    ? incident.severity.color.withValues(alpha: 0.5)
                    : AppTheme.neutral200,
                width: isCritical ? 1.5 : 1,
              ),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: title + severity indicator ──────────────────────
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: incident.severity.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incident.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            incident.incidentType.label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.onSurfaceVariant),
                          ),
                          if (incident.tourName != null &&
                              incident.tourName!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              incident.schoolName?.trim().isNotEmpty == true
                                  ? '${incident.tourName} · ${incident.schoolName}'
                                  : incident.tourName!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IncidentStatusBadge(status: incident.status),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Meta info ────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(incident.incidentTime),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppTheme.onSurfaceVariant),
                    ),
                    if (incident.locationText != null) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          incident.locationText!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (incident.affectedStudentIds.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outlined,
                        size: 14,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${incident.affectedStudentIds.length} HS',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
