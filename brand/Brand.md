# Ell-ena Brand

Canonical branding assets live in this folder. App runtime assets stay under `ELL-ena-logo/` and platform icon directories.

---

## Logo

| File | Use |
|------|-----|
| [`logo.svg`](logo.svg) | Primary SVG mark |
| [`favicon.svg`](favicon.svg) | Favicon SVG |
| [`icons/app-icon-source.png`](icons/app-icon-source.png) | App / launcher icon source |
| [`icons/logo-mark.png`](icons/logo-mark.png) | Compact mark (splash) |
| [`icons/logo-light-with-name.png`](icons/logo-light-with-name.png) | Light lockup |
| [`icons/logo-dark-with-name.png`](icons/logo-dark-with-name.png) | Dark lockup |
| [`icons/logo-bw-with-name.png`](icons/logo-bw-with-name.png) | Monochrome lockup |

**Do:** use SVG when scaling; keep clear space; dark mark on light backgrounds (and reverse).  
**Don’t:** stretch, recolor, or crop until the mark is unreadable.

---

## Colors

From `lib/theme/app_themes.dart`.

| Role | HEX |
|------|-----|
| Primary | `#66BB6A` |
| Secondary | `#388E3C` |
| Light background | `#F0F0F0` |
| Light surface | `#FFFFFF` |
| Light text | `#1C1C1C` |
| Light secondary text | `#5C5C5C` |
| Light border | `#E0E0E0` |
| Light error | `#B00020` |
| Dark background | `#1A1A1A` |
| Dark surface | `#2A2A2A` |
| Dark text | `#E8E8E8` |
| Dark secondary text | `#B0B0B0` |
| Dark border | `#404040` |
| Dark error | `#CF6679` |
| On primary | `#FFFFFF` |

---

## Typography

Material / platform default sans (no custom `fontFamily`). Scale from `TextTheme` in `app_themes.dart`:

| Style | Size | Weight |
|-------|------|--------|
| Display | 24–32 | Bold |
| Headline / title | 14–22 | w500–w600 |
| Body | 12–16 | Regular |
| Label / caption | 11–14 | w500 |

App bar title: 20 / w600.

---

## Icons

- **UI:** Material Icons; active accent `#66BB6A`.
- **App icon:** generated via `flutter_launcher_icons` → Android / iOS / macOS / Windows.
- **Web:** `web/favicon.png`, `web/icons/Icon-192.png`, `Icon-512.png` (copies in `brand/icons/`).
