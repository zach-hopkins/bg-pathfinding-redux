"""Exercise real WeiDU in fresh resource-only labs; never launch a game."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import uuid
from checks import ROOT, WORK, check_integrity

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def exercise(weidu, game, eet):
    lab=WORK/('installer-'+('eet-' if eet else 'bg2ee-')+uuid.uuid4().hex[:8])
    (lab/'override').mkdir(parents=True)
    (lab/'lang/en_US').mkdir(parents=True)
    for name in ('Baldur.exe','chitin.key','lang/en_US/dialog.tlk'):
        shutil.copyfile(game/name,lab/name)
    shutil.copytree(ROOT/'mrdx-movement',lab/'mrdx-movement')
    (lab/'weidu.conf').write_text('lang_dir = en_US\n',encoding='utf-8')
    (lab/'WeiDU.log').write_text('',encoding='utf-8')
    for name in ('EEex.dll','InfinityLoader.exe'):
        (lab/name).write_bytes(b'')
    if eet:
        (lab/'override/EET.flag').write_bytes(b'')
    overlay=lab/'override/M_MRIP.lua'
    original=b'-- existing movement overlay fixture\r\n'
    overlay.write_bytes(original)
    other=lab/'override/UNRELATED.lua'
    other.write_bytes(b'-- unrelated fixture\r\n')
    tlk=sha(lab/'lang/en_US/dialog.tlk')
    key=sha(lab/'chitin.key')
    config=lab/'mrdx-movement.ini'
    runtime=(ROOT/'mrdx-movement/runtime/M_MRIP.lua').read_bytes()
    def command(action,success=True):
        result=subprocess.run([str(weidu),'--noautoupdate','--skip-at-view','--language','0',
                               'mrdx-movement/mrdx-movement.tp2',action,'0'],
                              cwd=lab,capture_output=True,text=True,timeout=30)
        with (lab/'installer-output.txt').open('a',encoding='utf-8') as log:
            log.write(result.stdout+result.stderr+'\n')
        if success:
            assert result.returncode==0 and 'ERROR' not in result.stdout and 'FATAL' not in result.stdout, result.stdout+result.stderr
        else:
            assert 'SKIPPING:' in result.stdout and 'Unsupported executable' in result.stdout and 'SUCCESSFULLY INSTALLED' not in result.stdout,result.stdout+result.stderr
    command('--force-install-list')
    assert overlay.read_bytes()==runtime
    assert config.read_bytes()==(ROOT/'mrdx-movement/defaults.ini').read_bytes()
    custom=b'[Movement]\r\nMovement=0\r\nAttackSpacing=1\r\nGentleSettle=0\r\nRoutePreference=0\r\n'
    config.write_bytes(custom)
    command('--force-uninstall-list')
    assert overlay.read_bytes()==original and config.read_bytes()==custom
    overlay.unlink() # The single named file in this freshly created fixture.
    command('--force-install-list')
    assert overlay.read_bytes()==runtime and config.read_bytes()==custom
    command('--force-uninstall-list')
    assert not overlay.exists() and config.read_bytes()==custom
    assert sha(lab/'lang/en_US/dialog.tlk')==tlk and sha(lab/'chitin.key')==key
    assert other.read_bytes()==b'-- unrelated fixture\r\n'
    # A future/modified executable must be rejected before creating an overlay.
    with (lab/'Baldur.exe').open('ab') as file:file.write(b'future-build-fixture')
    command('--force-install-list',success=False)
    assert not overlay.exists() and config.read_bytes()==custom
    assert 'MRDX-MOVEMENT' not in (lab/'WeiDU.log').read_text().upper()
    return dict(game='EET' if eet else 'BG2EE',passed=True,overlay_restored=True,
                new_overlay_removed=True,defaults_created=True,settings_preserved=True,
                dialogue_and_key_unchanged=True,unrelated_overlay_unchanged=True,
                unknown_executable_refused=True)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--weidu',type=Path,required=True)
    parser.add_argument('--game',type=Path,required=True,help='Local BG2EE resources copied read-only into disposable labs')
    args=parser.parse_args()
    check_integrity()
    WORK.mkdir(parents=True,exist_ok=True)
    results=[exercise(args.weidu.resolve(),args.game.resolve(),eet) for eet in (False,True)]
    report=dict(passed=True,checks=results,game_launched=False,
                limits='Real WeiDU with copied local resources and prerequisite presence markers; no game emulation.')
    (WORK/'installer.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    main()
