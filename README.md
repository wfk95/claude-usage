# Claude Usage

A tiny macOS menu bar app that shows your Claude plan usage at a glance — a
doughnut gauge with your current 5‑hour session percentage and the time until it
resets, plus your weekly limits in a click‑down panel.

No more digging through the website or app just to see how much of your session
you've used.

```
🍩 34% · 52m            ← always visible in the menu bar
────────────────────────
 Current session   34%
 ▓▓▓▓▓░░░░░░░░░░    resets in 52m
 Weekly · all      18%
 ▓▓░░░░░░░░░░░░░    resets Sat 1:00 PM
 Weekly · Sonnet    2%
 ░░░░░░░░░░░░░░░    resets Sat 1:00 PM
```

> _Add a screenshot here once you've grabbed one (`screencapture -i shot.png`)._

## Features

- **Menu bar doughnut** showing current‑session usage, color‑coded green → yellow → red.
- **Time‑to‑reset** right next to it (`52m`, `1h4m`).
- **Click‑down panel** with all three limits (session, weekly all‑models, weekly Sonnet) and reset times.
- **Weekly in the bar when it matters** — optionally surface the weekly figure only once it crosses a threshold you set (default 50%).
- **Sign in with Claude** (OAuth, PKCE). Your token is stored in your macOS Keychain and auto‑refreshes.
- **Launch at login** toggle.
- Auto‑refreshes every 60s and on each open.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon (the build targets `arm64`; see *Build a universal binary* below for Intel)
- Xcode Command Line Tools (`xcode-select --install`) — no full Xcode needed

## Build & run

```bash
git clone https://github.com/<you>/claude-usage.git
cd claude-usage
./build.sh
open build/ClaudeUsage.app
```

Click **Sign in** in the menu bar, approve in the browser that opens, copy the
code it shows you, and paste it back into the app. Done.

### Build a universal binary (Apple Silicon + Intel)

Edit `build.sh` and change the compile step to build both architectures:

```bash
swiftc -O -target arm64-apple-macosx13.0  -o "$MACOS/$APP-arm64"  Sources/*.swift
swiftc -O -target x86_64-apple-macosx13.0 -o "$MACOS/$APP-x86_64" Sources/*.swift
lipo -create "$MACOS/$APP-arm64" "$MACOS/$APP-x86_64" -output "$MACOS/$APP"
rm "$MACOS/$APP-arm64" "$MACOS/$APP-x86_64"
```

## How it works

The app reads the same usage data the Claude apps show, from the endpoint the
Claude CLI uses for its `/usage` command:

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <your token>
anthropic-beta: oauth-2025-04-20
```

It returns the 5‑hour session bucket and the weekly buckets, which map directly
to the bars you see.

Sign‑in uses the standard OAuth 2.0 authorization‑code + PKCE flow. The access
and refresh tokens live in your **own** Keychain entry (`com.fk.ClaudeUsage`) —
the app never touches the entry the Claude CLI manages.

## Project layout

```
build.sh              Compiles Sources/ into ClaudeUsage.app (no Xcode project)
make_icon.{swift,sh}  Generates the app icon (Resources/AppIcon.icns)
Sources/
  AppDelegate.swift   Menu bar item, popover, sign-in dialog
  AppModel.swift      State + polling + formatting
  OAuth.swift         PKCE sign-in, token exchange/refresh
  UsageAPI.swift      Usage endpoint + response model
  UsageView.swift     The click-down SwiftUI panel
  SettingsStore.swift Persisted preferences
  MenuBarIcon.swift   The doughnut renderer
  Keychain.swift      Token storage
  LaunchAtLogin.swift Login-item toggle (SMAppService)
```

## ⚠️ Disclaimer

This is an **unofficial** tool and is **not affiliated with, endorsed by, or
supported by Anthropic**. It relies on a private, undocumented endpoint that may
change or stop working at any time. It is intended for personal use with your
own account. "Claude" is a trademark of Anthropic — this project uses the name
only to describe what it does. Use at your own risk.

## License

[MIT](LICENSE) © 2026 Fengkai Wan
