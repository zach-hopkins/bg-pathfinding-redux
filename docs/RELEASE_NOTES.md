# BG Pathfinding Redux 0.1.7-preview

Adds optional **enemy cooperation**: enemies can pass through their own side and
prefer separate melee approach positions. **Default OFF**, toggled with
**Left Ctrl+Left Shift+F2**; the choice is saved across launches.

## Changes

- Applies to normal-sized enemies with matching hostile allegiance. Party,
  neutrals, different allegiance groups, larger creatures, terrain and doors
  remain blockers. Known current attack targets are also retained as blockers.
- Enemy approach points are reserved separately. When frontage is occupied,
  enemies may wait briefly (up to 600 ms), then return to native behavior.
  Overlap can still occur; this is an experimental allegiance-based option.
- Requires allied movement and attack spacing ON. Core allied traversal remains
  unchanged. No additional native hooks or on-disk executable edits.
- F2–F5 choices persist in the game-folder INI, independently of saves.
  F6 allied movement is session-only and starts ON each launch; legacy saved
  `Movement=0` is ignored.
- Correct the WeiDU game predicate for BGEE/SoD content detection.
- Include a concise [hotkey guide](../bg-redux-movement/QUICKSTART.md) in the ZIP.

## Install or upgrade

Close the game. Extract **`bg-redux-movement-0.1.7-preview-windows.zip`** into the
game folder and install/reinstall component 0 using `setup-bg-redux-movement.exe`.
Launch through your EEex loader and retain the `bg-redux-movement` folder.
Existing optional settings survive reinstall; enemy cooperation defaults OFF
when no saved choice exists. Archived SoD requires DLC Merger before EEex.

## Validation

The user accepted enemy doorway/open approaches in the dedicated Windows BG2EE
2.6.6.0 test copy. Four-profile offline verification checks real executable bytes
and layouts plus simulated Lua/EEex fixtures: 427 configuration assertions,
212 enemy cooperation assertions, 180 enemy reservation assertions, 652 overlap
escape assertions and 2,303 private-map policy/adapter assertions.
Offline fixtures do not emulate gameplay. No game was launched by the agent.

Enemy gameplay has not been retested on every engine profile. Multiplayer remains
unsupported. Existing native door-entry failures remain under investigation.

For problems, press Left Ctrl+Left Shift+F7, reproduce within 20 seconds, then
run **`Collect BG Redux Support.cmd`** and send **`bg-redux-support.log`** with steps.
Startup failures do not require recording.

Verify the ZIP with `SHA256SUMS.txt`. Original code/docs are MIT; bundled WeiDU
retains GPL-2.0 with corresponding source.
