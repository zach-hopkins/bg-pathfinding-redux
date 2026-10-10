# BG Pathfinding Redux — 0.1.9-mp-experimental

Allied creatures pass through one another while walls, closed doors, neutral
NPCs and enemies retain their native blocking behavior. Party melee approach
positions prefer usable separate spots; gentle settle separates stopped party
members after a short 150 ms grace period. Allies can still compress when needed.

Allied movers already overlapping a neutral or enemy can walk outward to escape.
Normal blocking resumes on separation. Escape follows the Movement setting; it
does not allow entering blockers from outside or crossing walls/closed doors.

Optional enemy cooperation (Ctrl+Shift+F2, default OFF) lets normal-sized enemies
with matching hostile allegiance pass through each other and prefer separate melee
positions. They continue to block the party and neutral NPCs. Known current attack
targets remain blocking; allegiance grouping is experimental, not a complete
faction model. Requires allied movement and attack spacing ON.

See [QUICKSTART.md](QUICKSTART.md) for the hotkey guide.

## Tested setups and updates

This 0.1.9-mp-experimental package automatically selects the supported native profile for:

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

Movement starts automatically. Attack spacing, gentle settle and visual route
preference default ON in fresh installations. The optional preference offers modest
visual spacing in some routes and retains native movement whenever its guards
reject a candidate. It does not guarantee lasting lanes or eliminate overlap.

Reinstall preserves existing preferences, including a saved OFF choice. F3 can
switch visual preference OFF or ON, and that choice persists between launches.
The installer creates the supplied defaults file only when no settings file exists.

Edit `bg-redux-movement.ini` with1/0 and restart, or toggle during play:

| Left Ctrl+Left Shift+key | Setting |
|---|---|
| F6 | Allied movement (current session only; ON each launch) |
| F5 | Attack spacing |
| F4 | Gentle settle |
| F3 | Optional visual route preference |
| F2 | Enemy cooperation (experimental; saved; defaults OFF) |

F2–F5 changes persist through the installed EEex INI API, independently of game
saves. F6 never writes an INI setting; legacy `Movement=0` is ignored at startup.
Enemy cooperation defaults OFF only when no saved choice exists. Invalid values use
documented defaults. A reported configuration-write failure affects persistence;
the current session still uses the selected setting. A movement runtime error
or clock-reset guard disables movement for the current session; review the log
before re-enabling. This safeguard does not silently rewrite the saved setting.

Normal play logs compact startup/status/errors only. Automatic activation adds
no chat instructions. Verbose capture stays OFF unless requested: Left Ctrl+Left Shift+F7 begins a
20-second diagnostic capture; F9 ends it early; F8 takes a snapshot. Recording
never controls movement activation. Loader log path follows `InfinityLoader.ini`;
look for `[BG Redux]` entries in your loader log. Include build/version, steps
and completed captures when reporting a defect.

## Send one support file

For a movement problem, press Left Ctrl+Left Shift+F7 and reproduce within
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
