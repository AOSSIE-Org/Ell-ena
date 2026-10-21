import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/support_us_panel.dart';
import '../shell_destination.dart';

/// Fixed-width sidebar aligned with Figma shell (~288px).
class ShellNavigationRail extends StatelessWidget {
  static const double width = 288;

  final ShellDestination selectedDestination;
  final ValueChanged<ShellDestination>? onDestinationSelected;

  const ShellNavigationRail({
    super.key,
    required this.selectedDestination,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Material(
        color: colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'web/favicon.svg',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ell-ena',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
              indent: 24,
              endIndent: 24,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final destination in ShellDestination.sidebar)
                    _ShellNavItem(
                      destination: destination,
                      isSelected: destination == selectedDestination,
                      onTap: onDestinationSelected == null
                          ? null
                          : () => onDestinationSelected!(destination),
                    ),
                ],
              ),
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: _SupportUsNavItem(
                  onTap: () => openSupportUs(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  final ShellDestination destination;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ShellNavItem({
    required this.destination,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final foregroundColor =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  size: 24,
                  color: foregroundColor,
                ),
                const SizedBox(width: 12),
                Text(
                  destination.labelFor(l10n),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportUsNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportUsNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.volunteer_activism_outlined,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.shellSupportUs,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
