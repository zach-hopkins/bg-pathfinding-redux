# Installation and troubleshooting

## Before installing

Use the Windows BG2EE 2.6.6.0 executable and EEex 1.2.0 for the tested setup.
Install EEex first and close both the game and its loader before changing files.
EET is accepted by the installer, but its gameplay validation remains pending.
This preview does not support multiplayer.

## Install or upgrade

Extract the release's Windows installer ZIP into the game directory, beside
`Baldur.exe`. Keep `setup-mrdx-movement.exe` and the `mrdx-movement` folder together.
Run the installer and choose component 0. Launch using `InfinityLoader.exe`.

If an older package is installed, use WeiDU's normal reinstall flow. Existing
`mrdx-movement.ini` choices are preserved, so an older OFF choice stays OFF.
The package supplies ON defaults only when that settings file is absent.

Do not install a separate renamed prototype overlay alongside this package.
The runtime uses the existing `override/M_MRIP.lua` name and a duplicate-load guard.

## Uninstall

Close the game, run `setup-mrdx-movement.exe`, and remove component 0. WeiDU
restores a prior movement overlay if one existed, or removes the new overlay.
`mrdx-movement.ini` remains so preferences survive a later reinstall. You can
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

Include the game/EEex version, mod version, executable SHA256 if available,
`WeiDU.log`, and clear reproduction steps. If safe to reproduce, start a capture
with Left Ctrl + Left Shift + F7, reproduce within 20 seconds, and end with F9.
F8 adds a snapshot. Captures expire automatically after 20 seconds.

The output log location is configured by your `InfinityLoader.ini`; it is not
necessarily named `MRIP-prototype.log`. Look for `[MRIP prototype]` entries,
`LOADED revision=53`, and `RELEASE_READY` mode values. The historical log prefix
is retained in the accepted runtime. Review logs before sharing: filenames,
character names, or other details may be personal. Attach a save only when useful.

| Symptom | First check |
| --- | --- |
| Installer says “SKIPPING” | Confirm this package is used; its predicate accepts both BG2EE and EET. BGEE/IWDEE are excluded. |
| Game starts but no allied passage | Launch through InfinityLoader; check F6 state and startup/refusal messages. |
| An optional feature is unavailable | Inspect the log's signature/layout/backend refusal; do not remove the guard. |
| Visual preference seems subtle | It is bounded and may retain the native route. It is not continuous steering or guaranteed lanes. |
| A stopped idle stack remains overlapped after F4 | Arrival normally triggers settle. Enabling it on an already idle stack does not guarantee enrollment. |
| Feature disabled after an error | Preserve the log and report it. Session error guards do not silently rewrite saved settings. |

To isolate a reported problem, turn optional features off independently and
compare the same scene. A vanilla comparison should use a separate game copy
or a deliberate uninstall, rather than casually deleting an active overlay.
