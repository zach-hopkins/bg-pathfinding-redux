# BG Pathfinding Redux

**Party members should be able to move through their own party.**

BG Pathfinding Redux is an EEex mod for Baldur's Gate II: Enhanced Edition that
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

**Version 0.1.0-preview** contains the accepted revision 53 runtime.

| Setup | Status |
| --- | --- |
| Windows BG2EE 2.6.6.0 with EEex 1.2.0, single player | Tested preview target |
| EET using that BG2EE executable | Installer verified; live EET gameplay acceptance pending |
| Other executable versions, BGEE, or IWDEE | Not validated |
| Multiplayer | Not supported by this preview; several paths deliberately decline network work |
| Linux through Wine/Proton; macOS through Wine/CrossOver | Potential Windows-executable routes; this mod has not been tested there |
| Native Linux or macOS game executables | Not supported by these Windows x64 hooks |

The tested executable SHA256 is
`FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580`.
Native signature and layout guards refuse incompatible hooks. The installer
accepting a game does not establish that its executable is supported.

## Installation

1. Close the game and install [EEex](https://github.com/Bubb13/EEex/releases).
2. Download the **Windows installer ZIP** from this repository's
   [Releases](https://github.com/zach-hopkins/bg-pathfinding-redux/releases).
3. Extract beside `Baldur.exe`, preserving the `mrdx-movement` folder.
4. Run `setup-mrdx-movement.exe` and install component **0**.
5. Start the game through **`InfinityLoader.exe`**.

GitHub's automatic “Source code” archives do not contain the Windows installer.
For a source checkout, see [building the package](docs/DEVELOPMENT.md).
Existing saves can be used. The installer writes the movement overlay and user
settings; it does not patch campaign resources or save files.

The existing `mrdx-movement` installer IDs and `M_MRIP.lua` runtime name are
retained for upgrade compatibility. Do not run a second renamed copy of the
earlier prototype alongside this one. See [installation and troubleshooting](docs/INSTALLATION.md).

## Controls

Hold **Left Ctrl + Left Shift**, then press:

| Key | Feature |
| --- | --- |
| F6 | Allied movement |
| F5 | Attack spacing |
| F4 | Gentle settle |
| F3 | Visual route preference |

Changes persist in `mrdx-movement.ini`. You can also edit its four settings to
`1` (on) or `0` (off), then restart the game.

Diagnostics are off by default. With the same modifiers, **F7** starts a
20-second capture, **F8** takes a snapshot, and **F9** ends the capture early.
Recording does not enable or disable movement.

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

Project licensing is pending the maintainer's choice before public release.
Third-party tools retain their own licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
