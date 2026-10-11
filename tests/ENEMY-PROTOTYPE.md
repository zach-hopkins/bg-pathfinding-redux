# Enemy cooperation prototype 4

Released as an experimental option in 0.1.7-preview; defaults OFF when no saved choice exists. It combines enemy pass-through and preferred melee attack positions; the two features are tested together.

## Controls

Keep movement and attack spacing ON. Press **Left Ctrl+Shift+F3** and confirm “enemy cooperation prototype ON.” This choice persists in `bg-redux-movement.ini` across saves and launches. F1 allied movement is session-only and starts ON at each launch. Issue fresh orders after changing a toggle.

Record each trial with **Left Ctrl+Shift+F6** before enemies start approaching, and allow the 20-second capture to finish (dev F9 can end it early).

1. **Open ground, OFF:** let four to six normal-sized melee enemies approach one stationary party member. Record their baseline movement and attack positions.
2. **Open ground, ON:** repeat from the same save. Expect passage through cooperating enemies and preferred distinct attack positions when available. Compression is still permitted.
3. **Doorway, ON:** lure several normal-sized enemies through a narrow opening. Their own side should flow through; a party blocker, neutral NPC, closed door or wall should still stop them.
4. **OFF regression:** turn F3 off and repeat the approach. Allied party movement should retain its existing behavior in both modes.

## Scope and limits

“Cooperating” initially means identical hostile enemy/allegiance values (200–255), with both creatures having personal space 3. Larger creatures and differing enemy allegiance values use ordinary collision. Known current attack targets are excluded from cooperation; observations expire and are bound to actor and area identities.

This is not a complete faction registry. Unobserved disputes between creatures with the same allegiance value are a remaining limitation. Flag any such case before expanding the scope.

Enemy attack positioning builds on the preferred-destination logic used by party attackers. Party destinations remain soft preferences; prototype 3 adds bounded enemy claims as described below. Native attack behavior remains responsible for range, visibility and attack execution. Budget exhaustion uses a verified partial result when available, otherwise native movement.

Prototype 3 strengthens enemy endpoints: a claimed destination excludes nearby enemy attack destinations within two search-grid units. Claims survive brief idle/SmallWait phases for 600 ms, and actual continuing attack callbacks refresh standing attackers' claims. Actor, target, area and allegiance changes release or invalidate claims.

If reachable frontage is already reserved, the enemy briefly waits at its current position, rechecking about every 100 ms. The maximum wait is 600 ms, after which native behavior may compress or overlap. That wait cannot restart indefinitely for the same engagement. No friendly collision or physical combat push is introduced. Existing in-range attacks are not universally redistributed.

Offline verification executes the actual extracted runtime policies, the private-map adapter and reservation cleanup under Lua/EEex fixtures. It also checks hook setup against actual executable bytes/layout. It does not emulate gameplay or prove live AI behavior.

## Visual route preference's “slow” notification

Visual preference stays enabled. A query over 4 ms or a full evaluation over
8 ms keeps the native route for that request without turning the feature OFF.
Dev Ctrl+Shift+F7 allows session-only comparisons. This concerns calculation
time, not the Slow spell.
