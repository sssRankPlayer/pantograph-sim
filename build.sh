#!/usr/bin/env bash
set -x
ROOT=$(pwd)
GV=4.3-stable
mkdir -p "$HOME/godot" "$ROOT/build"
cd "$HOME/godot"
wget -q "https://github.com/godotengine/godot/releases/download/${GV}/Godot_v${GV}_linux.x86_64.zip" || exit 1
wget -q "https://github.com/godotengine/godot/releases/download/${GV}/Godot_v${GV}_export_templates.tpz" || exit 1
unzip -q "Godot_v${GV}_linux.x86_64.zip"
unzip -q "Godot_v${GV}_export_templates.tpz"
mkdir -p "$HOME/.local/share/godot/export_templates/4.3.stable"
mv templates/* "$HOME/.local/share/godot/export_templates/4.3.stable/"
GODOT="$HOME/godot/Godot_v${GV}_linux.x86_64"
chmod +x "$GODOT"
cd "$ROOT"

SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses > /dev/null || true
"$SDKM" "platform-tools" "build-tools;34.0.0" "platforms;android-34" || true
ls "$ANDROID_HOME" "$ANDROID_HOME/build-tools"

keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$HOME/debug.keystore" -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.3.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA_HOME"
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/debug_keystore = "$HOME/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
cp "$HOME/.config/godot/editor_settings-4.3.tres" "$HOME/.config/godot/editor_settings-4.tres"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASS=android

"$GODOT" --headless --path "$ROOT" --editor --quit || true
"$GODOT" --headless --path "$ROOT" --quit-after 120 || true
"$GODOT" --headless --path "$ROOT" --export-debug "Android" "$ROOT/build/pantograph-sim.apk"
ls -l "$ROOT/build"
