#!/usr/bin/env bash
#
# Build SwiftDefaultApps as an arm64 (or universal) preference pane, sign it
# and install it into ~/Library/PreferencePanes.
#
# Why this exists: releases built before Apple Silicon are x86_64-only. System
# Settings hosts third-party panes in legacyLoader-arm64, and an arm64 process
# cannot load an x86_64 bundle, so those panes silently fail to appear. Building
# for arm64 fixes that.
#
#   ./build.sh                 build, sign, install
#   ./build.sh --no-install    build and sign only
#   ./build.sh --cli           also build the "swda" command line tool
#
# Environment overrides:
#   SIGN_ID="..."              signing identity ("-" for ad-hoc)
#   ARCH="arm64"               narrow the build (default: universal)
#   DEPLOY_TARGET="12.0"       minimum macOS version

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO/build/Release"
BACKUP_DIR="$REPO/backups"
INSTALL_DIR="$HOME/Library/PreferencePanes"
PANE="SwiftDefaultApps.prefpane"

SWIFTCLI_DIR="$REPO/Packages/SwiftCLI-2.0.3"
SWIFTCLI_URL="https://github.com/Lord-Kamina/SwiftCLI.git"
SWIFTCLI_TAG="2.0.3+swift5"

# Universal by default: an x86_64-only pane cannot be loaded by
# legacyLoader-arm64, and an arm64-only one leaves Intel Macs out.
ARCH="${ARCH:-arm64 x86_64}"
DEPLOY_TARGET="${DEPLOY_TARGET:-12.0}"

DO_INSTALL=1
DO_CLI=0
for arg in "$@"; do
	case "$arg" in
		--no-install) DO_INSTALL=0 ;;
		--cli)        DO_CLI=1 ;;
		-h|--help)    sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# --------------------------------------------------------------- dependencies
# The Xcode project expects SwiftCLI sources at Packages/SwiftCLI-2.0.3/Sources.
# Tag 2.0.3 is Swift 3 code (String.characters) and no longer compiles; only
# 2.0.3+swift5 builds against current toolchains.
step "Checking SwiftCLI"
if [ ! -f "$SWIFTCLI_DIR/Sources/CLI.swift" ]; then
	echo "missing - cloning tag $SWIFTCLI_TAG"
	mkdir -p "$(dirname "$SWIFTCLI_DIR")"
	git clone --depth 1 --branch "$SWIFTCLI_TAG" "$SWIFTCLI_URL" "$SWIFTCLI_DIR"
else
	echo "present: $SWIFTCLI_DIR"
fi

# ------------------------------------------------------------------- identity
step "Signing identity"
if [ -z "${SIGN_ID:-}" ]; then
	SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
		| sed -n 's/.*"\(Developer ID Application: .*\)"$/\1/p' | head -1)"
fi
if [ -z "$SIGN_ID" ]; then
	echo "no Developer ID Application identity found - using ad-hoc"
	echo "(fine for local use, not for distribution)"
	SIGN_ID="-"
elif [ "$SIGN_ID" != "-" ] && ! security find-identity -v -p codesigning | grep -qF "$SIGN_ID"; then
	echo "requested identity is not in the keychain - falling back to ad-hoc" >&2
	SIGN_ID="-"
fi
# Deliberately not echoing the identity itself: it carries a real name and
# Team ID, and build logs get pasted into issues.
if [ "$SIGN_ID" = "-" ]; then
	echo "using: ad-hoc signature"
else
	echo "using: Developer ID Application from keychain"
fi

# Ad-hoc signatures cannot be timestamped.
TS_FLAG=(--timestamp)
[ "$SIGN_ID" = "-" ] && TS_FLAG=(--timestamp=none)

# ---------------------------------------------------------------------- build
step "Building prefpane ($ARCH, deployment target $DEPLOY_TARGET)"
xcodebuild -project "$REPO/SWDA Prefpane.xcodeproj" \
	-target SwiftDefaultApps \
	-configuration Release \
	ARCHS="$ARCH" ONLY_ACTIVE_ARCH=NO \
	MACOSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
	CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" \
	2>&1 | grep -E '^/.*(error|warning):|^\*\* BUILD' || true

[ -d "$BUILD_DIR/$PANE" ] || { echo "build product missing: $BUILD_DIR/$PANE" >&2; exit 1; }

if [ "$DO_CLI" = 1 ]; then
	step "Building CLI"
	xcodebuild -project "$REPO/SwiftDefaultApps CLI.xcodeproj" \
		-target SwiftDefaultApps \
		-configuration Release \
		ARCHS="$ARCH" ONLY_ACTIVE_ARCH=NO \
		MACOSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" \
		2>&1 | grep -E '^/.*error:|^\*\* BUILD' || true
	echo "CLI built at: $BUILD_DIR/swda"
fi

# ----------------------------------------------------------------------- sign
# Nested bundles must be signed before the enclosing one.
step "Signing"
codesign --force --options runtime "${TS_FLAG[@]}" --sign "$SIGN_ID" \
	"$BUILD_DIR/$PANE/Contents/Resources/ThisAppDoesNothing.app"
codesign --force --options runtime "${TS_FLAG[@]}" --sign "$SIGN_ID" \
	"$BUILD_DIR/$PANE"

codesign --verify --deep --strict "$BUILD_DIR/$PANE" && echo "signature verified"
codesign -dv "$BUILD_DIR/$PANE" 2>&1 | grep -E '^(Identifier|Format)='
lipo -info "$BUILD_DIR/$PANE/Contents/MacOS/SwiftDefaultApps"

if [ "$DO_INSTALL" = 0 ]; then
	step "Done (not installed)"
	echo "$BUILD_DIR/$PANE"
	exit 0
fi

# -------------------------------------------------------------------- install
# legacyLoader keeps the installed bundle open, so copying over a pane that is
# currently loaded would overwrite a bundle in use.
step "Quitting System Settings"
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
sleep 2

step "Installing into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BACKUP_DIR"
if [ -e "$INSTALL_DIR/$PANE" ]; then
	BAK="$BACKUP_DIR/$PANE.backup-$(date +%Y%m%d-%H%M%S)"
	mv "$INSTALL_DIR/$PANE" "$BAK"
	echo "previous version kept at: $BAK"
fi
cp -R "$BUILD_DIR/$PANE" "$INSTALL_DIR/$PANE"

step "Verifying"
lipo -info "$INSTALL_DIR/$PANE/Contents/MacOS/SwiftDefaultApps"
codesign --verify --strict "$INSTALL_DIR/$PANE" && echo "signature ok"
echo
echo "Installed. Open with:  open \"$INSTALL_DIR/$PANE\""
