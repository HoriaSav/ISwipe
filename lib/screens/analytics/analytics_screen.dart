import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/deletion_events.dart';
import '../../services/analytics_service.dart';
import '../../utils/format_bytes.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen> {
  final _analytics = AnalyticsService.instance;

  int _today = 0;
  int _month = 0;
  int _year = 0;
  int _total = 0;
  int _bytesToday = 0;
  int _bytesMonth = 0;
  int _bytesYear = 0;
  int _bytesTotal = 0;
  AnalyticsPeriod _period = AnalyticsPeriod.day;
  List<AnalyticsBucket> _buckets = [];
  bool _loading = true;
  DeletionEvents? _deletionEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deletionEvents = context.read<DeletionEvents>();
      _deletionEvents!.addListener(_onDeletionChanged);
      reload();
    });
  }

  @override
  void dispose() {
    _deletionEvents?.removeListener(_onDeletionChanged);
    super.dispose();
  }

  void _onDeletionChanged() {
    reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final results = await Future.wait([
      _analytics.deletionsToday(),
      _analytics.deletionsThisMonth(),
      _analytics.deletionsThisYear(),
      _analytics.totalDeletions(),
      _analytics.bucketsFor(_period),
      _analytics.bytesRecoveredToday(),
      _analytics.bytesRecoveredThisMonth(),
      _analytics.bytesRecoveredThisYear(),
      _analytics.totalBytesRecovered(),
    ]);

    if (!mounted) return;
    setState(() {
      _today = results[0] as int;
      _month = results[1] as int;
      _year = results[2] as int;
      _total = results[3] as int;
      _buckets = results[4] as List<AnalyticsBucket>;
      _bytesToday = results[5] as int;
      _bytesMonth = results[6] as int;
      _bytesYear = results[7] as int;
      _bytesTotal = results[8] as int;
      _loading = false;
    });
  }

  Future<void> _changePeriod(AnalyticsPeriod period) async {
    setState(() {
      _period = period;
      _loading = true;
    });
    final buckets = await _analytics.bucketsFor(period);
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _buckets.isEmpty && _total == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _StatCardGrid(
            cards: [
              _StatCard(label: 'Today', value: _today),
              _StatCard(label: 'This month', value: _month),
              _StatCard(label: 'This year', value: _year),
              _StatCard(label: 'All time', value: _total),
            ],
          ),
          const SizedBox(height: 12),
          _StatCardGrid(
            cards: [
              _StatCard(
                label: 'Recovered today',
                valueLabel: formatBytes(_bytesToday),
              ),
              _StatCard(
                label: 'Recovered this month',
                valueLabel: formatBytes(_bytesMonth),
              ),
              _StatCard(
                label: 'Recovered this year',
                valueLabel: formatBytes(_bytesYear),
              ),
              _StatCard(
                label: 'Total recovered',
                valueLabel: formatBytes(_bytesTotal),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SegmentedButton<AnalyticsPeriod>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(value: AnalyticsPeriod.day, label: Text('Days')),
              ButtonSegment(value: AnalyticsPeriod.month, label: Text('Months')),
              ButtonSegment(value: AnalyticsPeriod.year, label: Text('Years')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) {
              _changePeriod(selection.first);
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_buckets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No data for this period.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            ..._buckets.map(
              (bucket) => _BucketRow(bucket: bucket, maxCount: _maxCount()),
            ),
        ],
      ),
    );
  }

  int _maxCount() {
    if (_buckets.isEmpty) return 1;
    return _buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);
  }
}

class _StatCardGrid extends StatelessWidget {
  const _StatCardGrid({required this.cards});

  final List<_StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < cards.length ? 12 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < cards.length
                        ? cards[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    this.value,
    this.valueLabel,
  });

  final String label;
  final int? value;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final displayValue = valueLabel ?? '$value';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayValue,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket, required this.maxCount});

  final AnalyticsBucket bucket;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : bucket.count / maxCount;
    final primary = Theme.of(context).colorScheme.primary;
    final countDigits = maxCount.toString().length;
    final countColumnWidth = (countDigits * 10.0 + 12).clamp(48.0, 88.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              bucket.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: countColumnWidth,
            child: Text(
              '${bucket.count}',
              textAlign: TextAlign.end,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
