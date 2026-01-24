# Theme Toggle Feature

## Overview
This implementation adds a complete theme toggle functionality to the Ell-ena app, allowing users to switch between light and dark modes.

## Files Created

### 1. `lib/providers/theme_provider.dart`
- `ThemeProvider` class that manages the app's theme state
- Persists theme preference using SharedPreferences
- Provides methods to toggle and set theme mode

### 2. `lib/theme/app_themes.dart`
- `AppThemes` class with static getters for light and dark themes
- Consistent color schemes for both themes
- Material 3 design implementation

### 3. `lib/widgets/theme_toggle.dart`
- `ThemeToggleButton`: Icon button for quick theme toggling
- `ThemeToggleSwitch`: Switch with label for settings screens

## Usage

### In AppBar (Icon Button)
```dart
import '../widgets/theme_toggle.dart';

AppBar(
  title: Text('My Screen'),
  actions: [
    ThemeToggleButton(),
  ],
)
```

### In Settings Screen (Switch)
```dart
import '../widgets/theme_toggle.dart';

ThemeToggleSwitch()
```

### Programmatic Theme Change
```dart
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

// Toggle theme
Provider.of<ThemeProvider>(context, listen: false).toggleTheme();

// Set specific theme
Provider.of<ThemeProvider>(context, listen: false).setThemeMode(ThemeMode.light);

// Check current theme
final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
```

## Features
- ✅ Persistent theme preference (survives app restart)
- ✅ Smooth theme transition
- ✅ Light and dark theme implementations
- ✅ Ready-to-use toggle widgets
- ✅ Provider-based state management

## Integration Example

To add the theme toggle button to the ProfileScreen, add it to the AppBar:

```dart
appBar: AppBar(
  title: Text('Profile'),
  actions: [
    ThemeToggleButton(),
  ],
)
```
