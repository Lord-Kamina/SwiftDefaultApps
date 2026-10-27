#!/usr/bin/env bash
#
# Build, sign and install SwiftDefaultApps into ~/Applications.
#
#   ./build.sh                 build, sign, install
#   ./build.sh --no-install    build and sign only
#   ./build.sh --cli           also build the "swda" command line tool
#
# Environment overrides:
#   SIGN_ID="..."              signing identity ("-" for ad-hoc)
#   ARCH="arm64"               narrow the build (default: universal)
#   DEPLOY_TARGET="13.0"       minimum macOS version

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$REPO/build/Release"
BACKUP_DIR="$REPO/backups"
INSTALL_DIR="$HOME/Applications"
APP="SwiftDefaultApps.app"

SWIFTCLI_DIR="$REPO/Packages/SwiftCLI-2.0.3"
SWIFTCLI_URL="https://github.com/Lord-Kamina/SwiftCLI.git"
SWIFTCLI_TAG="2.0.3+swift5"

ARCH="${ARCH:-arm64 x86_64}"
DEPLOY_TARGET="${DEPLOY_TARGET:-13.0}"

DO_INSTALL=1
DO_CLI=0
for arg in "$@"; do
	case "$arg" in
		--no-install) DO_INSTALL=0 ;;
		--cli)        DO_CLI=1 ;;
		-h|--help)    sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
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
step "Building app ($ARCH, deployment target $DEPLOY_TARGET)"
xcodebuild -project "$REPO/SwiftDefaultApps.xcodeproj" \
	-target SwiftDefaultApps \
	-configuration Release \
	ARCHS="$ARCH" ONLY_ACTIVE_ARCH=NO \
	MACOSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
	CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" \
	2>&1 | sed -nE '/^\/.*(error|warning):|^\*\* BUILD/p'

[ -d "$BUILD_DIR/$APP" ] || { echo "build product missing: $BUILD_DIR/$APP" >&2; exit 1; }

if [ "$DO_CLI" = 1 ]; then
	step "Building CLI"
	xcodebuild -project "$REPO/SwiftDefaultApps CLI.xcodeproj" \
		-target SwiftDefaultApps \
		-configuration Release \
		ARCHS="$ARCH" ONLY_ACTIVE_ARCH=NO \
		MACOSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" \
		2>&1 | sed -nE '/^\/.*(error|warning):|^\*\* BUILD/p'
	echo "CLI built at: $BUILD_DIR/swda"
fi

# ----------------------------------------------------------------------- sign
# Nested bundles must be signed before the enclosing one.
step "Signing"
codesign --force --options runtime "${TS_FLAG[@]}" --sign "$SIGN_ID" \
	"$BUILD_DIR/$APP/Contents/Resources/ThisAppDoesNothing.app"
codesign --force --options runtime "${TS_FLAG[@]}" --sign "$SIGN_ID" \
	"$BUILD_DIR/$APP"

codesign --verify --deep --strict "$BUILD_DIR/$APP" && echo "signature verified"
codesign -dv "$BUILD_DIR/$APP" 2>&1 | grep -E '^(Identifier|Format)='
lipo -info "$BUILD_DIR/$APP/Contents/MacOS/SwiftDefaultApps"

if [ "$DO_INSTALL" = 0 ]; then
	step "Done (not installed)"
	echo "$BUILD_DIR/$APP"
	exit 0
fi

# -------------------------------------------------------------------- install
step "Quitting SwiftDefaultApps"
if pgrep -x SwiftDefaultApps >/dev/null; then
	osascript -e 'quit app id "cl.fail.lordkamina.SwiftDefaultApps"'
	sleep 2
fi

step "Installing into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BACKUP_DIR"
if [ -e "$INSTALL_DIR/$APP" ]; then
	BAK="$BACKUP_DIR/$APP.backup-$(date +%Y%m%d-%H%M%S)"
	mv "$INSTALL_DIR/$APP" "$BAK"
	echo "previous version kept at: $BAK"
fi
cp -R "$BUILD_DIR/$APP" "$INSTALL_DIR/$APP"

step "Verifying"
lipo -info "$INSTALL_DIR/$APP/Contents/MacOS/SwiftDefaultApps"
codesign --verify --deep --strict "$INSTALL_DIR/$APP" && echo "signature ok"
echo
echo "Installed. Open with:  open \"$INSTALL_DIR/$APP\""
