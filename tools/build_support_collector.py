"""Build the standalone Windows support-collector hotfix ZIP."""
import hashlib
import json
from pathlib import Path
import zipfile

from checks import ROOT


VERSION = "0.1.11-hotfix-1"
FILES = {
    "Collect BG Redux Support.cmd": ROOT / "bg-redux-movement/support/Collect BG Redux Support.cmd",
    "bg-redux-movement/support/collect-support.ps1": ROOT / "bg-redux-movement/support/collect-support.ps1",
}
README = """BG Pathfinding Redux - standalone support collector hotfix

This download only fixes Collect BG Redux Support. It does not install or change
movement code.

1. Extract this ZIP into the game directory containing Baldur.exe or BaldurII.exe.
2. Allow the existing bg-redux-movement folder to merge and replace files.
3. Double-click Collect BG Redux Support.cmd in the game directory.
4. Send the resulting bg-redux-support.log with the bug report.

This collector is read-only except for writing bg-redux-support.log. Nothing is
uploaded automatically.
"""


def main():
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    name = f"bg-redux-support-collector-{VERSION}.zip"
    archive = output / name
    entries = {path: source.read_bytes() for path, source in FILES.items()}
    entries["README.txt"] = README.encode("utf-8")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path, data in sorted(entries.items()):
            item = zipfile.ZipInfo(path, (2026, 10, 25, 0, 0, 0))
            item.compress_type = zipfile.ZIP_DEFLATED
            item.create_system = 3
            item.external_attr = 0o100644 << 16
            bundle.writestr(item, data, compresslevel=9)
    with zipfile.ZipFile(archive) as bundle:
        assert set(bundle.namelist()) == set(entries)
        assert bundle.testzip() is None
        for path, data in entries.items():
            assert bundle.read(path) == data
    digest = hashlib.sha256(archive.read_bytes()).hexdigest().upper()
    report = {"archive": name, "sha256": digest, "files": sorted(entries)}
    (output / "support-collector-build-report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
