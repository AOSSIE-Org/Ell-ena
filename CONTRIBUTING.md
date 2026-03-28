# 🤝 Contributing to Ell-ena

Thank you for your interest in contributing to Ell-ena! This guide will help you get set up quickly and contribute effectively.

---
## Table of Contents

- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Setup Instructions](#-setup-instructions)
- [Project Structure](#-project-structure)
- [Development Workflow](#-development-workflow)
- [Code Style](#-code-style)
- [Reporting Issues](#-reporting-issues)
- [Pull Request Guidelines](#-pull-request-guidelines)
- [Common Issues & Fixes](#common-issues--fixes)
---

## ⚡ Quick Start
```bash
git clone https://github.com/AOSSIE-Org/Ell-ena.git
cd Ell-ena
flutter pub get
cp .env.example .env   # then fill in your credentials
flutter run
```
> ⚠️ If `.env.example` is missing, create `.env` manually using the variables below.
---
## 📋 Prerequisites

Ensure the following are installed before you begin:

| Tool | Notes |
|------|-------|
| Flutter | Latest stable — run `flutter --version` to check |
| Dart | Bundled with Flutter |
| Git | Any recent version |
| IDE | Android Studio or VS Code (with Flutter extension) |
| Device | Emulator or physical device |

---

## 🚀 Setup Instructions

### 1. Fork and Clone

Fork the repo on GitHub, then clone your fork:

```bash
git clone https://github.com/<your-username>/Ell-ena.git
cd Ell-ena
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment

Copy the example env file and fill in your credentials:

```bash
cp .env.example .env
```

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

> ⚠️ Use your own Supabase project credentials.  
> 🚫 Never commit `.env` — it is already listed in `.gitignore`.

### 4. Run the App

```bash
flutter run
```

---

## 📁 Project Structure

```
Ell-ena/
├── lib/
│   ├── main.dart          # Entry point
│   ├── screens/           # UI screens
│   ├── widgets/           # Reusable widgets
│   ├── services/          # Supabase & API logic
│   └── models/            # Data models
├── test/                  # Unit & widget tests
├── .env.example           # Environment variable template
└── pubspec.yaml           # Dependencies
```

> Adjust this structure to match the actual project layout if it differs.

---

## 🔄 Development Workflow

1. Sync your fork with the upstream `main` branch before starting:
   ```bash
   git remote add upstream https://github.com/AOSSIE-Org/Ell-ena.git
   git fetch upstream
   git checkout main && git merge upstream/main
   ```
2. Create a focused branch for your change:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-name
   ```
3. Make your changes, keeping commits small and descriptive.
4. Push and open a Pull Request.

---

## 🧪 Code Style

Run both commands before every commit:

```bash
flutter analyze   # catch errors & lint warnings
flutter format .  # auto-format all Dart files
```

**Additional conventions:**

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
- Keep widgets small and composable.
- Add comments for non-obvious logic.
- Always guard async calls with `mounted` checks:
  ```dart
  if (!mounted) return;
  ```

---

## 🐛 Reporting Issues

Before opening an issue:

- Search [existing issues](https://github.com/AOSSIE-Org/Ell-ena/issues) to avoid duplicates.
- Try reproducing on the latest `main` branch.

When filing a bug report, include:

- Flutter version (`flutter --version`)
- Steps to reproduce
- Expected vs. actual behavior
- Screenshots or logs if relevant

Use the `bug` label for bugs and `enhancement` for feature requests.

---

## 📬 Pull Request Guidelines

- **One concern per PR** — keep it focused.
- **Link the related issue** in the PR description (e.g., `Closes #42`).
- **Pass CI** — ensure `flutter analyze` and `flutter format .` produce no errors.
- **Write a clear description** — what changed and why.
- **Be responsive** — address review feedback promptly.

PR title format:

```
feat: add dark mode toggle
fix: resolve login crash on Android 12
docs: update setup instructions
```

---

## ⚠️ Common Issues & Fixes

### App not compiling

```bash
flutter clean
flutter pub get
```

### Missing `.env` file

Make sure `.env` exists in the root directory with valid values. See [Setup Instructions](#3-configure-environment).

### Flutter version mismatch

```bash
flutter upgrade
```

### Supabase errors

- Verify `.env` values match your Supabase project dashboard.
- Ensure your Supabase project is not paused (free tier pauses after inactivity).

### Async context warnings

```dart
if (!mounted) return;
```

---

## 🙏 Thank You

Every contribution — bug reports, docs, code, or feedback — makes Ell-ena better.  
If you have questions, open a [GitHub Discussion](https://github.com/AOSSIE-Org/Ell-ena/discussions) or comment on the relevant issue.
