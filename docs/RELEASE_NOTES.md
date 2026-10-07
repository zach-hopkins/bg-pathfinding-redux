# BG Pathfinding Redux 0.1.1-preview

Added confirmed Windows Steam BG2EE **2.7.3.0 / EEex 1.3.0** support alongside
the accepted **2.6.6.0 / EEex 1.2.0** setup. One installer ZIP contains both exact
tested runtimes and selects the corresponding profile automatically at startup.
Movement behavior is unchanged: allies and friendly summons pass through one
another; enemies, neutral NPCs, walls and closed doors retain blocking. Independent
attack spacing, 150 ms gentle settle and visual route preference remain enabled
by default and toggle independently.

## Install or upgrade

Close the game, install EEex for your executable, and extract the Windows installer
ZIP beside `Baldur.exe`. Run `setup-mrdx-movement.exe`, install/reinstall component
0, and launch through `InfinityLoader.exe`. Keep the `mrdx-movement` folder after
installation. Existing settings are preserved. Automatic GitHub source archives
do not include the Windows installer.

Hold Left Ctrl + Left Shift: F6 movement, F5 attack spacing, F4 gentle settle,
F3 visual preference. Movement starts ON; F6 is a toggle, not a required startup
step. F7 starts a 20-second diagnostic capture, F8 snapshots, F9 ends recording.

## Game updates

Known profiles are selected automatically. Unknown executable identities disable
the mod, preserve preferences and report that an update is required; no native
movement hooks are installed. The installer also skips unknown executable hashes.
Native movement remains active if EEex initializes. Future patches still require
a reviewed profile, and EEex may need its own update. This is not a promise of
universal update compatibility.

## Validation and scope

The tester confirmed revision 54 working on October 7, 2026. Its startup log shows
all four features active without MRIP errors; no per-scene captures were present.
The 2.7 port independently checked native function equivalence, addresses and
field registrations. Both profiles passed integrated offline selection/hook
fixtures with preference ON/OFF; installer rollback and unknown-build refusal
were verified on 2.6 and 2.7 resource labs. These fixtures do not emulate gameplay.

Single player only. EET gameplay, GOG 2.7, other executable hashes, multiplayer,
Wine/Proton and CrossOver remain unvalidated. Native Linux/macOS executables are
unsupported. Circle overlap and native fallback remain possible; attacking actors
are not pushed apart. See README and validation notes for exact scope and hashes.

Verify the installer ZIP using the attached `SHA256SUMS.txt`. Original code/docs
are MIT licensed, copyright (c) 2026 Zach Hopkins. Bundled WeiDU retains GPL-2.0
and includes its corresponding source archive.
