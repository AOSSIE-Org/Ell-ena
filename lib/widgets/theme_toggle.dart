import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// A widget that displays a theme toggle switch
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          ),
          tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
          onPressed: () {
            themeProvider.toggleTheme();
          },
        );
      },
    );
  }
}

/// A widget that displays a theme toggle switch with label
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: Text(themeProvider.isDarkMode ? 'Enabled' : 'Disabled'),
          value: themeProvider.isDarkMode,
          onChanged: (_) {
            themeProvider.toggleTheme();
          },
          secondary: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          ),
        );
      },
    );
  }
}
