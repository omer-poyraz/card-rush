#!/usr/bin/env bash
# Builds the targets this machine can build.
#   tools/build_release.sh [windows] [linux] [apk] [aab] [ios]   (default: all)
# Android release signing reads LOCAL secrets only (never committed):
#   env GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
# or export/keys/cardrush-upload.keystore + export/keys/upload_password.txt.
set -euo pipefail
cd "$(dirname "$0")/.."
G="$(tools/godot_path.sh)"
TARGETS=("$@"); [ ${#TARGETS[@]} -eq 0 ] && TARGETS=(tests windows linux apk aab ios)
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
mkdir -p export/windows export/linux export/android export/ios

ensure_android_template() {
  if [ ! -f android/.build_version ]; then
    local tpl="$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip"
    mkdir -p android/build && unzip -qo "$tpl" -d android/build
    echo "4.7.2.stable" > android/.build_version && touch android/build/.gdignore
  fi
}

release_keys() {
  if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] && [ -f export/keys/cardrush-upload.keystore ]; then
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(pwd)/export/keys/cardrush-upload.keystore"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER="cardrush-upload"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat export/keys/upload_password.txt)"
  fi
  [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] || { echo "AAB: no release keystore configured (see docs/RELEASE_CHECKLIST.md)"; return 1; }
}

"$G" --headless --path . --import >/dev/null 2>&1 || true
for t in "${TARGETS[@]}"; do
  case "$t" in
    tests) tools/run_tests.sh ;;
    windows) "$G" --headless --path . --export-release "Windows Desktop" export/windows/CardRush.exe ;;
    linux)
      "$G" --headless --path . --export-release "Linux (smoke test)" export/linux/CardRush.x86_64
      timeout 60 ./export/linux/CardRush.x86_64 --headless --quit-after 300 >/dev/null 2>&1 && echo "linux smoke: started and quit cleanly" ;;
    apk) ensure_android_template; "$G" --headless --path . --export-debug "Android APK" export/android/CardRush-debug.apk ;;
    aab) ensure_android_template; release_keys && "$G" --headless --path . --export-release "Android AAB" export/android/CardRush-release.aab ;;
    ios) "$G" --headless --path . --export-release "iOS" export/ios/CardRush.ipa || echo "iOS: final build needs macOS + Xcode + Apple Team ID (docs/RELEASE_CHECKLIST.md)" ;;
    *) echo "unknown target $t"; exit 2 ;;
  esac
done
ls -la export/*/ 2>/dev/null || true
