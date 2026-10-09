# BG Pathfinding Redux 0.1.6-preview

Fixes allied movers becoming trapped when a character they already overlap
becomes neutral or hostile, for example after dismissal or charm.

## Changes

- Allow outward movement from an existing neutral/enemy overlap.
- Apply the same origin-aware exception to the pathfinder's private working map.
- Re-check current positions: after separation, normal neutral/enemy blocking resumes.
- Preserve walls, closed doors, unrelated blockers and occupancy validation.
- No new executable hook sites, live collision-map edits or teleporting.
- Existing settings survive reinstall. Escape uses the Movement setting.
- Enemy-to-enemy pass-through is not included in this release.

## Install or upgrade

Close the game. Extract **`bg-redux-movement-0.1.6-preview-windows.zip`** into the
game folder and install/reinstall component 0 using `setup-bg-redux-movement.exe`.
Launch through your EEex loader and retain `bg-redux-movement`. Reinstall after
game updates to refresh the game/version hint. Archived SoD requires DLC Merger
before EEex.

## Validation

The user confirmed both neutral and enemy overlap escape in personal Windows EET
on October 9, 2026. The change passes 652 actual-profile policy assertions and
1,555 private-map policy/adapter assertions, plus existing native-byte/layout and
startup fixtures for BG2EE/BGEE/SoD 2.6/2.7. These offline fixtures do not emulate
gameplay. No game was launched by the agent.

Existing platform compatibility remains as documented. This change has not had
an additional live retest on each profile. GOG gameplay and multiplayer remain
unvalidated. The previously recorded door-entry failure remains under investigation;
this release does not claim to fix it.

For problems, record with Left Ctrl+Left Shift+F7, reproduce within 20 seconds,
then run **`Collect BG Redux Support.cmd`** and send **`bg-redux-support.log`**.
Startup failures do not require a capture.

Verify the ZIP with `SHA256SUMS.txt`. Original code/docs are MIT; bundled WeiDU
retains GPL-2.0 with corresponding source.
