# BG Pathfinding Redux 0.1.4-preview

Adds user-confirmed Windows Steam BGEE and Siege of Dragonspear **2.6.6.0 and
2.7.3.0** with EEex 1.3.0, alongside the accepted BG2EE 2.6.6.0 and Steam 2.7.3.0
profiles. Includes easy, single-file community diagnostics.

## Changes

- Add BGEE/SoD profiles 55 and 56 with relocated native addresses.
- Correct the lazy gentle-settle Stop guard in both 2.7 profiles.
- Warn and continue installation on an unfamiliar full executable hash.
  Recognized startup headers and native signature/layout guards remain required.
- Add **`Collect BG Redux Support.cmd`**, which creates **`bg-redux-support.log`**
  with versions/hashes, package/profile metadata, settings, mods, and bounded logs.
- Add area/creature and package/profile context to requested snapshots.
- Enable loader logging when its existing setting is blank; preserve custom paths
  and restore the previous loader INI on uninstall. No automatic uploads.
- Retain movement policy and feature defaults; verbose recording remains opt-in.

## Install or upgrade

For archived Steam/GOG SoD DLC, install DLC Merger first, then EEex. Close the
game, extract **`bg-redux-movement-0.1.4-preview-windows.zip`** beside `Baldur.exe`,
and install/reinstall component 0 using `setup-bg-redux-movement.exe`. Launch
through `InfinityLoader.exe` and retain the `bg-redux-movement` folder. Existing
settings survive reinstall. Upgrades from 0.1.0/0.1.1 require uninstalling the old
named component first.

Movement, attack spacing, gentle settle and optional visual preference default ON.
Normal play keeps compact startup/status/errors; recording is OFF.

## Reporting an issue

Hold Left Ctrl + Left Shift, press F7, and reproduce a movement issue within
20 seconds. Then double-click **`Collect BG Redux Support.cmd`** and send
**`bg-redux-support.log`** with a short description. Collect before restarting
when possible. Startup failures do not need a capture. Review the report before
sharing: character/mod names may appear. Saves and crash dumps are excluded.

## Validation and scope

BG1/SoD acceptance is user-reported, including the corrected 2.7 settle retest.
Offline checks cover relocated engine functions/references, native guards and
bindings, assembly expansion, restricted-Lua selection, real executable bytes
with preference OFF/ON, lazy settle initialization, real WeiDU install/rollback,
and collector fixtures. These checks do not emulate gameplay or launch the game.

Hash warnings do not certify arbitrary executable patches or support new
versions automatically. Other storefront builds, EET gameplay, multiplayer,
long campaign stability, and Wine/Proton/CrossOver remain unvalidated.

Verify the ZIP with **`SHA256SUMS.txt`**. Original code/docs are MIT; bundled
WeiDU retains GPL-2.0 with corresponding source.
