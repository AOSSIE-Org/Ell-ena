import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/auth/login_screen.dart';
import '../services/navigation_service.dart';
import '../services/supabase_service.dart';

/// Lets the user pick one of [teams]. Returns the chosen team id, or null when
/// the dialog is cancelled or the current team is picked again.
Future<String?> showTeamSwitcherDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> teams,
  required String? currentTeamId,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.switchTeam,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              final isCurrentTeam = team['id'] == currentTeamId;

              final scheme = Theme.of(context).colorScheme;
              return ListTile(
                title: Text(
                  team['name'] ?? l10n.teamFallbackName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight:
                        isCurrentTeam ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  l10n.teamCode('${team['team_code'] ?? 'N/A'}'),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: isCurrentTeam
                      ? Colors.green.shade400
                      : Colors.grey.shade700,
                  child: Text(
                    (team['name'] as String? ?? 'T')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                trailing: isCurrentTeam
                    ? Icon(Icons.check, color: Colors.green.shade400)
                    : null,
                onTap: () {
                  Navigator.pop(
                    context,
                    isCurrentTeam ? null : team['id'] as String?,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              l10n.cancel,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );
}

/// Asks for confirmation, signs out, and returns to the login page.
Future<void> confirmAndSignOut(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  //Confirmation dialog
  final shouldLogout = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(l10n.logoutTitle),
      content: Text(l10n.logoutMessage),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            l10n.logout,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (shouldLogout != true || !context.mounted) return;

  // modal loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  try {
    await SupabaseService().signOut();

    if (context.mounted) {
      Navigator.pop(context); // close loader
      NavigationService().navigateToReplacement(const LoginScreen());
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commonErrorLoggingOut('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
