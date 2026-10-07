"""Download only the pinned official WeiDU release inputs; never execute them."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile
from checks import ROOT

def fetch(url):
    request=urllib.request.Request(url,headers={'User-Agent':'bg-pathfinding-redux-release-builder'})
    with urllib.request.urlopen(request,timeout=45) as response:
        return response.read()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'.vendor')
    args=parser.parse_args()
    pin=json.loads((ROOT/'tools/weidu-provenance.json').read_text(encoding='utf-8'))
    windows=fetch(pin['binary_url'])
    source=fetch(pin['source_url'])
    with zipfile.ZipFile(io.BytesIO(windows)) as z:
        names=[name for name in z.namelist() if name.lower().endswith('/weidu.exe') or name.lower()=='weidu.exe']
        assert len(names)==1
        binary=z.read(names[0])
    with zipfile.ZipFile(io.BytesIO(source)) as z:
        names=[name for name in z.namelist() if name.count('/')==1 and name.endswith('/COPYING')]
        assert len(names)==1
        license_data=z.read(names[0])
    for name,data in [('binary',binary),('source',source),('license',license_data)]:
        assert hashlib.sha256(data).hexdigest().upper()==pin[name+'_sha256'], name+' hash mismatch'
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/'weidu.exe').write_bytes(binary)
    (args.output/'weidu-v251.00-source.zip').write_bytes(source)
    (args.output/'COPYING').write_bytes(license_data)
    print('Verified official WeiDU 251 executable, corresponding source, and license saved; no executable started')

if __name__=='__main__':
    main()
