# Dev hotkeys

Hold Left Ctrl + Left Shift. F1–F6 match the release build:

| Key | Function |
| --- | --- |
| F1 | Core allied noclip; session-only, starts ON |
| F2 | Outside-combat-only allied noclip; saved, default OFF |
| F3 | Enemy cooperation; saved, default OFF |
| F4 | Gentle settle; saved, default ON |
| F5 | Attack positioning; saved, default ON |
| F6 | Start a 20-second diagnostic recording |
| F7 | Visual preference comparison; session-only, starts ON |
| F8 | Unassigned |
| F9 | End diagnostic recording early |

Build the dev ZIP with `tools/build_release.py --dev --vendor-dir .vendor`.
The dev dispatcher enables the extra controls; engine profiles are shared with
release. Release dispatchers leave F7–F9 inactive. The dev visual choice is not
written to the INI. Both builds retain preference after slow evaluations and
fall back only for the affected request.
