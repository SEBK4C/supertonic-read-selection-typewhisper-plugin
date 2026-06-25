# Codex Cheat Sheet: TypeWhisper Plugins

This note is for future Codex sessions working on standalone TypeWhisper plugins.
It captures the practical steps and sharp edges discovered while building
Supertonic Read Selection.

## Goal Shape

A user-installable TypeWhisper plugin should ship as a ZIP containing one
macOS `.bundle`:

```text
SupertonicReadSelectionPlugin.zip
└── SupertonicReadSelectionPlugin.bundle
    └── Contents
        ├── Info.plist
        ├── MacOS/SupertonicReadSelectionPlugin
        └── Resources/manifest.json
```

Users install the ZIP from TypeWhisper's Integrations screen with Install
Plugin. The `~/Library/Application Support/TypeWhisper/Plugins` directory is
the installed destination, not the file users should pick in the installer.

## Repository Layout

Important paths in this repo:

- `TypeWhisperPluginSDK/Plugins/SupertonicPlugin/*.swift`: plugin source
- `TypeWhisperPluginSDK/Plugins/SupertonicPlugin/manifest.json`: TypeWhisper manifest
- `scripts/build-supertonic-plugin.sh`: builds the distributable ZIP and bundle
- `scripts/install-supertonic-read-selection.sh`: local direct installer for development
- `.github/workflows/release.yml`: builds the release ZIP on tag push
- `docs/screenshots/settings.png`: screenshot included in release notes

## Manifest Rules

Use a unique plugin ID. Do not reuse a built-in TypeWhisper marketplace ID.

Current working values:

```json
{
  "id": "com.sebk4c.typewhisper.tts.supertonic-read-selection",
  "name": "Supertonic Read Selection",
  "principalClass": "SupertonicSelectionReaderPlugin",
  "category": "tts",
  "categories": ["tts", "action"],
  "hosting": "local"
}
```

The `principalClass` must match the Objective-C runtime class exported by the
Swift plugin class:

```swift
@objc(SupertonicSelectionReaderPlugin)
public final class SupertonicPlugin: NSObject, TypeWhisperPlugin {
    ...
}
```

If TypeWhisper says `Failed to find class ...`, it may mean either:

- `NSClassFromString(manifest.principalClass)` returned nil, or
- the class exists but does not cast to `TypeWhisperPlugin.Type` because it was
  linked against a different copy of `TypeWhisperPluginSDK`.

## Build Rules

The standalone build should compile the plugin product as
`SupertonicReadSelectionPlugin`, but it should not embed its own private
`libTypeWhisperPluginSDK.dylib`.

TypeWhisper loads plugins against the framework inside the app:

```text
@rpath/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK
```

The build script handles this with `install_name_tool`:

```sh
install_name_tool \
  -change "@rpath/libTypeWhisperPluginSDK.dylib" \
  "@rpath/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK" \
  "$PLUGIN_BINARY"
```

Build locally:

```sh
scripts/build-supertonic-plugin.sh
```

If a TypeWhisper checkout already exists, avoid another sparse clone:

```sh
TYPEWHISPER_REPO_PATH=/path/to/typewhisper-mac scripts/build-supertonic-plugin.sh
```

SwiftPM may need normal user cache access and network access for ONNX runtime
packages. In Codex, that can require an escalated command.

## Local Install

For development, build first, then install directly:

```sh
scripts/build-supertonic-plugin.sh
scripts/install-supertonic-read-selection.sh
```

The installer copies the bundle to:

```text
~/Library/Application Support/TypeWhisper/Plugins/SupertonicReadSelectionPlugin.bundle
```

It also writes:

```text
defaults write com.typewhisper.mac \
  plugin.com.sebk4c.typewhisper.tts.supertonic-read-selection.enabled \
  -bool true
```

After installing or changing class names, fully quit TypeWhisper with Cmd-Q and
reopen it. Closing the window is not enough; Swift/Objective-C classes from
loaded bundles can stick around for the life of the app process.

## Verification Commands

Check manifest and Info.plist:

```sh
rg -n "principalClass|SupertonicSelectionReaderPlugin" \
  dist/SupertonicReadSelectionPlugin.bundle/Contents/Resources/manifest.json

plutil -p dist/SupertonicReadSelectionPlugin.bundle/Contents/Info.plist
```

Check SDK linkage:

```sh
otool -L dist/SupertonicReadSelectionPlugin.bundle/Contents/MacOS/SupertonicReadSelectionPlugin
```

Expected TypeWhisper SDK line:

```text
@rpath/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK
```

Smoke-test class lookup against the installed TypeWhisper app framework:

```sh
swift -module-cache-path /private/tmp/sst-swift-module-cache -e 'import Foundation; import Darwin; let sdk = "/Applications/TypeWhisper.app/Contents/Frameworks/TypeWhisperPluginSDK.framework/Versions/A/TypeWhisperPluginSDK"; guard dlopen(sdk, RTLD_NOW | RTLD_GLOBAL) != nil else { print(String(cString: dlerror())); exit(1) }; let url = URL(fileURLWithPath: "/Users/sebastian/Documents/SST/dist/SupertonicReadSelectionPlugin.bundle"); guard let bundle = Bundle(url: url) else { fatalError("no bundle") }; do { try bundle.loadAndReturnError(); print("loaded"); print(NSClassFromString("SupertonicSelectionReaderPlugin") as Any); print(NSClassFromString("SupertonicReadSelectionPlugin") as Any) } catch { print("load failed: \(error)"); exit(1) }'
```

Expected output:

```text
loaded
Optional(SupertonicReadSelectionPlugin.SupertonicPlugin)
nil
```

The old `SupertonicReadSelectionPlugin` class should be nil because the unique
runtime class is `SupertonicSelectionReaderPlugin`.

Verify the installable ZIP by extracting it to `/private/tmp` and checking the
extracted bundle:

```sh
mkdir -p /private/tmp/supertonic-zip-verify
ditto -x -k dist/SupertonicReadSelectionPlugin.zip /private/tmp/supertonic-zip-verify
codesign --verify --deep --strict --verbose=2 \
  /private/tmp/supertonic-zip-verify/SupertonicReadSelectionPlugin.bundle
```

Finder and file-provider xattrs can appear on bundles under `Documents`; the
installed copy and ZIP-extracted copy are the important ones to verify.

## Common Failure Modes

No Settings button or disabled checkbox:

- Check for ID collision with a built-in plugin.
- Confirm the manifest category/categories include the right capabilities.
- Confirm the plugin is enabled in defaults.
- Restart TypeWhisper after install.

`Failed to find class ...`:

- Confirm `manifest.json` and `Info.plist` use the same principal class.
- Confirm the Swift class has matching `@objc(...)`.
- Confirm the binary links to TypeWhisper's SDK framework, not a bundled SDK dylib.
- Use a new unique principal class if TypeWhisper may have cached an older one.

User picks a bundle from Application Support and gets "file could not be opened":

- Tell them to install the release ZIP from TypeWhisper's Install Plugin button.
- Application Support is the destination folder, not the release source.

## Release Flow

Before tagging, put the settings screenshot here:

```text
docs/screenshots/settings.png
```

Commit changes, then tag and push:

```sh
git tag -a vX.Y.Z -m "Supertonic Read Selection vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

The release workflow builds on macOS and attaches:

```text
dist/SupertonicReadSelectionPlugin.zip
```

If moving a local-only tag before it has been pushed:

```sh
git tag -d v1.0.0
git tag -a v1.0.0 -m "Supertonic Read Selection v1.0.0"
```

If the tag has already been pushed, be careful: moving published tags can
confuse users and release automation.
