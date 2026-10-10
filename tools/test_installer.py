"""Exercise real WeiDU in fresh resource-only labs; never launch a game."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import uuid
from checks import ROOT, WORK, check_integrity, executable_path

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def exercise(weidu, game, eet):
    lab=WORK/('installer-'+('eet-' if eet else 'bg2ee-')+uuid.uuid4().hex[:8])
    (lab/'override').mkdir(parents=True)
    (lab/'lang/en_US').mkdir(parents=True)
    shutil.copyfile(executable_path(game),lab/'Baldur.exe')
    for name in ('chitin.key','lang/en_US/dialog.tlk'):
        shutil.copyfile(game/name,lab/name)
    newer=(game/'data/PATCH27.BIF').exists()
    if newer:
        (lab/'data').mkdir();(lab/'data/PATCH27.BIF').write_bytes(b'')
    shutil.copytree(ROOT/'bg-redux-movement',lab/'bg-redux-movement')
    (lab/'weidu.conf').write_text('lang_dir = en_US\n',encoding='utf-8')
    (lab/'WeiDU.log').write_text('',encoding='utf-8')
    for name in ('EEex.dll','InfinityLoader.exe'):
        (lab/name).write_bytes(b'')
    if eet:
        (lab/'override/EET.flag').write_bytes(b'')
    loader_ini=lab/'InfinityLoader.ini'
    original_ini=b'[General]\r\nLogFile=\r\nDebug=0\r\n'
    loader_ini.write_bytes(original_ini)
    overlay=lab/'override/M_BGREDX.lua'
    original=b'-- existing movement overlay fixture\r\n'
    overlay.write_bytes(original)
    other=lab/'override/UNRELATED.lua'
    other.write_bytes(b'-- unrelated fixture\r\n')
    tlk=sha(lab/'lang/en_US/dialog.tlk')
    key=sha(lab/'chitin.key')
    config=lab/'bg-redux-movement.ini'
    runtime=(ROOT/'bg-redux-movement/runtime/M_BGREDX.lua').read_bytes()
    def command(action,success=True,tp2='bg-redux-movement/bg-redux-movement.tp2',reason='Unused default refusal reason'):
        result=subprocess.run([str(weidu),'--noautoupdate','--skip-at-view','--language','0',
                               tp2,action,'0'],
                              cwd=lab,capture_output=True,text=True,timeout=30)
        with (lab/'installer-output.txt').open('a',encoding='utf-8') as log:
            log.write(result.stdout+result.stderr+'\n')
        if success:
            assert result.returncode==0 and 'ERROR' not in result.stdout and 'FATAL' not in result.stdout, result.stdout+result.stderr
        else:
            assert 'SKIPPING:' in result.stdout and reason in result.stdout and 'SUCCESSFULLY INSTALLED' not in result.stdout,result.stdout+result.stderr
        return result.stdout+result.stderr
    clean_output=command('--force-install-list')
    assert 'WARNING: Executable hash differs from the verified builds.' not in clean_output
    assert overlay.read_bytes()==runtime
    hint=lab/'bg-redux-movement/installed-profile.lua'
    assert ('2.7.3.0' if newer else '2.6.6.0') in hint.read_text(encoding='utf-8')
    assert 'LogFile=bg-redux-runtime.log' in loader_ini.read_text()
    assert (lab/'Collect BG Redux Support.cmd').is_file()
    assert config.read_bytes()==(ROOT/'bg-redux-movement/defaults.ini').read_bytes()
    custom=b'[Movement]\r\nMovement=0\r\nAttackSpacing=1\r\nGentleSettle=0\r\nRoutePreference=0\r\n'
    config.write_bytes(custom)
    command('--force-uninstall-list')
    assert overlay.read_bytes()==original and config.read_bytes()==custom
    assert loader_ini.read_bytes()==original_ini
    assert not hint.exists()
    assert not (lab/'Collect BG Redux Support.cmd').exists()
    custom_ini=b'[General]\r\nLogFile=existing custom.log\r\nDebug=0\r\n'
    loader_ini.write_bytes(custom_ini)
    overlay.unlink() # The single named file in this freshly created fixture.
    command('--force-install-list')
    assert overlay.read_bytes()==runtime and config.read_bytes()==custom
    assert loader_ini.read_bytes()==custom_ini
    command('--force-uninstall-list')
    assert not overlay.exists() and config.read_bytes()==custom
    # A storefront filename, and then a custom name, are not installation gates.
    (lab/'Baldur.exe').rename(lab/'BaldurII.exe')
    renamed_output=command('--force-install-list')
    assert 'WARNING: Executable hash differs from the verified builds.' not in renamed_output
    assert overlay.read_bytes()==runtime and config.read_bytes()==custom and hint.exists()
    command('--force-uninstall-list')
    assert not hint.exists()
    (lab/'BaldurII.exe').rename(lab/'CustomGame.exe')
    (lab/'InfinityLoader.exe').rename(lab/'CustomLoader.exe')
    command('--force-install-list')
    assert overlay.read_bytes()==runtime and config.read_bytes()==custom
    command('--force-uninstall-list')
    (lab/'CustomGame.exe').rename(lab/'Baldur.exe')
    (lab/'CustomLoader.exe').rename(lab/'InfinityLoader.exe')
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
    # A modified full-file hash warns and installs; runtime identity/site checks remain.
    with (lab/'Baldur.exe').open('ab') as file:file.write(b'future-build-fixture')
    modified_output=command('--force-install-list')
    assert overlay.read_bytes()==runtime and config.read_bytes()==custom
    assert 'WARNING: Executable hash differs from the verified builds.' in modified_output
    command('--force-uninstall-list')
    assert not overlay.exists() and config.read_bytes()==custom
    installed_lines=[line for line in (lab/'WeiDU.log').read_text().upper().splitlines() if not line.lstrip().startswith('//')]
    assert not any('BG-REDUX-MOVEMENT' in line for line in installed_lines)
    return dict(game='EET-marker lab' if eet else 'BGEE/SoD' if hashlib.sha256(executable_path(game).read_bytes()).hexdigest().upper()in ('9634C3E685A9D2F467D663B2E211065F9D4D84FD3115B89AC24DCA2071D618B1','187F89E1033999B2C8EAE6591641325BA012071030364767F42221ECAE92372A') else 'BG2EE',passed=True,overlay_restored=True,
                new_overlay_removed=True,defaults_created=True,settings_preserved=True,
                dialogue_and_key_unchanged=True,unrelated_overlay_unchanged=True,
                modified_executable_warned=True,modified_executable_installed=True,blank_logging_enabled=True,custom_log_preserved=True,loader_ini_restored=True,collector_installed=True,legacy_component_refused=True,
                manual_legacy_overlay_refused=True,legacy_settings_migrated=True,storefront_and_custom_names_allowed=True,profile_hint_installed_and_rolled_back=True)

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
