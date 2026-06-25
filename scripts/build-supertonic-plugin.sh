#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_SRC="$ROOT_DIR/TypeWhisperPluginSDK/Plugins/SupertonicPlugin"
DIST_DIR="$ROOT_DIR/dist"
DIST_BASENAME="SupertonicReadSelectionPlugin"
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/supertonic-plugin-build.XXXXXX")"
TYPEWHISPER_REPO="${TYPEWHISPER_REPO_PATH:-$BUILD_ROOT/typewhisper-mac}"

cleanup() {
    rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

if [[ ! -d "$PLUGIN_SRC" ]]; then
    echo "Supertonic plugin source not found at $PLUGIN_SRC" >&2
    exit 1
fi

if [[ -z "${TYPEWHISPER_REPO_PATH:-}" ]]; then
    git clone --depth 1 --filter=blob:none --sparse https://github.com/SEBK4C/typewhisper-mac.git "$TYPEWHISPER_REPO"
    git -C "$TYPEWHISPER_REPO" sparse-checkout set TypeWhisperPluginSDK/Sources
elif [[ ! -d "$TYPEWHISPER_REPO/TypeWhisperPluginSDK/Sources/TypeWhisperPluginSDK" ]]; then
    echo "TYPEWHISPER_REPO_PATH must point at a typewhisper-mac checkout with TypeWhisperPluginSDK/Sources." >&2
    exit 1
fi

MIN_SDK="$BUILD_ROOT/TypeWhisperPluginSDK"
mkdir -p "$MIN_SDK/Sources"
cp -R "$TYPEWHISPER_REPO/TypeWhisperPluginSDK/Sources/TypeWhisperPluginSDK" "$MIN_SDK/Sources/"

cat > "$MIN_SDK/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeWhisperPluginSDK",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TypeWhisperPluginSDK", type: .dynamic, targets: ["TypeWhisperPluginSDK"]),
    ],
    targets: [
        .target(name: "TypeWhisperPluginSDK"),
    ]
)
PACKAGE

PACKAGE_DIR="$BUILD_ROOT/SupertonicReadSelectionStandalone"
TARGET_DIR="$PACKAGE_DIR/Sources/$DIST_BASENAME"
mkdir -p "$TARGET_DIR"
cp "$PLUGIN_SRC"/*.swift "$TARGET_DIR/"
cp "$PLUGIN_SRC/manifest.json" "$TARGET_DIR/"
cp "$PLUGIN_SRC/Localizable.xcstrings" "$TARGET_DIR/"

cat > "$PACKAGE_DIR/Package.swift" <<PACKAGE
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SupertonicReadSelectionStandalone",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "$DIST_BASENAME", type: .dynamic, targets: ["$DIST_BASENAME"]),
    ],
    dependencies: [
        .package(path: "$MIN_SDK"),
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager.git", from: "1.24.2"),
    ],
    targets: [
        .target(
            name: "$DIST_BASENAME",
            dependencies: [
                .product(name: "TypeWhisperPluginSDK", package: "typewhisperpluginsdk"),
                .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
            ],
            resources: [
                .process("Localizable.xcstrings"),
                .process("manifest.json"),
            ]
        ),
    ]
)
PACKAGE

swift build --package-path "$PACKAGE_DIR" -c release --product "$DIST_BASENAME"
BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" -c release --show-bin-path)"
PLUGIN_BINARY="$BIN_DIR/lib$DIST_BASENAME.dylib"

if command -v install_name_tool >/dev/null 2>&1; then
    install_name_tool \
        -change "@rpath/libTypeWhisperPluginSDK.dylib" \
        "@rpath/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK" \
        "$PLUGIN_BINARY"
fi

BUNDLE="$BUILD_ROOT/$DIST_BASENAME.bundle"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$PLUGIN_BINARY" "$BUNDLE/Contents/MacOS/$DIST_BASENAME"
cp "$PLUGIN_SRC/manifest.json" "$BUNDLE/Contents/Resources/manifest.json"
cp "$PLUGIN_SRC/Localizable.xcstrings" "$BUNDLE/Contents/Resources/Localizable.xcstrings"

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SupertonicReadSelectionPlugin</string>
    <key>CFBundleIdentifier</key>
    <string>com.sebk4c.typewhisper.tts.supertonic-read-selection.bundle</string>
    <key>CFBundleName</key>
    <string>SupertonicReadSelectionPlugin</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>SupertonicSelectionReaderPlugin</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true
fi

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$BUNDLE" >/dev/null 2>&1 || true
fi

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DIST_BASENAME.zip"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr -c -k --keepParent "$BUNDLE" "$DIST_DIR/$DIST_BASENAME.zip"
rm -rf "$DIST_DIR/$DIST_BASENAME.bundle"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr "$BUNDLE" "$DIST_DIR/$DIST_BASENAME.bundle"

if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$DIST_DIR/$DIST_BASENAME.bundle" >/dev/null 2>&1 || true
fi

echo "Built:"
echo "  $DIST_DIR/$DIST_BASENAME.zip"
echo "  $DIST_DIR/$DIST_BASENAME.bundle"
