import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_state.dart';

/// Single controller for dashboard-related Riverpod state.
class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashboardState();

  /// Sets chart range: 0 = week, 1 = month.
  void setTimeRange(int timeRange) {
    state = state.copyWith(timeRange: timeRange);
  }

  /// Sets the active workspace/team id.
  void setSelectedTeam(String? teamId) {
    state = state.copyWith(selectedTeamId: teamId);
  }

  /// Clears the selected team.
  void clearSelectedTeam() {
    setSelectedTeam(null);
  }

  /// Sets the dashboard list filter.
  void setFilter(DashboardListFilter filter) {
    state = state.copyWith(listFilter: filter);
  }

  /// Resets dashboard state to defaults.
  void reset() {
    state = const DashboardState();
  }
}

/// Unified dashboard state provider.
final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
