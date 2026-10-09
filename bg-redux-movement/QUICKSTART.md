# BG Pathfinding Redux — quick guide

Launch through EEex. Allied pass-through starts ON automatically.

Hold **Left Ctrl + Left Shift**, then press:

| Key | What it does | Default |
| --- | --- | --- |
| F2 | Enemy cooperation: enemy-to-enemy pass-through + melee spacing | OFF |
| F3 | Visual route preference: reduce prolonged overlap while traveling | ON |
| F4 | Gentle settle: separate overlapping party members after movement stops | ON |
| F5 | Attack spacing: prefer separate melee approach positions | ON |
| F6 | Allied pass-through: toggle core movement for this session | ON each launch |
| F7 | Start a 20-second diagnostic recording | — |
| F8 | Take a diagnostic snapshot | — |
| F9 | End recording early | — |

**F2–F5 are saved across launches**, independently of saves. **F6 is session-only**.
Enemy cooperation is experimental, limited to normal-sized enemies with matching
hostile allegiance, and requires F5 and F6 ON. Party members, neutrals, walls and
closed doors still block enemies. Issue fresh orders after changing an option.

Visual preference may switch OFF for the session if a calculation is slow;
core movement stays ON and its saved preference choice is unchanged.

**Report an issue:** press F7, reproduce within 20 seconds, then run
`Collect BG Redux Support.cmd` in the game folder and send `bg-redux-support.log`
with a short description. Startup failures do not require recording.
