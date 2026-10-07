# BG Pathfinding Redux 0.1.2-preview

Public naming and logging cleanup for the confirmed Windows BG2EE 2.6.6.0 /
EEex 1.2.0 and Steam BG2EE 2.7.3.0 / EEex 1.3.0 profiles. Native assembly,
signature tables, movement rules and tuning are unchanged.

## Install

Download `bg-redux-movement-0.1.2-preview-windows.zip`, close the game, and extract
beside `Baldur.exe`. Run `setup-bg-redux-movement.exe`, install component 0, and
launch through `InfinityLoader.exe`. Keep the `bg-redux-movement` folder.
Settings live in `bg-redux-movement.ini`; the installed selector is
`override/M_BGREDX.lua`. Automatic source archives lack the installer.

## Upgrade from 0.1.0/0.1.1

Uninstall the old component using `setup-mrdx-movement.exe` first. Keep
`mrdx-movement.ini`: the new installer copies it when the new settings file is
absent. Existing `bg-redux-movement.ini` choices take priority. The installer
refuses an installed legacy component or a remaining `override/M_MRIP.lua`.
For a manually installed prototype, back up and remove its old overlay first.
Do not delete WeiDU-managed files instead of uninstalling.

## Quiet normal play

Compact startup/status/error entries use `[BG Redux]`. Routine actor, path and
settle telemetry is hidden outside requested captures. Automatic activation adds
no chat instructions. Manual feature toggles still confirm their state.

Hold Left Ctrl + Left Shift: F6 movement, F5 attack spacing, F4 gentle settle,
F3 visual preference. F7 starts a 20-second diagnostic capture, F8 snapshots,
and F9 ends recording. All four features default ON; existing preferences persist.

## Scope and validation

Both integrated native profile fixtures, configuration/selector/quiet-logging
checks and real WeiDU install/rollback/migration/refusal labs pass. These checks
do not emulate gameplay; live acceptance belongs to the earlier tested profiles.
No game launch or installed-game changes were performed for this cleanup.

Known profiles select automatically. Unknown builds refuse safely before mod
hooks; future patches still require a reviewed profile and compatible EEex.
Single player only. EET gameplay, other storefront 2.7 executables, multiplayer,
Wine/Proton and CrossOver remain unvalidated. See compatibility and validation docs.

Verify the Windows ZIP against `SHA256SUMS.txt`. Original code/docs are MIT licensed,
copyright (c) 2026 Zach Hopkins. Bundled WeiDU retains GPL-2.0 and includes source.
