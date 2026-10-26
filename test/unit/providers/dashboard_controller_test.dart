import 'package:ell_ena/providers/dashboard/dashboard_controller.dart';
import 'package:ell_ena/providers/dashboard/models/enums/dashboard_list_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('starts on the week range, no team, and the all filter', () {
    final state = container.read(dashboardControllerProvider);

    // Loading lives on DashboardScreen, not in this controller.
    expect(state.timeRange, 0);
    expect(state.selectedTeamId, isNull);
    expect(state.listFilter, DashboardListFilter.all);
  });

  test('setFilter switches between tasks and meetings', () {
    final notifier = container.read(dashboardControllerProvider.notifier);

    notifier.setFilter(DashboardListFilter.tasks);
    expect(
      container.read(dashboardControllerProvider).listFilter,
      DashboardListFilter.tasks,
    );

    notifier.setFilter(DashboardListFilter.meetings);
    expect(
      container.read(dashboardControllerProvider).listFilter,
      DashboardListFilter.meetings,
    );
  });

  test('team selection, chart range, and reset return to defaults', () {
    final notifier = container.read(dashboardControllerProvider.notifier);

    notifier.setSelectedTeam('team-1');
    notifier.setTimeRange(1);
    notifier.setFilter(DashboardListFilter.tickets);

    var state = container.read(dashboardControllerProvider);
    expect(state.selectedTeamId, 'team-1');
    expect(state.timeRange, 1);
    expect(state.listFilter, DashboardListFilter.tickets);

    notifier.clearSelectedTeam();
    expect(container.read(dashboardControllerProvider).selectedTeamId, isNull);

    notifier.reset();
    state = container.read(dashboardControllerProvider);
    expect(state.timeRange, 0);
    expect(state.selectedTeamId, isNull);
    expect(state.listFilter, DashboardListFilter.all);
  });
}
