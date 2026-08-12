import '../../../attendance/domain/entities/offline_attendance.dart';

sealed class GuideItineraryTreeNode {
  const GuideItineraryTreeNode();
}

class GuideItineraryTerminalNode extends GuideItineraryTreeNode {
  const GuideItineraryTerminalNode({
    required this.checkpoint,
    required this.afterItems,
  });

  final GuideTourItineraryCheckpoint checkpoint;
  final List<GuideTourItineraryItem> afterItems;
}

class GuideItineraryDestinationNode extends GuideItineraryTreeNode {
  const GuideItineraryDestinationNode({
    required this.destinationName,
    required this.activities,
  });

  final String destinationName;
  final List<GuideItineraryActivityNode> activities;
}

class GuideItineraryActivityNode {
  const GuideItineraryActivityNode({
    required this.key,
    required this.activityId,
    required this.activityName,
    required this.checkpoints,
  });

  final String key;
  final String? activityId;
  final String activityName;
  final List<GuideTourItineraryCheckpoint> checkpoints;
}

List<GuideTourItineraryItem> itemsForAnchor(
  String checkpointId,
  List<GuideTourItineraryItem> planItems,
) {
  final seen = <String>{};
  final items = planItems
      .where((item) => item.checkpointId == checkpointId)
      .toList()
    ..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.title.compareTo(b.title);
    });

  return items.where((item) {
    if (item.itemKind.toUpperCase() == 'ATTENDANCE' && item.required) {
      // BOARDING và ALIGHTING là hai hoạt động khác nhau tại cùng checkpoint.
      final leg = (item.legType ?? 'BOARDING').trim().toUpperCase();
      final key = 'att:${item.checkpointId}:$leg';
      if (seen.contains(key)) return false;
      seen.add(key);
    }
    return true;
  }).toList();
}

List<GuideTourItineraryItem> livestreamForActivity(
  String? activityId,
  List<String> checkpointIds,
  List<GuideTourItineraryItem> planItems,
) {
  return planItems
      .where(
        (item) =>
            item.itemKind.toUpperCase() == 'LIVESTREAM' &&
            (item.activityId == activityId ||
                (item.activityId == null &&
                    item.checkpointId != null &&
                    checkpointIds.contains(item.checkpointId))),
      )
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

List<GuideItineraryTreeNode> buildGuideItineraryTree(
  GuideTourItinerary itinerary,
) {
  final sorted = [...itinerary.checkpoints]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final nodes = <GuideItineraryTreeNode>[];

  _MutableDestination? currentDest;

  void flushDest() {
    if (currentDest != null) {
      nodes.add(
        GuideItineraryDestinationNode(
          destinationName: currentDest!.destinationName,
          activities: currentDest!.activities
              .map((activity) => activity.toNode())
              .toList(),
        ),
      );
      currentDest = null;
    }
  }

  for (final checkpoint in sorted) {
    final kind = checkpoint.kind.toUpperCase();
    if (kind == 'PICKUP' || kind == 'DROPOFF') {
      flushDest();
      nodes.add(
        GuideItineraryTerminalNode(
          checkpoint: checkpoint,
          afterItems: itemsForAnchor(checkpoint.id, itinerary.items),
        ),
      );
      continue;
    }

    final destName = (checkpoint.destinationName ?? '').trim().isEmpty
        ? 'Điểm đến chưa gắn'
        : checkpoint.destinationName!.trim();

    if (currentDest == null || currentDest!.destinationName != destName) {
      flushDest();
      currentDest = _MutableDestination(destinationName: destName);
    }

    final activityKey = checkpoint.activityId?.isNotEmpty == true
        ? checkpoint.activityId!
        : 'name:${checkpoint.activityName ?? checkpoint.name}';

    final existing = currentDest!.activities
        .where((activity) => activity.key == activityKey)
        .firstOrNull;
    if (existing == null) {
      currentDest!.activities.add(
        _MutableActivity(
          key: activityKey,
          activityId: checkpoint.activityId,
          activityName: checkpoint.activityName ?? checkpoint.name,
          checkpoints: [checkpoint],
        ),
      );
    } else {
      existing.checkpoints.add(checkpoint);
    }
  }

  flushDest();
  return nodes;
}

class _MutableDestination {
  _MutableDestination({required this.destinationName});

  final String destinationName;
  final List<_MutableActivity> activities = [];
}

class _MutableActivity {
  _MutableActivity({
    required this.key,
    required this.activityId,
    required this.activityName,
    required this.checkpoints,
  });

  final String key;
  final String? activityId;
  final String activityName;
  final List<GuideTourItineraryCheckpoint> checkpoints;

  GuideItineraryActivityNode toNode() {
    return GuideItineraryActivityNode(
      key: key,
      activityId: activityId,
      activityName: activityName,
      checkpoints: List.unmodifiable(checkpoints),
    );
  }
}
