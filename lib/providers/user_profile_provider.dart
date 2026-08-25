import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Holds the current user's profile (id, full_name, email, avatar_url,
/// role, team_id) as shared, reactive app state, so every screen holding a
/// reference to this controller re-renders when the profile changes --
/// instead of each screen independently calling
/// SupabaseService().getCurrentUserProfile() into its own local state.
class UserProfileController extends ChangeNotifier {
  Map<String, dynamic>? _profile;

  Map<String, dynamic>? get profile => _profile;

  bool get isLoaded => _profile != null;

  String? get id => _profile?['id'] as String?;
  String? get fullName => _profile?['full_name'] as String?;
  String? get email => _profile?['email'] as String?;
  String? get avatarUrl => _profile?['avatar_url'] as String?;
  String? get role => _profile?['role'] as String?;
  String? get teamId => _profile?['team_id'] as String?;

  /// Loads/refreshes the profile from [SupabaseService] and notifies
  /// listeners. Pass [forceRefresh] to bypass SupabaseService's own cache.
  Future<void> refresh({bool forceRefresh = false}) async {
    final profile = await SupabaseService()
        .getCurrentUserProfile(forceRefresh: forceRefresh);
    _profile = profile;
    notifyListeners();
  }

  /// Updates just the local avatar_url and notifies listeners, without a
  /// full profile refetch. Call this right after a successful
  /// uploadAvatar()/removeAvatar() call on SupabaseService, so every screen
  /// holding a reference to this provider re-renders immediately.
  void updateAvatarUrl(String? newUrl) {
    _profile = {...?_profile, 'avatar_url': newUrl};
    notifyListeners();
  }
}

/// Riverpod exposure of [UserProfileController].
/// Overridden at app startup with the instance created in main.dart.
final userProfileControllerProvider =
    ChangeNotifierProvider<UserProfileController>((ref) {
  throw StateError(
    'userProfileControllerProvider must be overridden in ProviderScope',
  );
});
