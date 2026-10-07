# Contributing

Start with the [architecture](docs/ARCHITECTURE.md) and
[development checks](docs/DEVELOPMENT.md).

Preserve predictable allied pass-through. Attack spacing and visual spacing must
remain independent preferences; they must not restore obstruction during combat,
near enemies, or on stationary allies. Neutral and hostile blockers are intentional.

For native changes, document the exact supported executable, hook bytes,
instruction widths, register/flags preservation, stack layout, original
continuations, ownership, and thread constraints. Never call Lua on path worker
threads or bypass a layout/signature guard to accept an unknown executable.

Make focused changes and explain the observed defect, evidence, intended behavior,
offline checks, and required manual scene. Do not imply that simulated fixtures
prove gameplay behavior. Do not launch a contributor's game without their request.

Please avoid including game files, raw personal logs, saves, videos, or crash dumps
in source commits. Bug reports may attach a minimized capture or save when useful
and deliberately shared. Preview licensing must be chosen before public release.
