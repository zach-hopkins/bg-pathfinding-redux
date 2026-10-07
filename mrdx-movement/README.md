# BG Pathfinding Redux — 0.1.0 preview

Allied creatures pass through one another while walls, closed doors, neutral
NPCs and enemies retain their native blocking behavior. Party melee approach
positions prefer usable separate spots; gentle settle separates stopped party
members after a short 150 ms grace period. Allies can still compress when needed.

## Tested setup

Windows BG2EE 2.6.6.0, the project's pinned executable and EEex 1.2.0 setup.
Supported executable SHA256:
`FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580`.
Install EEex first. Start through `InfinityLoader.exe`. Native hook signature
mismatches disable the runtime. Installation also accepts EET on the BG2EE engine.
The reported EET test copy has the same executable and EEex version; EET gameplay
acceptance is pending. BGEE/IWDEE, other executable versions and multiplayer are
not validated release targets; several features deliberately decline network work.

Revision 53 passed the final solo release session on October 6, 2026. Automatic
startup, allied traversal/settle, blocking and attack positioning were checked;
save/load and area transition were manually confirmed by the tester. This is
an accepted solo preview; long campaign stability and multiplayer are not proven.
This package is the initial standalone BG Pathfinding Redux preview.

## Install and uninstall

Close the game. Extract beside `Baldur.exe`, retaining the `mrdx-movement` folder,
then run `setup-mrdx-movement.exe` and choose component 0. Installation backs up
any existing `override/M_MRIP.lua`. Do not keep a separate renamed copy of that
prototype active. No campaign resources or save files are patched.

To uninstall, close the game and rerun the installer to remove component 0.
WeiDU restores an existing previous overlay or removes the new one. The
preferences file `mrdx-movement.ini` stays in the game folder so choices survive
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

Edit `mrdx-movement.ini` with1/0 and restart, or toggle during play:

| Left Ctrl+Left Shift+key | Persistent setting |
|---|---|
| F6 | Allied movement |
| F5 | Attack spacing |
| F4 | Gentle settle |
| F3 | Optional visual route preference |

Hotkey changes persist through the installed EEex INI API. Invalid values use
documented defaults. A reported configuration-write failure affects persistence;
the current session still uses the selected setting. A movement runtime error
or clock-reset guard disables movement for the current session; review the log
before re-enabling. This safeguard does not silently rewrite the saved setting.

Verbose capture stays OFF unless requested: Left Ctrl+Left Shift+F7 begins a
20-second diagnostic capture; F9 ends it early; F8 takes a snapshot. Recording
never controls movement activation. Loader log path follows `InfinityLoader.ini`;
the project's MRIP copy uses `MRIP-prototype.log`. Include build/version, steps
and completed captures when reporting a defect.

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
configuration/activation only. Visual optimization rounds are closed.

Repository and issue reports: https://github.com/zach-hopkins/bg-pathfinding-redux
