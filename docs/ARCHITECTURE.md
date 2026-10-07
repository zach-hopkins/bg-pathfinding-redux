# Architecture and design intent

## Priority order

1. Reliable allied traversal.
2. Consistent, understandable behavior.
3. Sensible combat positioning where independent of traversal.
4. Balance and fidelity concerns.

Allies remain passable during ordinary movement and attack approaches. Enemy
proximity, combat state, stationary allies, and attack orders do not intentionally
restore allied collision. Neutral NPCs remain blocking, including story gates.

## Engine layers

The engine has several independent decisions between issuing an order and
moving an actor. Correcting just the final collision check leaves routes that
still avoid allies; correcting just planning leaves actors waiting or bumping.
The runtime applies its policy across synchronous planning, private background
search snapshots, early moving-actor waits, physical movement steps, and bump
recovery. Actor identity, footprint, ownership, and request lifetime matter.

An occupancy cell contains packed counts/flags rather than a reliable creature
identity. Where ownership is verified, friendly footprint contributions can be
discounted for the eligible mover's query or private search snapshot. Hostile,
neutral, static, mixed, or unknown obstruction is retained conservatively.
Live world occupancy is not globally erased: enemies must still see the party.

Current allied eligibility uses engine allegiance values 2 through 30, with
additional native safety gates. Drawn circle color alone is not the policy.
Normal-sized mover assumptions, ownership checks, network refusal, and lifetime
guards limit the supported scope.

Lua handles policy and controller decisions through EEex. Injected x64 code
handles native seams and thread-sensitive work. Worker threads do not call Lua.
Hook bytes and binding layouts are checked before installation. Windows calling
conventions, registers, flags, stack layout, instruction lengths, and original
continuations must be preserved.

## Independent spacing

**Attack spacing** selects and softly reserves usable native-valid approach
positions. It preserves range, terrain, and real blocker constraints. The target
may be idle, unconscious, hostile, neutral, or allied when explicitly attacked;
its status is not a prerequisite for spacing. Failed custom approaches keep
native fallback instead of continually replacing it. Tight-space compression
remains possible. Attack traversal stays permissive.

**Gentle settle** handles eligible ordinary movement arrivals and idle party
actors. After a 150 ms grace period, it may choose a small nearby valid adjustment.
Terrain and diagonal side checks apply; new orders supersede owned adjustments.
It does not push attacking actors or impose a hard minimum separation.

**Visual route preference** considers bounded native alternatives around shared
travel. Friendly proximity adds a soft cost rather than invalidating a cell.
Native footprints, clearance, endpoint, progress, added travel, time/query budgets,
and ownership guards determine whether a candidate is committed. Local
straightening reduces some unnecessary turns. It is not continuous steering.
The accepted tuning uses a 50-pixel route band and bounds added travel to both
8% and 32 pixels. Three optimization rounds are complete.

## Source organization

`mrdx-movement/runtime/M_MRIP.lua` is the self-contained accepted runtime: Lua
controllers, native assembly templates, guards, configuration, and diagnostics.
It is intentionally byte-identical to revision 53. This repository packaging
does not refactor its hooks or change gameplay.

`tests/fixtures` contains configuration/bootstrap extracts and native bridge
factories used by offline checks. These are test inputs, not separately installed
runtime modules. Checks require configuration extracts to occur in the actual
runtime. The installed runtime remains the canonical source for shipped behavior.

The earlier experimental revision history and raw capture files remain in the
development archive; they are not needed to install this package. A portable
modder API is a future design topic, not a feature promised by this preview.

## Accepted externalities

Retreat and tank rotation through allied formations are easier. Melee frontage
can compress, and overlap is sometimes visible. These tradeoffs are accepted.
Do not automatically restore collision or add combat pushing to compensate.
Surface demonstrated balance or positional problems before changing that policy.

GemRB informed the investigation, but these Beamdog executable hooks were mapped
and verified independently. Leader/Follow scripted movement behaved well in
manual testing; reusing its spacing mechanism remains an investigation idea,
not a claim about the current implementation.
