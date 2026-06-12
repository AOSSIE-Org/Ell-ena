import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums/dashboard_list_filter.dart';

part 'dashboard_state.freezed.dart';

/// Dashboard UI state managed by [DashboardController].
///
/// Chart range uses the same values as [DashboardScreen]: 0 = week, 1 = month.
/// Team display name is derived from profile/teams data — only [selectedTeamId]
/// is stored here.
@freezed
class DashboardState with _$DashboardState {
  const factory DashboardState({
    @Default(0) int timeRange,
    String? selectedTeamId,
    @Default(DashboardListFilter.all) DashboardListFilter listFilter,
  }) = _DashboardState;
}
