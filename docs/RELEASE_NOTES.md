# BG Pathfinding Redux 0.1.10-preview

Adds an optional **allied pass-through only outside combat** mode and simplifies the controls.

With the new mode enabled, allies block each other during combat. Characters already overlapping when combat starts can move outward until clear. Combat detection follows the game's quicksave battle/damage timers and their cooldown; dialogue and other save restrictions do not count. The mode defaults OFF and remembers your choice.

## Controls

Hold **Left Ctrl + Left Shift**:

| Key | Action |
| --- | --- |
| F1 | Allied pass-through ON/OFF; starts ON each launch |
| F2 | Outside-combat-only mode; default OFF |
| F3 | Enemy cooperation: enemy pass-through + attack spacing; default OFF |
| F4 | Gentle separation after movement; default ON |
| F5 | Attack positioning; default ON |
| F6 | Record a 20-second support capture; ends automatically |

F2–F5 remember your settings across launches. Enemy cooperation requires F1 and F5 enabled. Visual route preference starts enabled, has no release toggle, and ignores old saved OFF settings. Slow evaluations use native fallback for that request without disabling the feature.

## Install or upgrade

Close the game, extract `bg-redux-movement-0.1.10-preview-windows.zip` into the game folder, and reinstall component 0 using `setup-bg-redux-movement.exe`. Existing optional settings are preserved. Launch through EEex.

This is the regular single-player preview. The separate multiplayer experiment remains experimental.

## Verification and support

Combat transition and corrected overlap escape were confirmed in-game in the dedicated BG2EE 2.6 copy. Offline runtime, native assembly and control checks pass across all four supported BGEE/SoD and BG2EE 2.6/2.7 profiles. Real WeiDU install/reinstall/uninstall checks pass. The new combat mode has not been live-tested on every profile.

For support, press Ctrl+Shift+F6, reproduce the problem, then run `Collect BG Redux Support.cmd` and send `bg-redux-support.log` with your steps. The included `bg-redux-movement/QUICKSTART.md` has the usage guide.
