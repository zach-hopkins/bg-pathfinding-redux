# Changelog

## 0.1.5-preview — 2026-10-07

- Accept BaldurII.exe and SiegeOfDragonspear.exe; custom game/launcher filenames warn instead of blocking installation.
- Treat unfamiliar PE identities as advisory: try a matching layout or installer game/version hint.
- Generate the hint using the same GAME_IS/PATCH27.BIF selection as EEex.
- Retain actual native signature/layout checks and duplicate-install safeguards.
- Include alternate executable/launcher hashes and the hint in support reports.
- Movement profiles and tuning are unchanged; GOG gameplay confirmation remains pending.

## 0.1.4-preview â€” 2026-10-07

- Add user-confirmed Windows Steam BGEE and SoD 2.6.6.0 / EEex 1.3.0 compatibility.
- Add revisions 55/56 with relocated native addresses for BGEE/SoD 2.6 and 2.7.
- Confirm BGEE/SoD 2.7.3.0 / EEex 1.3.0 after correcting the lazy settle guard.
- Correct that guard in both 2.7 profiles without changing bridge logic.
- Add one-file community support collection and richer opt-in snapshots.
- Enable a blank loader log setting, preserve custom paths, and restore it on uninstall.
- Document DLC Merger before EEex for archived SoD distributions.

- Warn and continue installation when the full executable hash differs from known builds.
- Retain startup PE profile selection and native signature/layout checks.
- Hash warnings do not certify compatibility for patches outside guarded code regions.

## 0.1.3-preview â€” 2026-10-07

- Fix selector startup when the game does not expose Lua `io`: use EEex reads
  of the loaded executable header instead. Movement profiles are unchanged.
- Add io-disabled selector/integrated fixtures and contain missing chunk-loader
  failures. Exact installer hashes and native guards remain in place.

## 0.1.2-preview â€” 2026-10-07

- Rename the public folder/installer/settings to `bg-redux-movement`, and the overlay
  to `M_BGREDX.lua`; keep the GitHub project name.
- Refuse legacy component/prototype coexistence and copy old settings after uninstall
  when the new settings file is absent.
- Replace prototype feedback with `[BG Redux]` messages, quiet routine telemetry,
  and suppress automatic-startup chat; retain startup/errors and requested captures.
- Native hooks, signature tables, movement policy and tuning are unchanged.

## 0.1.1-preview

- Added the exact Steam BG2EE 2.7.3.0 / EEex 1.3.0 revision 54 profile, confirmed
  working by the tester on October 7, 2026. No movement policy tuning.
- Preserved the accepted revision 53 profile for BG2EE 2.6.6.0 / EEex 1.2.0.
- Added automatic executable-header profile selection, unsupported-build refusal
  with an update-needed message, and exact executable hash installer predicates.
- Settings survive refusal and upgrades; profile files live outside `override`.
- Verified both profiles through the selector, 97 refusal/selection assertions,
  and real WeiDU rollback/refusal checks on both versions' resource fixtures.
- Pinned ZIP platform metadata for reproducible Windows/Linux packaging.

## 0.1.0-preview

Initial standalone preview of BG Pathfinding Redux, developed as MRIP allied
movement within Multiplayer Redux.

- Allied pass-through across planning, background searches, movement checks,
  waiting, and bump recovery; hostile and neutral obstruction retained.
- Independent attack-position preferences, including idle and unconscious targets.
- Gentle settle after ordinary movement arrival with a 150 ms grace period.
- Optional bounded native route preference and local straightening.
- Automatic startup, persistent independent toggles, and opt-in diagnostics.
- All four features default ON for fresh installations.
- Original project code and documentation licensed under MIT.
- WeiDU component 0 installs on BG2EE and EET, preserves preferences, and supports
  rollback without campaign/save edits.

Runtime revision 53 remains unchanged during repository preparation. Tested scope
is the pinned Windows BG2EE 2.6.6.0 / EEex 1.2.0 single-player setup. EET gameplay
acceptance and broader platform/version compatibility remain pending.
