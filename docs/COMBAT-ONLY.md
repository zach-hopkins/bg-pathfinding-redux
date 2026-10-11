# Combat-only predicate investigation

The optional F2 mode uses the combat-only area condition from the native quicksave
path. It does not call `CanSaveGame`, alter timers or interpret generic save refusal.

`CScreenWorld::OnQuickSaveButtonClick` passes `checkCombat=1` to
`CInfGame::CanSaveGame`. That routine checks all 12 loaded `m_gameAreas` slots.
`CGameArea::CanSaveGame` rejects combat when `m_nBattleSongCounter > 0` or
`m_nDamageCounter > 0` (save reason `0xF00379`). Other branches handle other save
restrictions and are intentionally excluded. Native combat cooldown remains intact.

| Field | Verified offset |
| --- | --- |
| CGameArea.m_nBattleSongCounter | 0xFA4 |
| CGameArea.m_nDamageCounter | 0xFA8 |
| EEex_CInfGame.m_gameAreas | 0x6598 |

Native area-save RVAs: 2.6 `0x17B800`, 2.7 `0x17BA10`.
Quicksave RVAs: 2.6 `0x2F7A40`, 2.7 `0x2F8080`.
These instruction sequences and corresponding LuaBindings field registrations
were checked for all four supported profiles. The BG2EE 2.7 audit used the prepared
EEex 1.3 binding DLL alongside the actual Steam executable in an offline copy.

Implementation polls at most once per 50 ms and publishes a separate allocated
32-bit combat restriction flag to the native worker and bump bypasses. Allied
pass-cost and owned private bitmap policies retain ally occupancy during combat.
Only existing overlaps receive a distance-increasing outward escape; normal entry
stays blocked. Optional allied attack spacing, settle and visual route preference
pause, retaining their settings. Enemy cooperation remains independent.

If the combat timer binding is unavailable, this optional mode retains allied
collision and emits a diagnostic error. Turning F2 OFF restores normal allied
passage. F2 persists in the game-folder INI; F1 remains session-only.

Combat transition and outward escape were confirmed by the user in the dedicated
BG2EE 2.6 test copy on October 10, 2026. All four profiles passed offline Lua and
native assembly verification; this feature has not been live-tested on every profile.

## Candidate 2: escape grant correction

The first live run correctly detected combat but repeatedly treated new walking
overlaps as escapes (131 of 133 walk cost checks were allowed). Combat ally escape
now captures pairs once when blocking activates, pins actor IDs/pointers/areas,
and expires when they separate or leave the original blocker footprint.
Heartbeats resolve IDs again; no sprite userdata is retained. Re-overlap does
not renew grants. This also prevents an overlapping moving pair from carrying
permission across the map. Existing neutral/enemy escape behavior is unchanged.

Regression coverage tests new encounters, separation/reentry, identity reuse,
area changes and paired movement against the actual shipped policies and
transition adapter. The corrected escape behavior was confirmed working in-game.
