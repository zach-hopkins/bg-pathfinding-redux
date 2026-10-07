# Development and packaging

Python 3.10+ and LuaJIT are sufficient for portable integrity/configuration checks:

```sh
python tools/checks.py --lua luajit
```

CI runs that command. It checks the pinned accepted runtime, installer/defaults
metadata, linked configuration fixtures, and simulated settings/bootstrap behavior.
It does not run gameplay or native hooks on the GitHub runner.

## Native offline fixture on Windows

Supply your own pinned BG2EE/EEex installation. It is read-only input:

```powershell
python tools/checks.py --game "D:/Games/BG2EE"
```

This reads actual executable bytes and independently inspects `LuaBindings.dll`,
uses the installed LuaJIT, and expands templates through installed EEex scripts.
State/clock/INI interactions are simulated. Both missing-file OFF fallback and
package-configured ON route preference are checked. No game process is started.

You may supply `--lua-dll` explicitly if the installed LuaJIT DLL is elsewhere.
The fixture expects the tested EEex 1.2.0 file layout. Do not commit game files.

## Installer check

Use a local unmodified BG2EE resource set and the official Windows WeiDU 251:

```powershell
python tools/test_installer.py --weidu ".vendor/weidu.exe" --game "D:/Games/BG2EE"
```

Fresh BG2EE and EET-marker resource labs are created under `tests/.work`.
Checks cover fresh install, previous-overlay restoration, removal of a new overlay,
preservation of a customized OFF setting, and unchanged dialogue/key resources.
Labs are retained for inspection. They contain copies of local game resources and
must not be uploaded.

## Build a Windows release

Download the pinned tools and source without executing them:

```sh
python tools/fetch_vendor.py
```

Alternatively, obtain them manually from the URLs in `tools/weidu-provenance.json`:

1. Extract the official Windows package's `weidu.exe` into `.vendor`.
2. Save the tagged source ZIP as `.vendor/weidu-v251.00-source.zip`.
3. Copy that source archive's root `COPYING` file to `.vendor/COPYING`.

Hashes are verified against the release preparation inputs. The source ZIP is
bundled beside WeiDU's license in the installer package, not committed as mod
source. EEex and proprietary game files are not bundled.

```sh
python tools/build_release.py --vendor-dir .vendor
```

While licensing is undecided, maintainers can explicitly build a local staging
archive with `--allow-unlicensed-staging`. Choose the license before publishing.

The builder uses an explicit payload inventory, stable ZIP timestamps, and
byte-for-byte extraction checks. It writes the Windows ZIP, `SHA256SUMS.txt`, and
`build-report.json` under ignored `dist/`. Running it twice with identical inputs
must produce the same SHA256.

## Release preparation

- Confirm the project license and keep third-party terms separate.
- Keep the accepted runtime hash until a new gameplay revision is intentionally
  validated; do not weaken hash or executable guards just to pass checks.
- Run portable checks and applicable native/installer checks.
- Build the ZIP and check its install layout and hashes.
- Attach the ZIP and checksum file to a draft **prerelease** named `v0.1.0-preview`.
- Use `docs/RELEASE_NOTES.md` as its description; review before publishing.

The technical docs distinguish manual observations, actual native bytes, and
simulated fixtures. Claim only the compatibility tested for this preview.
