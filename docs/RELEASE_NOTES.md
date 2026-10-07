# BG Pathfinding Redux 0.1.0-preview

An initial single-player preview for Windows BG2EE 2.6.6.0 with EEex 1.2.0.

Allied creatures can move through one another while walls, closed doors, neutral
NPCs, and enemies retain blocking. Independent attack spacing, gentle settle,
and visual route preference improve party spacing without restoring friendly
obstruction. All four features default ON and have persistent individual toggles.

## Install

Install EEex first, close the game, and extract the Windows installer ZIP beside
`Baldur.exe`. Run `setup-mrdx-movement.exe`, install component 0, and launch through
`InfinityLoader.exe`. GitHub's automatic source archives lack the installer.

Hold Left Ctrl + Left Shift and press F6 for movement, F5 for attack spacing,
F4 for gentle settle, or F3 for visual preference. Existing settings are preserved.

## Scope

Revision 53 retains the accepted revision 52 movement policy. The final solo
regression and manual save/load/transition checks passed. EET installation is
verified, but EET gameplay acceptance remains pending. Other executable versions,
BGEE/IWDEE, multiplayer, Linux/Wine/Proton, and macOS/CrossOver are unvalidated.

Overlap can still occur. Spacing remains a preference, and settle does not push
attacking actors. Retreating through allies is easier than vanilla by design.

See the repository README and validation notes for supported hashes, test limits,
installation details, and diagnostic reporting. Verify your download using the
included `SHA256SUMS.txt` release asset.

The project's original code and documentation are MIT licensed, copyright (c)
2026 Zach Hopkins. The bundled WeiDU installer retains its GPL-2.0 license and
includes its corresponding source archive.
