# BG Pathfinding Redux — experimental multiplayer

Separate test release based on 0.1.8-preview. Removes explicit network-session
refusals from private path-search correction, gentle settle and visual route
preference. Both peers must install this same build with compatible EEex and
matching options. The regular release is unchanged.

This unlocks existing movement behavior; it does not synchronize settings,
route reservations or automatic spacing orders between peers. Paired gameplay
testing is pending. Native signature, bitmap ownership and action checks remain.

Close the game, extract the Windows ZIP into each game folder, and reinstall
component 0 with `setup-bg-redux-movement.exe`. Launch through EEex. Existing
settings persist, so match F2–F5 on both peers before testing.

Start with F2/F3/F4/F5 OFF and F6 ON. Test host-controlled and client-controlled
characters crossing each other and doorways; watch both screens. Then enable
attack spacing, gentle settle, route preference and enemy cooperation separately.
Record matching trials with Ctrl+Shift+F7 on both peers, then send both support
logs from `Collect BG Redux Support.cmd` with who controlled each character.

The ZIP includes `bg-redux-movement/MULTIPLAYER-TEST.md` and `QUICKSTART.md`.
Offline tests cover network admission, private-map corrections and preserved
safety checks. Offline fixtures do not establish multiplayer synchronization.
No launch tests were performed.

To return to the normal build, reinstall 0.1.8-preview on both peers.
