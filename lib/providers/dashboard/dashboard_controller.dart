import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/dashboard_state.dart';
import 'models/enums/dashboard_list_filter.dart';

part 'dashboard_controller.g.dart';

/// Single controller for dashboard-related Riverpod state.
@Riverpod(keepAlive: true)
class DashboardController extends _$DashboardController {
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
