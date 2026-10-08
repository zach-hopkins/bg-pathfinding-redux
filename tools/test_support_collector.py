"""Exercise the Windows collector with disposable logs; never start a game."""
import argparse
import hashlib
import json
import subprocess
import uuid
from pathlib import Path
from checks import ROOT, WORK


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--powershell', default='powershell.exe')
    args = parser.parse_args()
    lab = WORK / ('support-' + uuid.uuid4().hex[:8])
    (lab/'bg-redux-movement/runtime/profiles').mkdir(parents=True)
    (lab/'override').mkdir()
    (lab/'Baldur.exe').write_bytes(b'fixture executable, not runnable')
    (lab/'override/M_BGREDX.lua').write_text('-- selector fixture\n')
    (lab/'bg-redux-movement/runtime/profiles/fixture.lua').write_text('-- profile fixture\n')
    profile = dict(id='fixture', revision=56, runtime_path='bg-redux-movement/runtime/profiles/fixture.lua',
                   runtime_sha256=hashlib.sha256((lab/'bg-redux-movement/runtime/profiles/fixture.lua').read_bytes()).hexdigest().upper())
    (lab/'bg-redux-movement/profiles.json').write_text(json.dumps([profile]))
    (lab/'bg-redux-movement/release.json').write_text('{"version":"support-fixture"}')
    (lab/'bg-redux-movement.ini').write_text('[Movement]\nMovement=1\n')
    (lab/'WeiDU.log').write_text('~FIXTURE.TP2~ #0 #0 // fixture mod\n')
    ini = lab/'InfinityLoader.ini'
    log = lab/'custom output.log'
    report = lab/'report.log'

    def collect():
        before = {p.name: p.read_bytes() for p in (ini, log, lab/'Baldur.exe') if p.exists()}
        cp = subprocess.run([args.powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                             str(ROOT/'bg-redux-movement/support/collect-support.ps1'),
                             '-GameDirectory', str(lab.resolve()), '-OutputPath', str(report.resolve())],
                            capture_output=True, text=True, timeout=30)
        assert cp.returncode == 0, cp.stdout + cp.stderr
        for name, content in before.items():
            assert (lab/name).read_bytes() == content, name
        return report.read_text(encoding='utf-8')

    ini.write_text('[General]\nLogFile="custom output.log"\n')
    log.write_text('[BG Pathfinding Redux] PROFILE_SELECTED package=fixture\n'
                   '[BG Redux] START label=fixture\n[BG Redux] SNAPSHOT fixture\n'
                   '[BG Redux] PARTY area="ARTEST"\n' + str(lab.resolve()) + '\n')
    text = collect()
    assert 'Movement capture present' in text and 'snapshots present' in text
    assert 'ARTEST' in text and 'support-fixture' in text and 'fixture mod' in text
    assert str(lab.resolve()) not in text and '[GAME]' in text
    assert hashlib.sha256((lab/'Baldur.exe').read_bytes()).hexdigest().upper() in text
    assert 'EEex.dll : [MISSING]' in text
    (lab/'Baldur.exe').rename(lab/'BaldurII.exe')
    text=collect()
    assert 'BaldurII.exe : bytes=' in text and 'Baldur.exe : [MISSING]' in text
    assert hashlib.sha256((lab/'BaldurII.exe').read_bytes()).hexdigest().upper() in text
    (lab/'BaldurII.exe').rename(lab/'Baldur.exe')
    log.unlink()  # Only the named log created in this disposable fixture.
    text = collect()
    assert '[MISSING]' in text and 'NO MOVEMENT CAPTURE RECORDED' in text
    ini.write_text('[General]\nLogFile=\n')
    assert 'logging is not configured' in collect()
    ini.write_text('[General]\nLogFile="' + str(log.resolve()) + '"\n')
    log.write_bytes(b'x' * (5 * 1024 * 1024) + b'\n[BG Redux] SETTLE_ERROR fixture\n')
    text = collect()
    assert '[TRUNCATED:' in text and 'SETTLE_ERROR fixture' in text
    assert len(report.read_bytes()) < 4300000
    print('Support collector passed: custom/quoted/absolute paths, hashes, missing information, '
          'bounded logs, path redaction, and read-only inputs')


if __name__ == '__main__':
    main()
