# Validation of 0.1.0-preview

Revision 53 was accepted in single-player testing on October 6, 2026, using the
pinned Windows BG2EE 2.6.6.0 executable and EEex 1.2.0. Its movement policy is
revision 52; revision 53 adds release activation and persistent configuration.

Runtime SHA256:
`5B4B657326FEE0E3DE868C01753965C71C7995C4E3F07719BBBFEF75CAD9D218`.

## Final recorded checks

| Run | Scene | Recorded evidence |
| --- | --- | --- |
| 1 | Doorway traversal and settle | 213/213 pass checks, 142/142 route checks, and 167/167 yield checks allowed; two settle adjustments reached their points |
| 2 | Closed door | One native non-ally obstruction retained; door stayed closed and blocked passage according to the tester |
| 3 | Creature blocker | Ten route refusals preserved neutral allegiance 128 occupancy; two settle adjustments reached their points |
| 4 | Group attack | Nine slot selections, five initial assignments, and four assigned-path decisions; neutral target obstruction retained |

These counts are bounded to capture START/END intervals. Across the four
captures, 364 of 365 physical pass checks allowed passage; one native obstruction
was retained. 244 of 259 route checks allowed passage; 15 neutral refusals were
retained. All 294 yield checks allowed passage. No runtime/configuration errors,
trace drops, or budget shutdowns were recorded.

Save/load and area transitions were confirmed manually by the tester. Earlier
accepted tests covered hostile blockers, friendly summons, Haste, Improved Haste,
Boots of Speed, Slow, ordinary and scripted movement, and group doorway movement.
Attack spacing was checked against idle and unconscious targets and different
allegiances. These are manual observations, not comprehensive automated proofs.

The final four-run regression had visual route preference OFF. Its ON behavior
was accepted in prior revision 52 captures. The later package change sets it ON
for fresh installs while preserving the exact runtime and existing OFF choices.

## Offline checks: what they establish

- Lua configuration/bootstrap fixtures exercise all 16 setting combinations,
  persistence errors, unavailable optional features, and startup error handling.
- Native fixtures read actual executable bytes and independently extracted
  LuaBindings registrations, then simulate EEex state and clock/INI APIs to check
  hook setup, guards, hotkeys, capture handling, and assembly expansion.
- Real WeiDU tests use isolated resource-only BG2EE/EET fixtures to verify install,
  exact overlay restoration/removal, custom settings preservation, and unchanged
  dialogue resources.
- Packaging checks pin hashes, inventory, defaults, and reproducible archive bytes.

**These checks do not emulate a running game.** They do not establish live
pathfinding quality, enemy behavior, rendering, thread scheduling, or stability.
The user performed live checks. Automated checks never launch the game.

EET's previous installer skip was reproduced and its corrected install/rollback
verified. EET gameplay acceptance remains pending. Multiplayer, long campaigns,
other game executables, Wine/Proton, and CrossOver remain unvalidated.
