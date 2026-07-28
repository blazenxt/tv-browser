# TV Browser

A Chrome-inspired, D-pad friendly web browser for **Android TV, Google TV and Fire TV**, built with Flutter.
Designed from the ground up for the couch: a tab strip and omnibox, strong
focus rings, virtual mouse cursor, link-jump navigation, incognito tabs,
voice search, bookmarks, history and downloads.

![TV Browser banner](assets/banner.png)

---

## ✨ Features

| Feature | Details |
| --- | --- |
| **Virtual mouse cursor** | Move a pointer with the D-pad, click with OK. Native WebView taps work with players and JavaScript-heavy sites. |
| **Jump mode** | Focus hops directly between links/buttons—even off-screen ones—and scrolls them into view. Switch anytime from the toolbar. |
| **Chrome-inspired TV UI** | Tab strip, rounded omnibox, secure-page indicator, page menu and light/dark/system themes. |
| **Tabs** | Session restore, duplicate/reopen closed tabs, full-screen overview and private incognito tabs. |
| **Find & zoom** | Find text in the current page and set per-tab page zoom from 50–200%. |
| **Bookmarks** | Bookmark manager plus new-tab shortcuts; MENU on a shortcut removes it. |
| **History & downloads** | Dedicated remote-friendly managers, progress tracking and clear-list controls. |
| **Privacy & security** | Incognito tabs, clear browsing data, Safe Browsing, cookie control, Do Not Track and per-site permission prompts. |
| **Voice search** | Dictate addresses and searches (where the TV/box has a mic). |
| **TV-native UI** | Leanback launcher entry with banner, overscan-safe dark UI, big focus outlines. |
| **Web text fields** | Clicking a text box opens an on-TV dialog (with voice + Done/Enter) — no fighting the WebView for keyboard focus. |
| **Desktop mode** | Optional desktop user-agent for sites that serve cramped mobile layouts. |
| **Ad & popup blocker** | Built-in blocklist kills known ad/tracker networks; silent pop-ups are cancelled, gestured ones open in the same tab. Toggle in Settings. |
| **Downloads** | Files offered by sites download to the TV's public **Downloads** folder, with a progress dialog. |
| **Text size** | Normal / Large / Extra-large website text scaling. |
| **Custom new-tab page** | New tabs open the built-in start page or any URL you choose. |

## 🎮 Remote control

| Button | In cursor mode | In jump mode |
| --- | --- | --- |
| **D-pad arrows** | Move pointer (auto-scrolls at edges) | Highlight next link in that direction |
| **OK / SELECT** | Click | Click highlighted link |
| **MENU (≡)** | Open the toolbar; press again for the page menu | Same |
| **BACK** | Page back → closes tab → home → exit confirm | Same |
| **D-pad UP at top of page** | Open toolbar | Open toolbar |
| **MENU on a bookmark (start page)** | Delete bookmark | — |

Toolbar buttons: Back · Forward · Reload/Stop · Home · **Address bar** ·
★ Bookmark · Cursor/Jump toggle · Tabs · History · Settings.

## 📱 Install on your TV

1. Grab the APK (see [Releases](../../releases) or build it yourself — below).
2. Copy it to the TV with one of:
   * **Send files to TV** / **LocalSend** (phone ↔ TV over Wi-Fi)
   * **Downloader** app on the TV with a direct link
   * **USB stick**
   * **adb**: `adb connect <TV-IP> && adb install app-release.apk`
3. Open it from the TV's app row (🌐 *TV Browser* banner).

## 🛠️ Build from source

Requirements: [Flutter 3.24.5+](https://docs.flutter.dev/get-started/install), Android SDK 34, JDK 17.

```bash
flutter pub get
flutter test
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
```

No secrets or signing setup needed — release builds are signed with the
debug key so they install anywhere.

## ⚙️ CI build (GitHub Actions)

`.github/workflows/build.yml` builds split-ABI APKs on every push and
attaches them as workflow artifacts — no local toolchain required.
Fork, push, download from the **Actions** tab.

## 🗂️ Project structure

```
lib/
├─ main.dart                    App entry, providers, theme
├─ models/models.dart           Bookmark / HistoryEntry / BrowserTab
├─ providers/                   settings, bookmarks, history, tabs (ChangeNotifiers)
├─ services/
│  ├─ tv_js.dart                JS injected into every page (cursor clicks,
│  │                            spatial highlight, web-input bridge)
│  └─ voice_service.dart        speech-to-text wrapper
├─ widgets/                     TvButton, cursor overlay, dialogs
└─ screens/                     browser, home panel, tabs, history, settings
android/                        Leanback manifest, banner, icons
```

## 🎨 Customization tips

* **App name** — `android:label` in `android/app/src/main/AndroidManifest.xml`.
* **Package id** — `applicationId` in `android/app/build.gradle`.
* **Icon / banner** — replace files under `android/app/src/main/res/mipmap-*`
  and `…/res/drawable*/banner.png` (320×180).
* **Default bookmarks / search engine** — `lib/providers/bookmarks_provider.dart`
  and `lib/providers/settings_provider.dart`.
* **Cursor look/speed** — `lib/widgets/cursor_overlay.dart` and
  `CursorSpeed` in settings provider.

## 🧾 Changelog

**1.3.0** — Chrome-inspired tab strip and omnibox, light/dark/system themes,
incognito tabs, session restore, reopen/duplicate tab, bookmark and download
managers, find-in-page, per-tab zoom and desktop mode, page sharing/translation,
site permission prompts, TV-native JavaScript dialogs, fullscreen media,
external-app links, clear browsing data and expanded remote/keyboard controls.

**1.2.0** — Reliable Android TV / Google TV / Fire TV remote bridge,
native WebView cursor taps and hover, improved jump navigation and automatic
focus scrolling throughout the TV UI.

**1.1.0** — Ad & popup blocker (with toggle), downloads to the public
Downloads folder via MediaStore, text-size setting, customizable new-tab
page, popup navigation goes to the current tab instead of being lost.

**1.0.0** — First release: cursor + jump navigation, tabs, bookmarks,
history, voice search, settings, TV launcher banner.

## ⚠️ Known limitations

* This is an independent Chrome-inspired TV interface, not Google Chrome.
  Google account sync, the Chrome Web Store/extensions, Chrome Password Manager
  and Google's proprietary browser services are not available.
* The rendering engine is the **system WebView** — update "Android System
  WebView" from the Play Store for the best compatibility. DRM services
  (Netflix etc.) will not work in any WebView-based browser.
* Jump mode relies on finding visible links in the DOM; very dynamic sites
  may behave better in cursor mode.
* A background tab with playing media keeps playing (switch away or close it).

## 📄 License

MIT — see [LICENSE](LICENSE).
