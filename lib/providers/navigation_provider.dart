import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/models/home_tab.dart';

/// Selected tab for [HomeScreen] bottom navigation.
final homeTabProvider = StateProvider<HomeTab>(
  (ref) => HomeTab.dashboard,
);
