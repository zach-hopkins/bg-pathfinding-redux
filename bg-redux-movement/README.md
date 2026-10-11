# BG Pathfinding Redux — 0.1.10 preview

Allied creatures pass through one another while walls, closed doors, neutral
NPCs and enemies retain their native blocking behavior. Party melee approach
positions prefer usable separate spots; gentle settle separates stopped party
members after a short 150 ms grace period. Allies can still compress when needed.

Allied movers already overlapping a neutral or enemy can walk outward to escape.
Normal blocking resumes on separation. Escape follows the Movement setting; it
does not allow entering blockers from outside or crossing walls/closed doors.

Optional enemy cooperation (Ctrl+Shift+F3, default OFF) lets normal-sized enemies
with matching hostile allegiance pass through each other and prefer separate melee
positions. They continue to block the party and neutral NPCs. Known current attack
targets remain blocking; allegiance grouping is experimental, not a complete
faction model. Requires allied movement and attack spacing ON.

See [QUICKSTART.md](QUICKSTART.md) for the hotkey guide.

## Tested setups and updates

This 0.1.10-preview package automatically selects the supported native profile for:

- Windows BG2EE 2.6.6.0 / EEex 1.2.0 (revision 53).
- Windows Steam BG2EE 2.7.3.0 / EEex 1.3.0 (revision 54), confirmed working
  October 7, 2026.
- Windows Steam BGEE and Siege of Dragonspear 2.6.6.0 / EEex 1.3.0
  (revision 55), both campaigns confirmed working October 7, 2026.

- Windows Steam BGEE and Siege of Dragonspear 2.7.3.0 / EEex 1.3.0
  (revision 56), confirmed working October 7, 2026 after the settle correction.

Executable hashes are listed in `profiles.json` and are advisory. Unfamiliar
headers warn and try a likely profile: first a matching entrypoint/image size,
then the installer game/version hint. Native instruction and field-layout checks
remain active. GOG `BaldurII.exe`, `SiegeOfDragonspear.exe`, and custom filenames
no longer prevent installation. A renamed EEex launcher warns rather than blocks.
The installer hint follows EEex: game type plus `data/PATCH27.BIF` for 2.7,
otherwise the 2.6 candidate. Passing checks does not certify every executable edit.
For archived SoD DLC, install DLC Merger before EEex. Launch through your EEex
loader and retain `bg-redux-movement`, which holds all four profiles. Reinstall
after a game update to refresh the hint. Existing settings are preserved.

Personal EET neutral/enemy overlap escape was confirmed October 9, 2026;
broader campaign coverage remains incomplete. GOG 2.7, other
executables, IWDEE and multiplayer are unvalidated. These accepted setups do not
establish long campaign stability. The repository validation notes distinguish
manual gameplay observations from simulated offline tests.

## Install and uninstall

For upgrades from 0.1.0/0.1.1, uninstall using `setup-mrdx-movement.exe` first.
Keep `mrdx-movement.ini`: it is copied when the new settings file is absent.
The installer refuses an installed old component or a lingering old prototype.

Close the game. Extract beside your game executable, retaining the `bg-redux-movement` folder,
then run `setup-bg-redux-movement.exe` and choose component 0. Installation backs up
any existing `override/M_BGREDX.lua`. Do not keep a separate renamed copy of that
prototype active. No campaign resources or save files are patched.

To uninstall, close the game and rerun the installer to remove component 0.
WeiDU restores an existing previous overlay or removes the new one. The
preferences file `bg-redux-movement.ini` stays in the game folder so choices survive
reinstall. It is ordinary user configuration and can be removed manually after
uninstall if desired.

## Settings and controls

Hold Left Ctrl + Left Shift:

| Key | Function | Default |
| --- | --- | --- |
| F1 | Core allied noclip | ON each launch; session-only |
| F2 | Allied noclip only outside combat | OFF; saved |
| F3 | Enemy cooperation | OFF; saved |
| F4 | Gentle settle | ON; saved |
| F5 | Attack positioning | ON; saved |
| F6 | Start a 20-second diagnostic recording | Automatically ends |

F2–F5 persist through the installed EEex INI API, independently of saves.
F1 never writes an INI setting; legacy Movement values are ignored at startup.
Enemy cooperation requires F1 and F5 ON. Existing feature choices survive reinstall.

Visual route preference stays enabled in release builds and ignores a legacy
saved OFF choice. It offers modest spacing and keeps native movement whenever
its guards reject a candidate. Slow calculations retain the native route for
that request without disabling preference for later movement.

Normal play logs compact startup/status/errors. F6 recording includes detailed
movement and party state and ends automatically after 20 seconds. Recording
does not change enabled features. See QUICKSTART.md for the concise guide.

## Send one support file

For a movement problem, press Left Ctrl+Left Shift+F6 and reproduce within
20 seconds. Then double-click `Collect BG Redux Support.cmd` beside `Baldur.exe`
and send `bg-redux-support.log` with a description. Collect before restarting
when possible; startup errors do not need a capture. The report is normally saved
in the game folder, with Desktop fallback if it cannot be written there.

The collector includes file versions/hashes, settings, the mod list and the newest
4 MiB of loader output. Requested snapshots add area, actor, action, destination
and package/profile context. Missing recordings are identified. Normal play stays
quiet; the installer enables a blank loader log setting and preserves custom paths.
No upload occurs. Saves and dumps are excluded; review names and loader output
before sharing. Windows PowerShell is required.

## Accepted limitations

- Travel may overlap. Optional spacing and attack destinations are preferences.
- Friendly summons are transparent; neutral story blockers retain collision.
- Retreat/tank rotation through allies is easier than vanilla and accepted.
- Attack spacing may use native fallback rather than repeatedly replace a failed
  approach. Gentle settle does not push attacking actors apart.
- The immediate F4 toggle does not guarantee separation of a previously idle
  stack. New movement/arrival is the normal trigger.
- Solo manual tests cover speed modifiers, summons, ordinary/scripted movement,
  save/load, transitions, doors and hostile/neutral blockers. They do not prove
  every mod combination, multiplayer synchronization or long campaign stability.

Underlying movement policy is frozen revision 52. Revision 53 adds release
configuration/activation only. Revision 54 relocates the accepted runtime for Steam
2.7.3.0. The selector adds packaging and compatibility checks without gameplay
tuning. Version 0.1.2 changes public names and logging only; native assembly and
signature tables remain unchanged. Visual optimization rounds are closed.

Repository and issue reports: https://github.com/zach-hopkins/bg-pathfinding-redux

## License

Original mod code and documentation: MIT License, copyright (c) 2026 Zach Hopkins.
See the included `LICENSE`. The WeiDU installer retains its separate GPL-2.0
license; its license and corresponding source are included under `third_party/weidu`.

## Outside-combat-only allied passage

**Left Ctrl + Left Shift + F2** toggles this optional mode. It defaults OFF and
saves `OutOfCombatOnly` in `bg-redux-movement.ini` for later launches. F1 remains
a session switch and starts ON.

When enabled, allies pass through each other outside combat and use native
blocking during combat. Allies already overlapping can move outward until clear;
they cannot enter another ally’s space. Walls, doors, enemies and neutrals stay
blocking. Enemy cooperation remains independent. Allied custom attack spacing,
settle and visual preference pause during combat and retain their saved settings.

Combat follows quicksave’s combat-only area check: a positive battle or damage
timer in any loaded area. Passage resumes after the native cooldown expires.
Dialogue and other save restrictions do not activate this mode. Combat transition and overlap escape were confirmed in the dedicated BG2EE 2.6
test copy on October 10, 2026. All four profiles passed offline checks.
