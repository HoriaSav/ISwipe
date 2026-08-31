import 'package:intl/intl.dart';

import 'database_service.dart';

enum AnalyticsPeriod { day, month, year }

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final DatabaseService _db = DatabaseService.instance;

  Future<int> totalDeletions() => _db.totalDeletions();

  Future<int> totalBytesRecovered() => _db.totalBytesRecovered();

  Future<int> deletionsToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _countSince(start);
  }

  Future<int> bytesRecoveredToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _db.bytesRecoveredSince(start);
  }

  Future<int> deletionsThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return _countSince(start);
  }

  Future<int> bytesRecoveredThisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return _db.bytesRecoveredSince(start);
  }

  Future<int> deletionsThisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year);
    return _countSince(start);
  }

  Future<int> bytesRecoveredThisYear() {
    final now = DateTime.now();
    final start = DateTime(now.year);
    return _db.bytesRecoveredSince(start);
  }

  Future<int> _countSince(DateTime since) async {
    final result = await _db.deletionCountsSince(since);
    return result['count'] ?? 0;
  }

  Future<List<AnalyticsBucket>> bucketsFor(AnalyticsPeriod period) async {
    final since = _sinceForPeriod(period);
    final List<Map<String, dynamic>> rows;

    switch (period) {
      case AnalyticsPeriod.day:
        rows = await _db.deletionsGroupedByDay(since);
      case AnalyticsPeriod.month:
        rows = await _db.deletionsGroupedByMonth(since);
      case AnalyticsPeriod.year:
        rows = await _db.deletionsGroupedByYear();
    }

    return rows
        .map(
          (row) => AnalyticsBucket(
            label: _formatLabel(
              period,
              (row['day'] ?? row['month'] ?? row['year']) as String,
            ),
            count: row['count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  DateTime _sinceForPeriod(AnalyticsPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case AnalyticsPeriod.day:
        return now.subtract(const Duration(days: 30));
      case AnalyticsPeriod.month:
        return DateTime(now.year - 1, now.month);
      case AnalyticsPeriod.year:
        return DateTime(now.year - 5);
    }
  }

  String _formatLabel(AnalyticsPeriod period, String raw) {
    switch (period) {
      case AnalyticsPeriod.day:
        final date = DateTime.parse(raw);
        return DateFormat.MMMd().format(date);
      case AnalyticsPeriod.month:
        final parts = raw.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat.yMMM().format(date);
      case AnalyticsPeriod.year:
        return raw;
    }
  }
}

class AnalyticsBucket {
  const AnalyticsBucket({required this.label, required this.count});

  final String label;
  final int count;
}
