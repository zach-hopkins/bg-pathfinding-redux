"""Build and verify a deterministic Windows installer ZIP from explicit inputs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile
from checks import ROOT, check_integrity

def digest(data):
    return hashlib.sha256(data).hexdigest().upper()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vendor-dir',type=Path,required=True,
                        help='Directory containing official weidu.exe, tagged source ZIP, and COPYING')
    args=parser.parse_args()
    meta=check_integrity()
    pin=json.loads((ROOT/'tools/weidu-provenance.json').read_text(encoding='utf-8'))
    binary=(args.vendor_dir/'weidu.exe').read_bytes()
    source=(args.vendor_dir/'weidu-v251.00-source.zip').read_bytes()
    license_data=(args.vendor_dir/'COPYING').read_bytes()
    assert digest(binary)==pin['binary_sha256'], 'WeiDU binary hash mismatch'
    assert digest(source)==pin['source_sha256'], 'WeiDU source hash mismatch'
    assert digest(license_data)==pin['license_sha256'], 'WeiDU license hash mismatch'
    with zipfile.ZipFile(io.BytesIO(source)) as z:
        license_paths=[name for name in z.namelist() if name.count('/')==1 and name.endswith('/COPYING')]
        assert len(license_paths)==1 and z.read(license_paths[0])==license_data
    files={
        'setup-bg-redux-movement.exe':binary,
        'bg-redux-movement/README.md':(ROOT/'bg-redux-movement/README.md').read_bytes(),
        'bg-redux-movement/bg-redux-movement.tp2':(ROOT/'bg-redux-movement/bg-redux-movement.tp2').read_bytes(),
        'bg-redux-movement/defaults.ini':(ROOT/'bg-redux-movement/defaults.ini').read_bytes(),
        'bg-redux-movement/runtime/M_BGREDX.lua':(ROOT/'bg-redux-movement/runtime/M_BGREDX.lua').read_bytes(),
        'bg-redux-movement/release.json':(ROOT/'release.json').read_bytes(),
        'bg-redux-movement/CHANGELOG.md':(ROOT/'CHANGELOG.md').read_bytes(),
        'bg-redux-movement/THIRD_PARTY_NOTICES.md':(ROOT/'THIRD_PARTY_NOTICES.md').read_bytes(),
        'bg-redux-movement/LICENSE':(ROOT/'LICENSE').read_bytes(),
        'bg-redux-movement/third_party/weidu/COPYING':license_data,
        'bg-redux-movement/third_party/weidu/source-v251.00.zip':source,
        'bg-redux-movement/third_party/weidu/provenance.json':(ROOT/'tools/weidu-provenance.json').read_bytes(),
    }
    files['bg-redux-movement/QUICKSTART.md']=(ROOT/'bg-redux-movement/QUICKSTART.md').read_bytes()
    files['bg-redux-movement/support/Collect BG Redux Support.cmd']=(ROOT/'bg-redux-movement/support/Collect BG Redux Support.cmd').read_bytes()
    files['Collect BG Redux Support.cmd']=(ROOT/'bg-redux-movement/support/Collect BG Redux Support.cmd').read_bytes()
    files['bg-redux-movement/support/collect-support.ps1']=(ROOT/'bg-redux-movement/support/collect-support.ps1').read_bytes()
    files['bg-redux-movement/runtime/profile-hint.lua.in']=(ROOT/'bg-redux-movement/runtime/profile-hint.lua.in').read_bytes()
    files['bg-redux-movement/profiles.json']=(ROOT/'profiles.json').read_bytes()
    for profile in meta['profiles']:
        files[profile['runtime_path']]=(ROOT/profile['runtime_path']).read_bytes()
    manifest=dict(meta,files={name:digest(data) for name,data in sorted(files.items())})
    files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode('utf-8')
    output=ROOT/'dist'
    output.mkdir(exist_ok=True)
    name=meta['name']+'-'+meta['version']+'-windows.zip'
    archive=output/name
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for path,data in sorted(files.items()):
            entry=zipfile.ZipInfo(path,(2026,10,7,0,0,0))
            entry.compress_type=zipfile.ZIP_DEFLATED
            entry.create_system=3
            entry.external_attr=0o100644<<16
            z.writestr(entry,data,compresslevel=9)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist())==len(files) and set(z.namelist())==set(files)
        assert z.testzip() is None
        for path,data in files.items():
            assert z.read(path)==data and not path.startswith('/') and '..' not in Path(path).parts
    archive_hash=digest(archive.read_bytes())
    (output/'SHA256SUMS.txt').write_text(archive_hash+'  '+name+'\n',encoding='utf-8')
    result=dict(archive=name,sha256=archive_hash,files=len(files),
                runtime_sha256=meta['runtime_sha256'],game_launched=False,
                project_license=meta['project_license'],published=False)
    (output/'build-report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    main()
