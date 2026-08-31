#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_SDK="${FLUTTER_SDK:-$HOME/.local/flutter}"
ANDROID_SDK="${ANDROID_SDK:-$HOME/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk}"

echo "==> ISwipe Android Studio setup"
echo "    Project:  $ROOT"
echo "    Flutter:  $FLUTTER_SDK"
echo "    Android:  $ANDROID_SDK"
echo "    Java:     $JAVA_HOME"

if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  echo "ERROR: Flutter not found at $FLUTTER_SDK"
  echo "Install Flutter or set FLUTTER_SDK to your SDK path."
  exit 1
fi

if [[ ! -d "$ANDROID_SDK" ]]; then
  echo "ERROR: Android SDK not found at $ANDROID_SDK"
  echo "Install Android Studio or set ANDROID_SDK."
  exit 1
fi

mkdir -p "$ROOT/android"
cat > "$ROOT/android/local.properties" <<EOF
sdk.dir=$ANDROID_SDK
flutter.sdk=$FLUTTER_SDK
EOF

GRADLE_PROPS="$ROOT/android/gradle.properties"
if grep -q '^org.gradle.java.home=' "$GRADLE_PROPS" 2>/dev/null; then
  sed -i "s|^org.gradle.java.home=.*|org.gradle.java.home=$JAVA_HOME|" "$GRADLE_PROPS"
else
  echo "org.gradle.java.home=$JAVA_HOME" >> "$GRADLE_PROPS"
fi

export PATH="$FLUTTER_SDK/bin:$ANDROID_SDK/platform-tools:$PATH"

"$FLUTTER_SDK/bin/flutter" config --jdk-dir="$JAVA_HOME" --android-sdk="$ANDROID_SDK"
"$FLUTTER_SDK/bin/flutter" pub get

echo
echo "==> Verifying toolchain"
"$FLUTTER_SDK/bin/flutter" doctor

echo
echo "==> Connected devices"
"$FLUTTER_SDK/bin/flutter" devices

echo
cat <<'INSTRUCTIONS'

Setup complete.

Open in Android Studio:
  1. File → Open → select the ISwipe project root (not the android/ folder)
  2. Settings → Languages & Frameworks → Flutter
     Flutter SDK path: /home/horia/.local/flutter
  3. Settings → Build, Execution, Deployment → Build Tools → Gradle
     Gradle JDK: java-21-openjdk (or "21")
  4. Enable USB debugging on your phone, connect via USB
  5. Select your device in the toolbar and press Run (main.dart)

If Gradle sync fails with a Java version error, set Gradle JDK to 21 in:
  Settings → Build Tools → Gradle → Gradle JDK

INSTRUCTIONS
