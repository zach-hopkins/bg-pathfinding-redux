# Community support checks — 2026-10-07

Disposable Windows PowerShell fixtures verify hashes, quoted/custom/absolute log
paths, missing captures, bounded tails, path redaction and read-only inputs.
Lua fixtures verify safe optional context fields and queue bounds. Real WeiDU
fixtures verify blank logging activation, custom-path preservation, collector
installation and rollback. Captures remain opt-in; game behavior is unchanged.
The lazy Stop bridge adds one assembly body to the earlier 51-body gate.

# 2.7 lazy settle guard correction â€” 2026-10-07

BGEE 2.7 reported `native settle Stop signature mismatch`. The constructor
address was relocated, but its separate 137-byte guard still described 2.6.
BG2EE 2.7 had the same stale guard. Both now use actual executable bytes.
The guard is retained; native bridge logic and movement tuning are unchanged.

A new fixture initializes the embedded lazy factory against actual bytes,
checks corrupted-guard refusal and relocated bases, and registers/invokes a
simulated bridge. It does not execute game code. Earlier startup checks did
not exercise this lazy factory. Both 2.7 fixtures now cover it directly.
The user confirmed the BGEE/SoD 2.7 retest: "Great working now."
Setup: Steam 2.7.3.0, DLC Merger 2.1, EEex 1.3.0, revision 56.
No game was launched by the agent. Publication is tracked separately.

# BG1EE / SoD compatibility acceptance â€” 2026-10-07

The user confirmed both BG1EE and SoD working: "All work on BG1EE/SOD engine."
Setup: Windows Steam BGEE/SoD 2.6.6.0, DLC Merger 2.1, EEex 1.3.0 minimal,
and BG Redux revision 55. This records the user's overall acceptance; it does
not assert individual test results beyond that report or long campaign stability.

Static comparison mapped 94 references in 41 corresponding engine functions,
all equivalent after relocation. The profile retains 56 native guards. Official
EEex binary inspection verified 16 member offsets and 6 usertypes; 51 expanded
assembly bodies passed parsing. Native-byte fixtures pass with visual preference
OFF/ON, using the actual installed executable and bindings. Movement policy is retained. Shipped profiles additionally contain read-only
snapshot context; BG2EE 2.7 also receives the lazy Stop guard correction. No agent game launch occurred.

The full-file hash is now advisory at installation. Recognized loaded PE identity
and native signature/layout checks remain required; changes outside those checks
are not guaranteed compatible. Unknown executable headers still disable hooks.
Other storefront builds, EET gameplay, multiplayer, and Wine/Proton/
CrossOver remain unvalidated.

# Executable hash warning policy

The installer now warns and continues for a modified full-file hash. Native
header selection and signature/layout checks remain. Real WeiDU tests cover
warning, installation, preserved preferences, and uninstall of a modified-hash
fixture. Historical exact-hash refusal results below describe earlier releases.

# Validation of 0.1.3-preview

## Restricted-Lua startup correction

The tester reported `M_BGREDX.lua:25: attempt to index global 'io' (a nil value)`
when starting 0.1.2. The selector incorrectly assumed that the game's Lua state
exposes the standard I/O library. The offline harness used `luaL_openlibs`, which
made that assumption pass. This was a packaging-selector defect.

The selector now reads the loaded PE header through EEex APIs, and checks the
DOS/PE signatures, bounded header offset, architecture, timestamp, entrypoint,
image size and checksum. It never uses `io`. Exact executable hashes remain
installer gates; native signature/layout guards are unchanged. Disk file length
remains provenance metadata rather than a startup selection input.

206 selector assertions run with `io=nil`, covering both known identities,
unknown/malformed headers, absent APIs, loader/payload failures and duplicate
loading. Both integrated native fixtures execute the actual selector and payload
with `io=nil` using real 2.6/2.7 header and instruction bytes, with visual preference
OFF/ON. Configuration and quiet-logging fixtures remain unchanged. Both movement
profile hashes are unchanged from 0.1.2. No game was launched; live hotfix startup
acceptance remains pending the tester's confirmation.

## Historical 0.1.2 public cleanup checks

## Public naming and quiet logging

This release changes installer/configuration/overlay names and presentation only.
It builds on the recorded 2.6 and Steam 2.7 gameplay acceptance below. It does not
claim a new live gameplay test of 0.1.2. Embedded assembly blocks and native
signature tables were compared exactly with 0.1.1 and remain unchanged.

The integrated native fixtures passed on both supported executables with visual
preference OFF/ON, alongside 326 configuration, 97 selector and 28 quiet-logging
assertions. Automatic activation adds no chat message; startup/status/errors remain
visible in the loader log. Explicit F7/F8/F9 diagnostics retain detailed output.
Diagnostic failures cannot leave normal play in verbose mode.

Real WeiDU resource labs verify old-component and manual-overlay refusal,
uninstalling the legacy ID before installation, copying old preferences only when
new preferences are absent, preservation of current settings, rollback, and unknown
executable refusal. No game was launched or installed game copy modified.

## Historical 0.1.1 acceptance and combined package checks

## Steam BG2EE 2.7.3.0 / EEex 1.3.0

On October 7, 2026 the tester confirmed revision 54: **"Yes it works well."**
This establishes manually confirmed startup and gameplay for the exact Steam
executable listed in `profiles.json`. The loader log shows `HOOKS_READY`,
`PREFERENCE_READY`, and `RELEASE_READY` with all four features enabled. It contains
no MRIP error entries. No F7/F9 scene captures were present, so this update does
not claim individually logged repetitions of every earlier regression case.
Raw private logs and user/game files are not distributed.

The port audited 41 native functions, mapped 94 native references, retained all
56 native signature guards, independently resolved three EEex startup anchors,
and checked 16 field-offset plus six usertype registrations. All referenced
functions were instruction-equivalent after relocating addresses and switch
tables. The existing policy, registers, stack use and validated field offsets
were retained. All 51 expanded hook bodies passed the offline assembler gate.

## Combined package and update handling

The package bundles the exact accepted revision 53 and revision 54 payloads.
Its selector adds no gameplay tuning. End-to-end offline native fixtures passed
through automatic selection for both executable versions, with route preference
OFF and ON. The configuration fixtures retain 326 assertions; profile-selection
fixtures add 97 assertions for known builds, future/modified header identities,
missing and malformed files, profile refusal, and duplicate loading.

Real WeiDU installation/rollback fixtures passed on both 2.6 and 2.7 resources,
using BG2EE and EET-marker labs. Unknown executable hashes were skipped before
writing a movement overlay; settings and unrelated resources were preserved.
EET-marker labs establish installer behavior only, not EET gameplay support.

Unknown startup identities never load a profile or write mod hooks. PE header
identity is not a cryptographic file check. Exact installer hashes and existing
native signature/layout guards provide independent checks. Future engine builds
still need a verified profile, and EEex must support the executable first.

## Historical 2.6 acceptance

Revision 53 was accepted in single-player testing on October 6, 2026, using the
pinned Windows BG2EE 2.6.6.0 executable and EEex 1.2.0. Its movement policy is
revision 52; revision 53 adds release activation and persistent configuration.

Runtime SHA256:
`5B4B657326FEE0E3DE868C01753965C71C7995C4E3F07719BBBFEF75CAD9D218`.

## Final recorded checks

| Run | Scene | Recorded evidence |
| --- | --- | --- |
| 1 | Doorway traversal and settle | 213/213 pass checks, 142/142 route checks, and 167/167 yield checks allowed; two settle adjustments reached their points |
| 2 | Closed door | One native non-ally obstruction retained; door stayed closed and blocked passage according to the tester |
| 3 | Creature blocker | Ten route refusals preserved neutral allegiance 128 occupancy; two settle adjustments reached their points |
| 4 | Group attack | Nine slot selections, five initial assignments, and four assigned-path decisions; neutral target obstruction retained |

These counts are bounded to capture START/END intervals. Across the four
captures, 364 of 365 physical pass checks allowed passage; one native obstruction
was retained. 244 of 259 route checks allowed passage; 15 neutral refusals were
retained. All 294 yield checks allowed passage. No runtime/configuration errors,
trace drops, or budget shutdowns were recorded.

Save/load and area transitions were confirmed manually by the tester. Earlier
accepted tests covered hostile blockers, friendly summons, Haste, Improved Haste,
Boots of Speed, Slow, ordinary and scripted movement, and group doorway movement.
Attack spacing was checked against idle and unconscious targets and different
allegiances. These are manual observations, not comprehensive automated proofs.

The final four-run regression had visual route preference OFF. Its ON behavior
was accepted in prior revision 52 captures. The later package change sets it ON
for fresh installs while preserving the exact runtime and existing OFF choices.

## Offline checks: what they establish

- Lua configuration/bootstrap fixtures exercise all 16 setting combinations,
  persistence errors, unavailable optional features, and startup error handling.
- Native fixtures read actual executable bytes and independently extracted
  LuaBindings registrations, then simulate EEex state and clock/INI APIs to check
  hook setup, guards, hotkeys, capture handling, and assembly expansion.
- Real WeiDU tests use isolated resource-only BG2EE/EET fixtures to verify install,
  exact overlay restoration/removal, custom settings preservation, and unchanged
  dialogue resources.
- Packaging checks pin hashes, inventory, defaults, and reproducible archive bytes.

**These checks do not emulate a running game.** They do not establish live
pathfinding quality, enemy behavior, rendering, thread scheduling, or stability.
The user performed live checks. Automated checks never launch the game.

EET's previous installer skip was reproduced and its corrected install/rollback
verified. EET gameplay acceptance remains pending. Multiplayer, long campaigns,
other executable hashes, Wine/Proton, and CrossOver remain unvalidated.
The Steam 2.7 acceptance is described above; it does not imply GOG 2.7 support.
