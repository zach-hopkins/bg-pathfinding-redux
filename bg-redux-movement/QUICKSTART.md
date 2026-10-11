# BG Pathfinding Redux — quick guide

Launch through EEex. Hold **Left Ctrl + Left Shift**, then press:

| Key | What it does | Default |
| --- | --- | --- |
| F1 | Core allied noclip | ON each launch; session-only |
| F2 | Allied noclip only outside combat | OFF; saved |
| F3 | Enemy cooperation: pass-through + attack spacing | OFF; saved |
| F4 | Gentle settle after movement | ON; saved |
| F5 | Attack positioning | ON; saved |
| F6 | Start a 20-second diagnostic recording | Automatically ends |

**F2–F5 persist across launches**, independently of saves. Enemy cooperation
requires F1 and F5 ON. Issue fresh orders after changing a movement option.

Visual route preference stays ON in release builds. An old `RoutePreference=0`
is ignored. Slow calculations keep the native route for that request and leave
preference enabled for later movement.

With F2 ON, allies block each other during the engine's combat cooldown. Pairs
already overlapping when blocking starts can escape outward; new overlaps do
not receive permission. Walls, doors, enemies and neutrals remain blocking.

**Report an issue:** press F6, reproduce within 20 seconds, then run
`Collect BG Redux Support.cmd` and send `bg-redux-support.log` with a description.
Recording does not change your movement settings.
