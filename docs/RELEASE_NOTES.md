# BG Pathfinding Redux 0.1.11-preview

Fixes crowded party overlaps when the optional outside-combat-only mode restores allied collision.

- **Easier escape from an existing stack:** characters can take sideways or briefly inward steps through allies they were already overlapping. Permission stays confined to the original overlap and ends on separation. Newly encountered allies, enemies, neutrals, walls and doors remain blockers.
- **More stable combat transitions:** allied collision starts immediately when combat is detected. Pass-through returns after the native combat timers clear and three continuously clear seconds of game time. Pausing does not consume the delay; renewed combat resets it.
- Gentle settle still defaults ON. Existing saved settings and the F1–F6 controls are preserved. Outside-combat-only mode (Ctrl+Shift+F2) still defaults OFF.

## Install or upgrade

Close the game, extract `bg-redux-movement-0.1.11-preview-windows.zip` into the game folder, and reinstall component 0 using `setup-bg-redux-movement.exe`. Launch through EEex. The included `bg-redux-movement/QUICKSTART.md` has the controls and support instructions.

## Verification

The user confirmed this correction working in the dedicated BG2EE 2.6 copy. Offline checks cover crowded corridors, preservation of other blockers, separation/re-entry, pause, renewed combat and game-time resets across all four supported BGEE/SoD and BG2EE 2.6/2.7 profiles. Native assembly checks pass on all four profiles. This correction has not been live-tested on every profile.

The separate investigation into quicksave's combat detection is deferred. This update improves escape and stabilizes the existing combat signal; it does not claim to resolve that detection discrepancy. This remains the regular single-player preview.
