# Installation and troubleshooting

## Before installing

Tested setups are Windows BG2EE 2.6.6.0 / EEex 1.2.0 and Windows Steam
BG2EE 2.7.3.0 / EEex 1.3.0, and Steam BGEE/SoD 2.6.6.0 and 2.7.3.0 / EEex 1.3.0. See `profiles.json` for exact executable hashes.
For archived Steam/GOG SoD DLC, install DLC Merger before EEex.
Install EEex and close both the game and its loader before changing files.
EET is accepted by the installer, but its gameplay validation remains pending.
This preview does not support multiplayer.

## Install or upgrade

Extract the release's Windows installer ZIP into the game directory, beside
your game executable (`Baldur.exe`, `BaldurII.exe`, or `SiegeOfDragonspear.exe`). Keep `setup-bg-redux-movement.exe` and the `bg-redux-movement` folder together.
Run the installer and choose component 0. Launch using `InfinityLoader.exe`.

For **0.1.2 and later**, use WeiDU's normal reinstall flow. Existing
`bg-redux-movement.ini` choices are preserved, so an older OFF choice stays OFF.

### Upgrading from 0.1.0/0.1.1 or the prototype

1. Close the game. Run the previous `setup-mrdx-movement.exe` and uninstall
   component 0 before installing the newly named package.
2. Keep `mrdx-movement.ini`. When `bg-redux-movement.ini` is absent, the new
   installer copies your previous settings into it. An existing new settings
   file takes priority. Both files survive uninstall.
3. Install component 0 using `setup-bg-redux-movement.exe`.

The installer refuses an installed old component or a lingering
`override/M_MRIP.lua`. For a manually copied prototype, back up and remove that
old overlay after closing the game. Do not delete WeiDU-managed files in place of
uninstalling their component. The duplicate-load guard is a second safeguard;
it does not replace removing the old installation.

Keep the entire `bg-redux-movement` folder: it holds all four runtime profiles.
The installed selector is `override/M_BGREDX.lua`.

## Uninstall

Close the game, run `setup-bg-redux-movement.exe`, and remove component 0. WeiDU
restores a prior movement overlay if one existed, or removes the new overlay.
`bg-redux-movement.ini` remains so preferences survive a later reinstall. You can
remove that configuration file manually after uninstall if desired.

## Settings

```ini
[Movement]
Movement=1
AttackSpacing=1
GentleSettle=1
RoutePreference=1
```

Edit with the game closed and restart, or use Left Ctrl + Left Shift + F3–F6.
Invalid or missing values use the runtime's fallback defaults: movement, attack
spacing, and settle ON; route preference OFF. The installer supplies the explicit
ON route-preference value for fresh installations.

## Reporting a problem

Press Left Ctrl + Left Shift + F7, reproduce a movement issue within 20 seconds,
then double-click `Collect BG Redux Support.cmd` in the game folder. Send
`bg-redux-support.log` and reproduction steps. Collect before restarting when
possible. Startup failures do not require recording. See [support details](SUPPORT.md).

Installation enables `bg-redux-runtime.log` when the loader log setting is blank;
an existing custom path is preserved. Uninstall restores the prior loader INI.

| Symptom | First check |
| --- | --- |
| Installer says “SKIPPING” | Read the printed reason. Installation requires BGEE/SoD/BG2EE/EET and EEex. Unknown hashes/headers and custom filenames warn; a likely profile is tried with native checks. |
| Game starts but no allied passage | Launch through InfinityLoader; check F6 state and startup/refusal messages. |
| An optional feature is unavailable | Inspect the log's signature/layout/backend refusal; do not remove the guard. |
| Visual preference seems subtle | It is bounded and may retain the native route. It is not continuous steering or guaranteed lanes. |
| A stopped idle stack remains overlapped after F4 | Arrival normally triggers settle. Enabling it on an already idle stack does not guarantee enrollment. |
| Feature disabled after an error | Preserve the log and report it. Session error guards do not silently rewrite saved settings. |

To isolate a reported problem, turn optional features off independently and
compare the same scene. A vanilla comparison should use a separate game copy
or a deliberate uninstall, rather than casually deleting an active overlay.

## Game updates

One package contains four verified profiles, and the selector rechecks the
executable each startup. Switching between the supported 2.6 and Steam 2.7 builds
does not require manually swapping mod runtimes, provided EEex supports the build.

An unfamiliar header prints `COMPATIBILITY_WARNING` and tries a likely existing
profile. Matching entrypoint/image size takes priority; otherwise the installer
hint supplies the game family and a 2.6/2.7 candidate. It follows EEex's detection:
`GAME_IS` plus `data/PATCH27.BIF`. Reinstall after updates to refresh this hint.

Executable hashes and standard game/launcher filenames are advisory. Native
instruction/layout mismatches still disable the affected hooks/features. A missing
EEex backend, invalid architecture/header, or absence of any candidate remains a
real activation failure. Saved preferences are preserved. Native checks do not
establish comprehensive compatibility with every executable edit.

Keep EEex current; an incompatible loader can fail before this mod runs. Steam
may also replace installed game/mod files during updates or verification. Reinstall
EEex and this mod if their files are replaced. Report the new version and executable
hash so a matching profile can be audited. Do not bypass native guards to force it.
