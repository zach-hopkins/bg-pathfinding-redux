# BG Pathfinding Redux 0.1.3-preview

Fixes the startup error `M_BGREDX.lua:25: attempt to index global 'io' (a nil value)`
in the public version selector. The game's Lua environment does not expose the I/O
library that the previous offline harness assumed. The corrected selector uses
EEex memory reads of the loaded executable header and contains loading failures.
Both movement profiles, native hooks, settings and tuning are unchanged from 0.1.2.

## Install or upgrade

Close the game, extract `bg-redux-movement-0.1.3-preview-windows.zip` beside
`Baldur.exe`, and install/reinstall component 0 using `setup-bg-redux-movement.exe`.
Launch through `InfinityLoader.exe`; keep the `bg-redux-movement` folder.
Existing settings survive reinstall. Upgrades from 0.1.0/0.1.1 still require
uninstalling the old component with `setup-mrdx-movement.exe` first; legacy settings
are copied only when the new settings file is absent. See installation instructions.

## Checks and scope

Both supported executable profiles pass integrated offline checks with `io=nil`,
including actual executable header/native bytes and visual preference OFF/ON.
206 selector assertions cover known identities, malformed/unknown headers,
missing APIs, missing/failing loaders and duplicate loading. Configuration and
quiet-log checks pass. These checks do not emulate gameplay. Live startup of this
hotfix remains pending tester confirmation; no agent game launch was performed.

Supported profiles remain Windows BG2EE 2.6.6.0 / EEex 1.2.0 and Steam BG2EE
2.7.3.0 / EEex 1.3.0. Unknown header identities refuse safely; exact installer hashes
and native guards remain. The selected package version is in `PROFILE_SELECTED`;
unchanged profile readiness messages retain their earlier payload version.

Normal play keeps compact startup/status/errors; detailed telemetry is requested
with Left Ctrl + Left Shift + F7/F8/F9. Movement defaults ON and F6 toggles it.
Single player only; EET gameplay, other storefront builds, multiplayer and
Wine/Proton/CrossOver remain unvalidated. Verify the ZIP with `SHA256SUMS.txt`.
Original code/docs are MIT licensed; bundled WeiDU retains GPL-2.0 with source.
