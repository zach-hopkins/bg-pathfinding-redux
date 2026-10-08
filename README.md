# BG Pathfinding Redux

**Party members should be able to move through their own party.**

BG Pathfinding Redux is an EEex mod for Baldur's Gate: Enhanced Edition, Siege of Dragonspear, and Baldur's Gate II: Enhanced Edition that
removes allied creature obstruction from movement planning and execution.
Allies can flow through one another and through cramped doorways. Walls, closed
doors, neutral NPCs, and enemies retain their native blocking behavior.

## Features

- **Allied pass-through:** ordinary movement and attack approaches ignore allied
  bodies. Friendly summons are included. Combat and speed modifiers do not
  intentionally switch friendly collision back on.
- **Attack positioning:** melee attackers prefer distinct usable positions around
  their target while continuing to pass through allies on the way there.
- **Gentle settle:** eligible stopped party members can make small adjustments
  to reduce overlap after an ordinary movement arrival, with a 150 ms grace period.
- **Visual route preference:** a bounded, optional preference reduces sustained
  shared routes where a suitable native route alternative exists. Overlap remains
  allowed when space or route constraints require it.

All four features are enabled by default on a fresh installation and can be
toggled independently. Existing saved settings survive reinstall.

## Compatibility

**Version 0.1.4-preview** automatically selects one of four verified executable profiles.

| Setup | Status |
| --- | --- |
| Windows BG2EE 2.6.6.0 with EEex 1.2.0, single player | Accepted revision 53 |
| Windows Steam BG2EE 2.7.3.0 with EEex 1.3.0, single player | Revision 54 confirmed working October 7, 2026 |
| EET using a supported BG2EE executable | Installer verified; live EET gameplay acceptance pending |
| Windows Steam BGEE and SoD 2.6.6.0 with EEex 1.3.0, single player | Revision 55 confirmed working October 7, 2026 |
| Windows Steam BGEE and SoD 2.7.3.0 with EEex 1.3.0, single player | Revision 56 confirmed working October 7, 2026 |
| Other executable versions or IWDEE | Not validated |
| Multiplayer | Not supported by this preview; several paths deliberately decline network work |
| Linux through Wine/Proton; macOS through Wine/CrossOver | Potential Windows-executable routes; this mod has not been tested there |
| Native Linux or macOS game executables | Not supported by these Windows x64 hooks |

The exact tested executable hashes and profile revisions are listed in
[profiles.json](profiles.json). A different executable hash produces an installer warning and installation continues.
At startup, a small loader selects a known loaded-image PE identity, then the selected
runtime verifies native signatures and field layouts before installing hooks.
Unknown build identities leave the mod disabled, preserve settings, and report
that an update is needed. This preserves native movement when EEex initializes.

This handles the four known executable profiles without manually replacing the runtime. It
does not guarantee compatibility with future patches, or prevent EEex itself
from needing an update. See [game updates](docs/INSTALLATION.md#game-updates).

## Installation

1. Close the game. For archived Steam/GOG SoD DLC, install [DLC Merger](https://github.com/Argent77/A7-DlcMerger/releases) first, then [EEex](https://github.com/Bubb13/EEex/releases).
2. Download the **Windows installer ZIP** from this repository's
   [Releases](https://github.com/zach-hopkins/bg-pathfinding-redux/releases).
3. Extract beside `Baldur.exe`, preserving the `bg-redux-movement` folder.
4. Run `setup-bg-redux-movement.exe` and install component **0**.
5. Start the game through **`InfinityLoader.exe`**.

GitHub's automatic “Source code” archives do not contain the Windows installer.
For a source checkout, see [building the package](docs/DEVELOPMENT.md).
Existing saves can be used. The package keeps its profiles in the `bg-redux-movement` folder and installs one
selector overlay plus user settings. Keep that folder after installation. It
does not patch campaign resources or save files.

Upgrading from **0.1.0/0.1.1**: uninstall the old component using
`setup-mrdx-movement.exe` first, then install this package. The new installer
copies `mrdx-movement.ini` to `bg-redux-movement.ini` when the new file is absent.
It refuses an installed legacy component or a remaining `override/M_MRIP.lua`
prototype, so the two versions cannot silently run together. See
[installation and troubleshooting](docs/INSTALLATION.md).

## Controls

Hold **Left Ctrl + Left Shift**, then press:

| Key | Feature |
| --- | --- |
| F6 | Allied movement |
| F5 | Attack spacing |
| F4 | Gentle settle |
| F3 | Visual route preference |

Changes persist in `bg-redux-movement.ini`. You can also edit its four settings to
`1` (on) or `0` (off), then restart the game.

Normal play logs only compact startup/status/error entries with the `[BG Redux]`
prefix. Automatic startup does not add toggle instructions to game chat.
Detailed diagnostics are off by default. With the same modifiers, **F7** starts a
20-second capture, **F8** takes a snapshot, and **F9** ends the capture early.
Recording does not enable or disable movement.

## Support reports

For a movement issue, press **Left Ctrl + Left Shift + F7** and reproduce within
20 seconds. Then double-click **`Collect BG Redux Support.cmd`** in the game folder
and send **`bg-redux-support.log`** with a short description. Collect before
restarting when possible. Startup failures can be collected without a capture.
See [support instructions and report contents](docs/SUPPORT.md).

## Design and limitations

Spacing is a preference; allied obstruction is removed independently. Tight
spaces can still compress a party, and neither spacing feature promises zero
overlap. Gentle settle does not push attacking actors apart. Retreating through
your own formation is easier than vanilla; that balance change is intentional.

This preview has manual coverage for doorways, hostile and neutral blockers,
speed modifiers, summons, scripted movement, attack targets in several states,
save/load, and area transitions. It does not establish long campaign stability
or compatibility with every mod combination. See [validation](docs/VALIDATION.md).

## Development and credits

The runtime combines Lua policies with guarded Windows x64 hooks through EEex.
It addresses planning, background search, early waits, actual movement steps,
and allied bump recovery. It does not globally erase creatures from the world.
See [architecture](docs/ARCHITECTURE.md) and [contributing](CONTRIBUTING.md).

Thanks to **Bubb and the EEex/InfinityLoader contributors** for the infrastructure
and reverse engineering that make these engine changes possible; **WeiDU's
authors and maintainers** for installation tooling; and **GemRB's contributors**
for useful implementation references. This project began as the MRIP allied
movement prototype within Multiplayer Redux. See [credits](CREDITS.md).

## License

BG Pathfinding Redux's original code and documentation are available under the
[MIT License](LICENSE), copyright (c) 2026 Zach Hopkins. Third-party tools retain
their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
