# ISwipe

Swipe-based image sorter for Android and iOS. No accounts, all local.

## Features

- Browse all image albums/folders on your device
- Grid gallery view with green checkmarks on reviewed (kept) images
- Tinder-style swipe sorting: left to trash, right to keep
- Preview bar showing 5 past + current + 5 upcoming thumbnails
- Undo last deletion (Android restores from system trash)
- Deleted tab with local history of trashed items
- Analytics tab with deletion stats by day, month, and year
- Settings screen (placeholder for future options)

## Requirements

- Flutter SDK 3.2+
- Android 7.0+ (API 24)
- iOS 12+

## Run on Android (Android Studio)

Your phone **SM A546B** is already detected when connected over USB.

### One-time setup

```bash
./scripts/setup-android-studio.sh
```

This writes `android/local.properties`, points Flutter at your SDK/JDK, and configures Gradle to use **Java 21** (required because Android Studio 2026 ships Java 25, which is incompatible with the current Gradle version).

### Open in Android Studio

1. **File → Open** → select `/home/horia/Projects/cursor/ISwipe` (the project root, **not** the `android/` folder).
2. **Settings → Languages & Frameworks → Flutter**  
   Flutter SDK path: `/home/horia/.local/flutter`
3. **Settings → Build, Execution, Deployment → Build Tools → Gradle**  
   Gradle JDK: **java-21-openjdk** (21)
4. Wait for **Pub get** and **Gradle sync** to finish.
5. On your phone: enable **Developer options → USB debugging**, connect via USB, accept the trust prompt.
6. In the toolbar, pick your device (**SM A546B**) and click **Run** on `main.dart`.

### CLI alternative

```bash
export PATH="$HOME/.local/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter run -d RZCW40P7XXJ
```

### Troubleshooting

| Problem | Fix |
|---------|-----|
| Gradle/Java version error | Set Gradle JDK to 21 in Android Studio (step 3 above) or re-run the setup script |
| No device shown | Check USB debugging; run `flutter devices` |
| Photo permission denied | Grant photos permission when prompted on first launch |


## Trash behavior

Deleted images are moved to the **system trash** (Android trash / iOS Recently Deleted), not permanently removed. They expire automatically per OS rules (typically up to 30 days).

**Undo:** Works on Android via system trash restore. On iOS, undo may require manual recovery from Photos → Recently Deleted.

## Permissions

- **Android:** `READ_MEDIA_IMAGES` (Android 13+), legacy storage on older versions
- **iOS:** Photo Library read access (limited access supported)

## Project structure

```
lib/
  main.dart                 App entry
  screens/                  Gallery, Deleted, Analytics, Settings
  services/                 Gallery, review, analytics, database
  widgets/                  Swipe card, preview bar, reviewed badge
```

## License

Private / testing version.
