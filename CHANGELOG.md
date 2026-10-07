# Changelog

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
- WeiDU component 0 installs on BG2EE and EET, preserves preferences, and supports
  rollback without campaign/save edits.

Runtime revision 53 remains unchanged during repository preparation. Tested scope
is the pinned Windows BG2EE 2.6.6.0 / EEex 1.2.0 single-player setup. EET gameplay
acceptance and broader platform/version compatibility remain pending.
