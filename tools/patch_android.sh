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

echo "==> Installing our MainActivity (Termux launcher code)"
MAIN="$(find android/app/src/main -name 'MainActivity.kt' | head -n 1)"
if [ -z "$MAIN" ]; then
  echo "ERROR: MainActivity.kt not found."
  exit 1
fi
cp tools/MainActivity.kt "$MAIN"
echo "Copied tools/MainActivity.kt to $MAIN"

echo "All Android patches applied."
