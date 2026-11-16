import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation index for the home shell ([HomeScreen]).
///
/// 0: Dashboard, 1: Calendar, 2: Workspace, 3: Chat, 4: Profile.
///
/// Not wired to [HomeScreen] yet — foundation for future migration.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);
