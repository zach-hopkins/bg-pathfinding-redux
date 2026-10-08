# BG Pathfinding Redux 0.1.5-preview

Makes compatibility permissive for storefront variants and modified executables.
Movement behavior and the four existing native profiles are unchanged.

## Changes

- Accept GOG's `BaldurII.exe` and `SiegeOfDragonspear.exe` in installation and support collection.
- Custom game or EEex launcher filenames now warn instead of preventing installation.
- Unfamiliar hashes and PE headers are advisory. Startup tries the likely existing
  profile using matching entrypoint/image size or an installer game/version hint.
- Generate that hint using EEex's game-family and `data/PATCH27.BIF` detection.
- Keep checks for actual native instruction/layout mismatches, missing EEex APIs,
  invalid architecture, and conflicting old movement installations.
- Record candidate-selection provenance, alternate file hashes, and the installer
  hint in diagnostics. Existing settings survive reinstall.

## Install or upgrade

Close the game. Extract **`bg-redux-movement-0.1.5-preview-windows.zip`** into the
game folder and install/reinstall component 0 using `setup-bg-redux-movement.exe`.
Launch through your EEex loader. Retain `bg-redux-movement`. Reinstall after game
updates to refresh the game/version hint. Archived SoD requires DLC Merger before EEex.

## Validation

All four known BG2EE/BGEE/SoD 2.6/2.7 profiles pass native-byte fixtures with
preference OFF/ON and unfamiliar-header activation. Selector tests cover 442
assertions, including malformed hints and retained native refusal. Real WeiDU
fixtures verify alternate/custom executable names, a renamed launcher, hint
installation/rollback, and settings/log preservation. Support collector tests pass.

**GOG gameplay confirmation is pending.** This removes the filename/header
rejection; it does not claim a live test of the GOG executable. Native checks
remain active, but passing them is not comprehensive validation of arbitrary edits.
No game was launched by the agent.

For problems, record with Left Ctrl+Left Shift+F7, reproduce within 20 seconds,
then run **`Collect BG Redux Support.cmd`** and send **`bg-redux-support.log`**.
Collect before restarting when possible; startup failures do not need a capture.

Verify the ZIP with `SHA256SUMS.txt`. Original code/docs are MIT; bundled WeiDU
retains GPL-2.0 with corresponding source.
