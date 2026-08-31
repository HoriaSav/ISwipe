import 'package:flutter/material.dart';

import '../../models/session_decision.dart';
import '../../providers/app_services.dart';

class SessionHistorySheet extends StatelessWidget {
  const SessionHistorySheet({
    super.key,
    required this.decisions,
    required this.onUndo,
  });

  final List<SessionDecision> decisions;
  final Future<void> Function(SessionDecision decision) onUndo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Session history',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (decisions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No decisions yet in this session.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: decisions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final decision = decisions[index];
                    return ListTile(
                      leading: Icon(_iconFor(decision.decision)),
                      title: Text(decision.title ?? 'Photo'),
                      subtitle: Text(_labelFor(decision.decision)),
                      trailing: TextButton(
                        onPressed: () async {
                          await onUndo(decision);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Undo'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(DecisionType type) {
    switch (type) {
      case DecisionType.keep:
        return Icons.check_circle_outline;
      case DecisionType.delete:
        return Icons.delete_outline;
      case DecisionType.later:
        return Icons.schedule_outlined;
      case DecisionType.favorite:
        return Icons.star_outline;
    }
  }

  String _labelFor(DecisionType type) {
    switch (type) {
      case DecisionType.keep:
        return 'Kept';
      case DecisionType.delete:
        return 'Queued delete';
      case DecisionType.later:
        return 'Later';
      case DecisionType.favorite:
        return 'Favorite';
    }
  }
}

Future<void> showSessionHistorySheet(
  BuildContext context, {
  required Future<void> Function(SessionDecision decision) onUndo,
}) async {
  final decisions = await context.reviewService.sessionDecisions();
  if (!context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SessionHistorySheet(
      decisions: decisions,
      onUndo: onUndo,
    ),
  );
}
