import 'package:flutter/material.dart';
import '../tasks/task_screen.dart';
import '../tickets/ticket_screen.dart';
import '../../l10n/app_localizations.dart';
import '../meetings/meeting_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  final int initialTabIndex;
  final ValueChanged<int>? onTabSelected;

  const WorkspaceScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onTabSelected,
  });

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        _tabController.index != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 2));
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
      return;
    }

    // Route-driven moves (see didUpdateWidget) are already in the route.
    if (_tabController.index == widget.initialTabIndex.clamp(0, 2)) return;
    widget.onTabSelected?.call(_tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + statusBarHeight),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: true,
            bottom: false,
            left: false,
            right: false,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.green,
              labelColor: Colors.green,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              tabs: [
                Tab(icon: const Icon(Icons.task), text: l10n.tasks),
                Tab(
                  icon: const Icon(Icons.confirmation_number),
                  text: l10n.tickets,
                ),
                Tab(icon: const Icon(Icons.group), text: l10n.meetings),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAlive(child: TaskScreen(key: TaskScreen.globalKey)),
          _KeepAlive(child: TicketScreen(key: TicketScreen.globalKey)),
          _KeepAlive(child: MeetingScreen(key: MeetingScreen.globalKey)),
        ],
      ),
    );
  }
}

/// Keeps a tab's page alive while another tab is shown, so switching back
/// doesn't reload the list or reset its filter.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
