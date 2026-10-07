# Third-party notices

## WeiDU

The Windows release package includes an unmodified WeiDU 251 executable, renamed
`setup-mrdx-movement.exe`. WeiDU is separately licensed under GPL-2.0. Its license
and the corresponding tagged source archive are bundled under
`mrdx-movement/third_party/weidu/` by the release builder.

Upstream: https://github.com/WeiDUorg/weidu

Release: https://github.com/WeiDUorg/weidu/releases/tag/v251.00

The project's selected license, once chosen, does not replace WeiDU's license.

## EEex and InfinityLoader

These are required external dependencies, installed separately from their
official release. This repository does not bundle their DLLs, loader, or source.
Their own license terms apply. Offline native tests read the user's installed
EEex scripts and binding DLL without distributing them.

## Game files and research references

BG2EE executables, saves, dialogue files, videos, crash dumps, and campaign assets
are not included. Offline checks requiring those files use a local installation.
GemRB and IESDP are research references, not packaged runtime dependencies.
