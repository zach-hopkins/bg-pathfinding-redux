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
    shutil.copytree(ROOT/'bg-redux-movement',lab/'bg-redux-movement')
    (lab/'weidu.conf').write_text('lang_dir = en_US\n',encoding='utf-8')
    (lab/'WeiDU.log').write_text('',encoding='utf-8')
    for name in ('EEex.dll','InfinityLoader.exe'):
        (lab/name).write_bytes(b'')
    if eet:
        (lab/'override/EET.flag').write_bytes(b'')
    overlay=lab/'override/M_BGREDX.lua'
    original=b'-- existing movement overlay fixture\r\n'
    overlay.write_bytes(original)
    other=lab/'override/UNRELATED.lua'
    other.write_bytes(b'-- unrelated fixture\r\n')
    tlk=sha(lab/'lang/en_US/dialog.tlk')
    key=sha(lab/'chitin.key')
    config=lab/'bg-redux-movement.ini'
    runtime=(ROOT/'bg-redux-movement/runtime/M_BGREDX.lua').read_bytes()
    def command(action,success=True,tp2='bg-redux-movement/bg-redux-movement.tp2',reason='Unsupported executable'):
        result=subprocess.run([str(weidu),'--noautoupdate','--skip-at-view','--language','0',
                               tp2,action,'0'],
                              cwd=lab,capture_output=True,text=True,timeout=30)
        with (lab/'installer-output.txt').open('a',encoding='utf-8') as log:
            log.write(result.stdout+result.stderr+'\n')
        if success:
            assert result.returncode==0 and 'ERROR' not in result.stdout and 'FATAL' not in result.stdout, result.stdout+result.stderr
        else:
            assert 'SKIPPING:' in result.stdout and reason in result.stdout and 'SUCCESSFULLY INSTALLED' not in result.stdout,result.stdout+result.stderr
    command('--force-install-list')
    assert overlay.read_bytes()==runtime
    assert config.read_bytes()==(ROOT/'bg-redux-movement/defaults.ini').read_bytes()
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
    # A lingering manual prototype is refused before touching either overlay.
    legacy_overlay=lab/'override/M_MRIP.lua'
    legacy_overlay.write_bytes(b'-- manually installed legacy prototype fixture\n')
    command('--force-install-list',success=False,reason='older movement overlay remains')
    assert not overlay.exists() and legacy_overlay.read_bytes().startswith(b'-- manually')
    legacy_overlay.unlink() # Only this deliberately created fixture file.
    # Exercise the real old WeiDU component ID, uninstall, and preference migration.
    legacy=lab/'mrdx-movement';legacy.mkdir()
    (legacy/'old.lua').write_bytes(b'-- old component overlay fixture\n')
    (legacy/'mrdx-movement.tp2').write_text(
        'BACKUP ~mrdx-movement/backup~\nAUTHOR ~upgrade fixture~\n'
        'BEGIN ~legacy movement upgrade fixture~\nDESIGNATED 0\n'
        'COPY ~mrdx-movement/old.lua~ ~override/M_MRIP.lua~\n',encoding='utf-8')
    config.unlink() # Only the named settings file in this disposable lab.
    old_config=lab/'mrdx-movement.ini';old_config.write_bytes(custom)
    command('--force-install-list',tp2='mrdx-movement/mrdx-movement.tp2')
    command('--force-install-list',success=False,reason='Uninstall the older component')
    assert legacy_overlay.exists() and not overlay.exists() and not config.exists()
    command('--force-uninstall-list',tp2='mrdx-movement/mrdx-movement.tp2')
    assert not legacy_overlay.exists()
    command('--force-install-list')
    assert config.read_bytes()==custom and old_config.read_bytes()==custom
    assert overlay.read_bytes()==runtime
    command('--force-uninstall-list')
    assert not overlay.exists() and config.read_bytes()==custom
    # A future/modified executable must be rejected before creating an overlay.
    with (lab/'Baldur.exe').open('ab') as file:file.write(b'future-build-fixture')
    command('--force-install-list',success=False)
    assert not overlay.exists() and config.read_bytes()==custom
    assert 'BG-REDUX-MOVEMENT' not in (lab/'WeiDU.log').read_text().upper()
    return dict(game='EET' if eet else 'BG2EE',passed=True,overlay_restored=True,
                new_overlay_removed=True,defaults_created=True,settings_preserved=True,
                dialogue_and_key_unchanged=True,unrelated_overlay_unchanged=True,
                unknown_executable_refused=True,legacy_component_refused=True,
                manual_legacy_overlay_refused=True,legacy_settings_migrated=True)

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
