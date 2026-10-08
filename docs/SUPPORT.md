# Sending a support report

**Send `bg-redux-support.log` and a short description of what happened.**

1. For a movement problem, hold **Left Ctrl + Left Shift**, press **F7**, and
   reproduce the problem within 20 seconds. F9 ends recording early; F8 takes an
   extra snapshot. Recording does not change your enabled features.
2. Double-click **`Collect BG Redux Support.cmd`** beside `Baldur.exe`.
3. Send the resulting **`bg-redux-support.log`**. The collector prints its location:
   normally the game folder, or your Desktop if that folder cannot be written.

Collect before restarting the game when possible: the loader may replace its log
on a later launch. You can collect while the game is running. For a startup failure,
skip step 1 and collect directly. Missing captures are clearly identified in the report.

## What is included

- Game, EEex, loader, and runtime file versions/hashes; package/profile metadata.
- Saved feature settings and the installed mod list from `WeiDU.log`.
- The newest 4 MiB of loader output, including startup failures and recorded runs.
- During requested snapshots: area/creature identifiers, party actor state,
  positions, actions, destinations and paths, plus pause and package/profile context.

The report describes recorded moments. It cannot reconstruct an unrecorded problem
or guarantee that it contains every relevant engine field. A screenshot/video,
save, or crash dump may still be requested for a specific issue.

## Logging and privacy

Installation sets the loader log to `bg-redux-runtime.log` when its existing
`LogFile` setting is blank. An existing custom destination is preserved and the
collector follows it. A network log path is reported for separate attachment.
Normal play keeps compact startup/status/error logging; movement recording is opt-in.

The Windows collector reads files and writes one report. It does not launch the
game, modify game state, upload anything, or include saves/crash dumps. It redacts
the game folder and Windows user-folder paths. Review before sharing: character
names, mod names and other loader output may remain. Do not upload game executables.

The collector requires Windows PowerShell. Wine/CrossOver collection is unvalidated;
the configured loader log and `WeiDU.log` can be attached manually there.
