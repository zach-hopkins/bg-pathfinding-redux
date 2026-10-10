# BG Pathfinding Redux 0.1.8-preview

Fixes a false executable-hash warning during installation. The installer now
expands the selected filename before checking its MD5. An unchanged, verified
game executable no longer gets reported as unfamiliar.

Modified executables still warn and remain installable. Movement behavior,
optional enemy cooperation, hotkeys and all four 2.6/2.7 engine profiles are unchanged.

## Install or upgrade

Close the game, extract `bg-redux-movement-0.1.8-preview-windows.zip` into the
game folder, and reinstall component 0 using `setup-bg-redux-movement.exe`.
Existing optional settings are preserved. Launch through EEex.

If 0.1.7 already works, its false warning did not damage your installation.

## Verification

Real WeiDU tests using copied reference and personal EET resources confirm that
clean and renamed executables do not warn, while modified executables warn and
install successfully. Install/reinstall/uninstall and settings preservation pass.
Offline runtime checks remain in place; no game was launched by the agent.

The hotkey guide is included as `bg-redux-movement/QUICKSTART.md`.
For support, record with Ctrl+Shift+F7, reproduce, run `Collect BG Redux Support.cmd`
and send `bg-redux-support.log` with steps.
