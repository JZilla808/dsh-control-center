#!/bin/zsh
# =============================================================================
#  dsh-control-center — macOS desktop app installer
#
#  Builds "DSH Control Center.app": a tiny AppleScript applet that opens one
#  Terminal window running the console, carrying a proper macOS icon.
#
#  Usage:
#    install/install-macos.sh                  install to ~/Applications
#    install/install-macos.sh --dir /Applications
#    install/install-macos.sh --app-only       build into ./build, do not install
#
#  The icon is generated from assets/generate-icon.swift when Swift is
#  available, so the committed artwork stays reproducible rather than being a
#  binary nobody can regenerate.
# =============================================================================
set -eu

ROOT="${0:A:h:h}"
APP_NAME="DSH Control Center"
DEST_DIR="$HOME/Applications"
APP_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)      DEST_DIR="$2"; shift 2 ;;
    --app-only) APP_ONLY=1; shift ;;
    -h|--help)  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '  %s\n' "$*"; }
die() { printf '  error: %s\n' "$*" >&2; exit 1; }

# --- 1. locate the console binary -------------------------------------------
CC_BIN="$(command -v dsh-control-center 2>/dev/null || true)"
if [ -z "$CC_BIN" ]; then
  if [ -x "$ROOT/bin/dsh-control-center" ]; then
    CC_BIN="$ROOT/bin/dsh-control-center"
    say "using the checkout copy: $CC_BIN"
  else
    die "dsh-control-center not found. Install it first: npm install -g dsh-control-center"
  fi
else
  say "found console at $CC_BIN"
fi

# --- 2. build the icon -------------------------------------------------------
BUILD="$ROOT/build"
rm -rf "$BUILD"
mkdir -p "$BUILD"

MASTER="$ROOT/assets/icon-1024.png"
if command -v swift >/dev/null 2>&1; then
  say "generating icon artwork…"
  swift "$ROOT/assets/generate-icon.swift" "$MASTER" >/dev/null || die "icon generation failed"
elif [ ! -f "$MASTER" ]; then
  die "swift is unavailable and assets/icon-1024.png is missing"
fi

say "building .icns…"
ICONSET="$BUILD/icon.iconset"
mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$MASTER" --out "$ICONSET/$1" >/dev/null 2>&1; }
gen icon_16x16.png 16;       gen icon_16x16@2x.png 32
gen icon_32x32.png 32;       gen icon_32x32@2x.png 64
gen icon_128x128.png 128;    gen icon_128x128@2x.png 256
gen icon_256x256.png 256;    gen icon_256x256@2x.png 512
gen icon_512x512.png 512;    gen icon_512x512@2x.png 1024
iconutil -c icns "$ICONSET" -o "$BUILD/applet.icns" || die "iconutil failed"

# A .icns alone is not enough on modern macOS: the applet's Info.plist sets
# CFBundleIconName, which resolves through Assets.car, and an applet generated
# by osacompile ships a placeholder icon there that wins over applet.icns.
# Rebuilding Assets.car is what actually changes the Finder/Dock icon.
if command -v actool >/dev/null 2>&1; then
  say "building Assets.car…"
  XC="$BUILD/Assets.xcassets/applet.appiconset"
  mkdir -p "$XC"
  cp "$ICONSET/icon_16x16.png"      "$XC/icon_16.png"
  cp "$ICONSET/icon_16x16@2x.png"   "$XC/icon_16@2x.png"
  cp "$ICONSET/icon_32x32.png"      "$XC/icon_32.png"
  cp "$ICONSET/icon_32x32@2x.png"   "$XC/icon_32@2x.png"
  cp "$ICONSET/icon_128x128.png"    "$XC/icon_128.png"
  cp "$ICONSET/icon_128x128@2x.png" "$XC/icon_128@2x.png"
  cp "$ICONSET/icon_256x256.png"    "$XC/icon_256.png"
  cp "$ICONSET/icon_256x256@2x.png" "$XC/icon_256@2x.png"
  cp "$ICONSET/icon_512x512.png"    "$XC/icon_512.png"
  cp "$ICONSET/icon_512x512@2x.png" "$XC/icon_512@2x.png"
  cat > "$XC/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom":"mac", "scale":"1x", "size":"16x16",   "filename":"icon_16.png" },
    { "idiom":"mac", "scale":"2x", "size":"16x16",   "filename":"icon_16@2x.png" },
    { "idiom":"mac", "scale":"1x", "size":"32x32",   "filename":"icon_32.png" },
    { "idiom":"mac", "scale":"2x", "size":"32x32",   "filename":"icon_32@2x.png" },
    { "idiom":"mac", "scale":"1x", "size":"128x128", "filename":"icon_128.png" },
    { "idiom":"mac", "scale":"2x", "size":"128x128", "filename":"icon_128@2x.png" },
    { "idiom":"mac", "scale":"1x", "size":"256x256", "filename":"icon_256.png" },
    { "idiom":"mac", "scale":"2x", "size":"256x256", "filename":"icon_256@2x.png" },
    { "idiom":"mac", "scale":"1x", "size":"512x512", "filename":"icon_512.png" },
    { "idiom":"mac", "scale":"2x", "size":"512x512", "filename":"icon_512@2x.png" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON
  printf '{ "info" : { "version" : 1, "author" : "xcode" } }\n' > "$BUILD/Assets.xcassets/Contents.json"
  mkdir -p "$BUILD/assets"
  actool --output-format human-readable-text --notices --warnings \
    --app-icon applet --output-partial-info-plist "$BUILD/partial.plist" \
    --enable-on-demand-resources NO --target-device mac \
    --minimum-deployment-target 11.0 --platform macosx \
    --compile "$BUILD/assets" "$BUILD/Assets.xcassets" >/dev/null 2>&1 \
    || say "warning: actool failed; falling back to applet.icns only"
else
  say "warning: actool unavailable; falling back to applet.icns only"
fi

# --- 3. compile the applet ---------------------------------------------------
say "compiling the launcher…"
LAUNCHER_SRC="$BUILD/launcher.applescript"
sed "s|__CC_BIN__|$CC_BIN|g" "$ROOT/install/launcher.applescript" > "$LAUNCHER_SRC"
APP="$BUILD/$APP_NAME.app"
rm -rf "$APP"
osacompile -o "$APP" "$LAUNCHER_SRC" || die "osacompile failed"

cp "$BUILD/applet.icns" "$APP/Contents/Resources/applet.icns"
if [ -f "$BUILD/assets/Assets.car" ]; then
  cp "$BUILD/assets/Assets.car" "$APP/Contents/Resources/Assets.car"
fi

# Finder adds com.apple.FinderInfo to a freshly written bundle and codesign
# refuses to sign a bundle carrying detritus, so clear it and retry — the
# attribute can reappear between the two steps.
SIGNED=0
for _attempt in 1 2 3; do
  xattr -cr "$APP" 2>/dev/null || true
  if codesign --force --sign - --identifier "org.dsh.community.control-center" "$APP" >/dev/null 2>&1 \
     && codesign --verify "$APP" >/dev/null 2>&1; then
    SIGNED=1; break
  fi
  sleep 1
done
if [ "$SIGNED" = "1" ]; then
  say "signed (ad-hoc)"
else
  say "warning: ad-hoc signing failed; the app still runs locally"
fi

if [ "$APP_ONLY" = "1" ]; then
  say "built: $APP"
  exit 0
fi

# --- 4. install --------------------------------------------------------------
mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/$APP_NAME.app"
cp -R "$APP" "$DEST_DIR/$APP_NAME.app"
say "installed: $DEST_DIR/$APP_NAME.app"

touch "$DEST_DIR/$APP_NAME.app"
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

cat <<EOF

  Done. Open "$DEST_DIR/$APP_NAME.app".

  First launch may ask for permission to control Terminal — allow it once and
  macOS remembers.

  For the deep-sea terminal palette, create a Terminal profile named
  "Deep Sea"; without it the console still runs, it just keeps your current
  colours.

EOF
