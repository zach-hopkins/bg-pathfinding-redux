# Multiplayer experiment — first paired test

Install the same experimental ZIP on host and client, with compatible EEex.
Close each game, extract into its folder and reinstall component 0. Launch through
EEex. Use a separate test save so trials are easy to repeat.

All hotkeys require **Left Ctrl + Left Shift**. F2–F5 are saved locally and are
not synchronized, so match their ON/OFF messages on both machines. F6 starts ON
each launch. Record which peer controls each character.

## Start with core movement

Set **F2, F3, F4 and F5 OFF; F6 ON**, on both peers. Toggle only if needed;
pressing a key twice returns to the previous state.

1. Give each peer control of at least one party member.
2. Move a host-controlled character through a stationary client-controlled ally.
3. Reverse roles, then move both through each other and a narrow doorway.
4. Check closed doors, neutral NPCs and hostile blockers still block normally.
5. Watch both screens for disagreements, snapping back or persistent stalls.
6. Save/load, change area, and leave/rejoin; repeat a crossing.

## Add features individually

Repeat a short shared trial with F5 attack spacing, then F4 gentle settle, then
F3 visual route preference enabled. Finally try F2 enemy cooperation with F5/F6 ON.
Start each new feature with the previous optional features OFF where practical.
Both peers should always use matching settings.

## Send results

Press **F7 on both peers**, reproduce within 20 seconds, and use F9 to end early.
Then run `Collect BG Redux Support.cmd` on each machine. Send **both** generated
`bg-redux-support.log` files, identifying host/client, character ownership,
settings, what happened and whether both screens agreed. Capture video if possible.

This build removes multiplayer refusals but adds no settings synchronization or
movement-authority routing. Multiplayer operation is unverified until paired
testing. To return to the normal build, reinstall 0.1.8-preview on both peers.
