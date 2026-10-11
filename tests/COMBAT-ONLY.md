# Combat-only allied passage test

Test candidate: 0.1.10-preview. Dedicated game: `scratch/bg2ee-mrip`.
Hold Left Ctrl + Left Shift for all hotkeys. F1 must remain ON.

1. **Peaceful movement:** press F2 to enable outside-combat-only mode, then F6.
   Move party members through one another and an open doorway. They should pass.
2. **Combat:** provoke a hostile, press F6, and move one party member into another.
   Allies should block. Enemies and closed doors must still block.
3. **Existing overlap:** overlap allies while peaceful, then start combat. Press F6
   and send the stacked members in opposite directions. They should escape outward;
   once apart, moving back into each other should be blocked.
4. **Cooldown:** end combat, wait for the native combat timers to expire, press F6,
   and repeat party crossing. Passage should return. Dialogue alone should not
   switch on combat blocking.
5. **Saved setting:** leave F2 ON, save and restart. It should remain ON. Turn F2 OFF
   to return to full allied passage, including combat. F1 remains session-only.

Recording expires after 20 seconds (dev F9 can end it early). Report the run
numbers and visible outcomes. Enemy cooperation uses its own F3 setting.

Offline coverage executes shipped Lua policies and uses actual executable bytes,
EEex field registration data and source-built AsmTK assembly parsing. It does not
emulate gameplay or establish the visible in-game behavior above.
