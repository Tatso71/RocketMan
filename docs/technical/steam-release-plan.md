# RocketMan Steam Release Technical Plan

Date: 2026-05-12
Status: Early technical baseline

## Release Target

RocketMan is expected to release on Steam. The first technical target should be:

- Windows desktop build
- Linux x86_64 build for Steam Deck and Linux users
- Controller-first gameplay support
- Steam Auto-Cloud-compatible save files

Steamworks SDK integration is not required for the current vertical slice. Add it later only when the project needs achievements, stats, overlay checks, Steam Input API, rich presence, or Cloud API control.

## Steam Build Strategy

Use Godot export presets for:

- `Windows Desktop`
- `Linux/X11`

The Godot export config belongs in `export_presets.cfg` once export templates are installed. That file can be committed. Do not commit `.godot/export_credentials.cfg`.

Recommended build folder layout:

```text
builds/
  windows/
    RocketMan.exe
    RocketMan.pck
  linux/
    RocketMan.x86_64
    RocketMan.pck
steam/
  content/
  scripts/
  output/
```

Keep SteamPipe scripts out of Godot runtime code. Steam upload automation should live in `steam/scripts/` once an AppID and DepotIDs exist.

## Steam Cloud

Initial plan: use Steam Auto-Cloud.

RocketMan should write progression saves under Godot `user://saves/` and settings under `user://config/`.

Cloud sync should include:

- save files
- progression files

Cloud sync should exclude:

- graphics settings
- audio settings, unless desired
- logs
- crash dumps
- local editor files

When the Steam AppID exists, configure Steam Auto-Cloud root paths against the exported game's save directory. Test on Windows first, then verify cross-platform behavior for Linux/Steam Deck.

## Steam Deck Readiness

To target a good Steam Deck review outcome:

- All core gameplay must be available on controller.
- No required mouse-only or keyboard-only interactions.
- UI text must be readable at 1280x800.
- The game must not require a launcher.
- Prompts should show controller glyphs when a controller is active.
- The game should support pause/resume cleanly.
- Saves should be small and syncable.

Current project baseline already includes gamepad bindings for movement, jump, interact, journal, and pause.

## Direct Steamworks Integration Later

Consider adding a Steam adapter only when one of these becomes necessary:

- Achievements
- Stats
- Steam Input API glyphs and action sets
- Rich Presence
- Steam Cloud API instead of Auto-Cloud
- Overlay status checks

Suggested future structure:

```text
scripts/platform/
  platform_services.gd
  steam_services.gd
  local_services.gd
```

Game code should call a neutral `PlatformServices` interface instead of calling Steam APIs directly.

## Build And Release Checklist

- Install Godot export templates matching engine version.
- Add Windows and Linux export presets.
- Build Windows release locally.
- Build Linux release locally.
- Test Windows build outside the editor.
- Test Linux build, ideally on Steam Deck or a Linux VM.
- Configure Steam app, depots, launch options, and packages.
- Upload preview SteamPipe build.
- Test branch install through Steam client.
- Configure Steam Auto-Cloud.
- Test Cloud upload/download across two machines.
- Request Steam Deck review when the game is stable enough.

## References

- Godot export projects: https://docs.godotengine.org/en/latest/tutorials/export/exporting_projects.html
- SteamPipe uploading: https://partner.steamgames.com/doc/sdk/uploading
- Steam Cloud: https://partner.steamgames.com/doc/features/cloud
- Steam Deck compatibility: https://partner.steamgames.com/doc/steamdeck/compat
