#!/usr/bin/env bash
# Applies AI Hub's Android settings after "flutter create" has made the android folder.
# Safe to run more than once.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: $MANIFEST not found. Did 'flutter create' run?"
  exit 1
fi

echo "==> Patching AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

# 1) Allow plain http (our gateway is http://localhost:3001)
if "android:usesCleartextTraffic" not in text:
    text = text.replace(
        "<application",
        '<application android:usesCleartextTraffic="true"',
        1,
    )

# 2) App name shown under the icon
text = text.replace('android:label="ai_hub"', 'android:label="AI Hub"')

# 3) Permissions and <queries> (only once)
if "com.termux.permission.RUN_COMMAND" not in text:
    block = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="com.termux.permission.RUN_COMMAND"/>

    <queries>
        <package android:name="com.termux"/>
        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
    </queries>
"""
    text = text.replace("<application", block + "\n    <application", 1)

open(path, "w", encoding="utf-8").write(text)
print("Manifest done.")
PY

echo "==> Setting minSdk to 24"
for f in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$f" ]; then
    sed -i -E 's/minSdk(Version)?[[:space:]]*=[[:space:]]*flutter\.minSdkVersion/minSdk = 24/; s/minSdkVersion[[:space:]]+flutter\.minSdkVersion/minSdkVersion 24/' "$f"
    echo "Patched $f"
  fi
done

echo "==> Gradle init script (compileSdk 36 + lint band)"
# 1) Kuch plugins (jaise file_picker) API 34 par bane hain, lekin lifecycle
#    library ko API 36 chahiye. Har module ka compileSdk 36 kar dete hain.
# 2) Plugins ka "lint" check (jaise image_picker_android) Java 17 par crash
#    hota hai. APK banane ke liye ye zaroori nahi, isliye band kar dete hain.
INIT_DIR="$HOME/.gradle/init.d"
mkdir -p "$INIT_DIR"
cat > "$INIT_DIR/ai_hub_compile_sdk.gradle" <<'GRADLE'
// AI Hub: make every Android module compile against API 36 or higher.
gradle.projectsLoaded { g ->
    g.rootProject.allprojects { p ->
        p.afterEvaluate { proj ->
            def android = proj.extensions.findByName('android')
            if (android == null) return

            int current = 0
            try {
                def text = android.compileSdkVersion == null ? '' : android.compileSdkVersion.toString()
                def m = (text =~ /(\d+)/)
                if (m.find()) current = m.group(1) as int
            } catch (Throwable ignored) {
                current = 0
            }
            if (current >= 36) return

            try {
                android.compileSdkVersion(36)
            } catch (Throwable first) {
                try {
                    android.compileSdk = 36
                } catch (Throwable second) {
                    println 'AI Hub: could not raise compileSdk for ' + proj.path
                }
            }
        }
    }
}

// AI Hub: lint tasks band (lint tool Java 17 par crash ho raha hai).
gradle.taskGraph.whenReady { graph ->
    graph.allTasks.each { t ->
        if (t.name.startsWith('lint')) {
            t.enabled = false
        }
    }
}
GRADLE
echo "Wrote $INIT_DIR/ai_hub_compile_sdk.gradle"

echo "==> Installing our MainActivity (Termux launcher code)"
MAIN="$(find android/app/src/main -name 'MainActivity.kt' | head -n 1)"
if [ -z "$MAIN" ]; then
  echo "ERROR: MainActivity.kt not found."
  exit 1
fi
cp tools/MainActivity.kt "$MAIN"
echo "Copied tools/MainActivity.kt to $MAIN"

echo "All Android patches applied."
