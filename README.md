# Supertonic Read Selection TypeWhisper Plugin

This workspace contains a self-contained Supertonic plugin package copied from `SEBK4C/typewhisper-mac` and modified so it can read the currently selected text aloud from its own keyboard shortcut. It uses a standalone plugin ID so it does not collide with TypeWhisper's first-party Supertonic marketplace entry.

## Release Download

For normal installation, download `SupertonicReadSelectionPlugin.zip` from a GitHub release. Do not unzip it first.

## Build

```sh
scripts/build-supertonic-plugin.sh
```

The script builds a standalone macOS plugin bundle and writes both installable forms:

- `dist/SupertonicReadSelectionPlugin.zip`
- `dist/SupertonicReadSelectionPlugin.bundle`

If you already have a local checkout of TypeWhisper, you can avoid the script's temporary GitHub clone:

```sh
TYPEWHISPER_REPO_PATH=/path/to/typewhisper-mac scripts/build-supertonic-plugin.sh
```

## Install

In TypeWhisper, open the plugin screen and use the Install Plugin button in the upper-right corner. Select `dist/SupertonicReadSelectionPlugin.zip`, then enable the plugin. Do not select a copy from `~/Library/Application Support/TypeWhisper/Plugins`; that folder is the installed destination TypeWhisper scans after installation.

If you previously installed `dist/SupertonicPlugin.zip`, uninstall that old card first. It reused TypeWhisper's built-in Supertonic plugin ID and can appear as a Marketplace item without the standalone settings panel.

If the plugin appears as a disabled manual plugin and the checkbox does not stay enabled, install it directly and pre-enable the standalone plugin ID:

```sh
scripts/install-supertonic-read-selection.sh
```

Then restart TypeWhisper.

Open the plugin settings to accept the Supertonic 3 model license, download the model assets, choose a voice, and record the Read Selection Shortcut.

## Performance

Supertonic Read Selection can optionally run ONNX Runtime through Core ML with CPU and GPU compute units on Apple silicon Macs. Enable Use Mac GPU (Core ML) in the plugin settings to try the accelerated backend. If Core ML cannot load the model, the plugin falls back to CPU inference.

For long selections, the plugin splits text into paragraph and sentence-aware chunks, prioritizes the first utterance, then streams each synthesized chunk to one serialized player as soon as it finishes. Chunks are inferred one at a time in streaming mode to reduce pauses after the first sentence and to prevent overlapping playback.

Playback speed is handled by the audio player, separate from the model generation speed. Advanced Audio settings expose pitch, time-stretch overlap, low-pass cleanup, resonance cut, clarity shelf, and sibilance-taming EQ controls. Optional expression-tag settings can insert the confirmed Supertonic tags `<laugh>`, `<breath>`, and `<sigh>`.

## Release

Add a screenshot at `docs/screenshots/settings.png` if you want it included in the GitHub release notes, then tag the release:

```sh
git tag v1.2.0
git push origin main
git push origin v1.2.0
```

The GitHub Actions release workflow builds `dist/SupertonicReadSelectionPlugin.zip` on macOS and attaches it to the release.

## Future Development

Future Codex sessions should read `docs/CODEX_TYPEWHISPER_PLUGIN_CHEATSHEET.md` before changing packaging, manifests, principal classes, or release automation.

## Read-Aloud Behavior

The plugin listens for the configured shortcut directly. Pick a shortcut that does not conflict with the apps you use most often, because the plugin observes the shortcut globally but does not reserve it away from the foreground app. When triggered, it first asks macOS Accessibility for the focused app's selected text. If that is unavailable, it briefly sends Command-C, reads the copied text, and restores your clipboard snapshot.

Pressing the shortcut again stops the active Supertonic playback. TypeWhisper needs macOS Accessibility permission for selection access and the copy fallback.
