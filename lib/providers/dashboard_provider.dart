import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard chart range: 0 = week, 1 = month.
///
/// Mirrors [DashboardScreen]'s `_selectedTimeRange` for future migration.
final dashboardTimeRangeProvider = StateProvider<int>((ref) => 0);

/// Active workspace/team id for dashboard context.
/// Null until a team is selected or loaded from the profile.
/// Display name should be derived from [SupabaseService.getCurrentUserProfile]
final dashboardTeamIdProvider = StateProvider<String?>((ref) => null);

/// Optional filter applied to dashboard lists (tasks, tickets, meetings).
enum DashboardListFilter { all, tasks, tickets, meetings }

final dashboardListFilterProvider =
    StateProvider<DashboardListFilter>((ref) => DashboardListFilter.all);
