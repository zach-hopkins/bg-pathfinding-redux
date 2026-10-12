"""Release integrity and offline Lua checks. Never launches the game."""
import argparse
import configparser
import ctypes
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'tests/.work'
RUNTIME = ROOT / 'bg-redux-movement/runtime/M_BGREDX.lua'
PIN = '130FF778053C3CC6F220B6E7F79BB82900E783F4143D3986A89E59E67B6C7C89'
PROFILE_PINS = {
    'bgee-steam-2.7.3.0': '338208EEF94D25CE5DB0E76D9F411CB0CBBCAFF5651755980DF5A24004B92D40',
    'bgee-steam-2.6.6.0': '383EB1FCCA3F2B807670CD8BB80B0467F0A821870F32A2CCE8D3CB612ADC506C',
    'bg2ee-2.6.6.0': '68268E27E4933DFB4E10E80CD8CDC2CC3F1DBB9C1BA90CE0A44AB3D1D0638AC4',
    'bg2ee-steam-2.7.3.0': '929C9F2E09E49D4AC5B9440E793A749F39AEB25628029B42BB0774346EBEA75F',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def executable_path(game):
    for name in ('Baldur.exe', 'BaldurII.exe', 'SiegeOfDragonspear.exe'):
        path=game/name
        if path.is_file(): return path
    raise FileNotFoundError('No recognized game executable in '+str(game))

def check_integrity():
    meta = json.loads((ROOT/'release.json').read_text(encoding='utf-8'))
    assert sha(RUNTIME) == PIN == meta['runtime_sha256'], 'Shipped selector changed'
    assert meta['revision'] == 56 and meta['policy_revision'] == 52
    profiles=json.loads((ROOT/'profiles.json').read_text(encoding='utf-8'))
    assert profiles==meta['profiles'] and {p['id'] for p in profiles}==set(PROFILE_PINS)
    loader=RUNTIME.read_text(encoding='utf-8')
    for profile in profiles:
        assert sha(ROOT/profile['runtime_path'])==profile['runtime_sha256']==PROFILE_PINS[profile['id']]
        assert profile['memory_fingerprint'] in loader and profile['runtime_path'] in loader
    assert meta['project_license'] == 'MIT'
    license_text = (ROOT/'LICENSE').read_text(encoding='utf-8')
    assert license_text.startswith('MIT License\n')
    assert 'Copyright (c) 2026 Zach Hopkins' in license_text
    assert 'The above copyright notice and this permission notice shall be included' in license_text
    config = configparser.ConfigParser()
    config.read(ROOT/'bg-redux-movement/defaults.ini', encoding='utf-8')
    for key in ('AttackSpacing','GentleSettle'):
        assert config.get('Movement',key) == '1' and meta['defaults'][key]
    assert not config.has_option('Movement','RoutePreference') and meta['defaults']['RoutePreference']
    assert config.get('Movement','EnemyPrototype')=='0' and not meta['defaults']['EnemyPrototype']
    assert config.get('Movement','OutOfCombatOnly')=='0' and not meta['defaults']['OutOfCombatOnly']
    assert not config.has_option('Movement','Movement') and meta['defaults']['Movement']
    for profile in profiles:
        source=(ROOT/profile['runtime_path']).read_text(encoding='utf-8')
        for name in ('bg_redux_combat.lua','bg_redux_release_config.lua','bg_redux_release_bootstrap.lua','bg_redux_public_logging.lua','bg_redux_support_context.lua'):
            fragment = (ROOT/'tests/fixtures'/name).read_text(encoding='utf-8')
            assert source.count(fragment) == 1, 'Fixture no longer matches accepted profile: '+name
    tp2 = (ROOT/'bg-redux-movement/bg-redux-movement.tp2').read_text(encoding='utf-8')
    for text in ('GAME_IS ~bgee bg2ee eet~','DESIGNATED 0','FILE_EXISTS ~EEex.dll~',
                 'FILE_EXISTS ~InfinityLoader.exe~','NOT FILE_EXISTS ~bg-redux-movement.ini~',
                 'COPY + ~bg-redux-movement/defaults.ini~ ~bg-redux-movement.ini~',
                 'COPY ~bg-redux-movement/runtime/M_BGREDX.lua~ ~override/M_BGREDX.lua~',
                 'NOT MOD_IS_INSTALLED ~mrdx-movement/mrdx-movement.tp2~ 0',
                 'NOT FILE_EXISTS ~override/M_MRIP.lua~',
                 'COPY + ~mrdx-movement.ini~ ~bg-redux-movement.ini~'):
        assert text in tp2, text
    assert 'REQUIRE_PREDICATE (FILE_MD5' not in tp2
    assert 'ACTION_IF NOT (FILE_MD5 EVALUATE_BUFFER' in tp2 and 'WARNING: Executable hash differs' in tp2
    assert 'REQUIRE_PREDICATE (FILE_EXISTS ~Baldur.exe~)' not in tp2
    assert 'FILE_EXISTS ~BaldurII.exe~' in tp2 and 'FILE_EXISTS ~SiegeOfDragonspear.exe~' in tp2
    assert 'data/PATCH27.BIF' in tp2 and 'profile-hint.lua.in' in tp2
    for profile in profiles:
        assert 'FILE_MD5 EVALUATE_BUFFER ~%bg_redux_exe%~ ~'+profile['exe_md5']+'~' in tp2
    print('Integrity: MIT license, dispatcher/profile hashes, metadata, session movement, opt-in enemy defaults, fixture linkage and native pins passed')
    return meta

def lua_check(script, lua=None, dll=None):
    if lua:
        subprocess.run([lua, str(script)], cwd=ROOT, check=True, timeout=60)
        return
    assert dll and os.name == 'nt', 'Supply --lua luajit or --lua-dll on Windows'
    lib = ctypes.CDLL(str(dll.resolve()))
    lib.luaL_newstate.restype = ctypes.c_void_p
    lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lib.luaL_loadfile.argtypes = [ctypes.c_void_p,ctypes.c_char_p]
    lib.luaL_loadfile.restype = ctypes.c_int
    lib.lua_pcall.argtypes = [ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int]
    lib.lua_pcall.restype = ctypes.c_int
    lib.lua_tolstring.argtypes = [ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
    lib.lua_tolstring.restype = ctypes.c_char_p
    lib.lua_close.argtypes = [ctypes.c_void_p]
    previous = Path.cwd()
    os.chdir(ROOT)
    state = lib.luaL_newstate()
    assert state, 'Lua state allocation failed'
    try:
        lib.luaL_openlibs(state)
        result = lib.luaL_loadfile(state,str(script.resolve()).encode('utf-8'))
        if not result:
            result = lib.lua_pcall(state,0,0,0)
        if result:
            raise RuntimeError(lib.lua_tolstring(state,-1,None).decode('utf-8',errors='replace'))
    finally:
        lib.lua_close(state)
        os.chdir(previous)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', help='LuaJIT executable for portable fixtures')
    parser.add_argument('--lua-dll',type=Path,help='Installed 64-bit lua51.dll on Windows')
    parser.add_argument('--game',type=Path,help='Read-only pinned BG2EE/EEex installation for native checks')
    parser.add_argument('--profile',choices=tuple(PROFILE_PINS),help='Reference profile for an unfamiliar executable; actual native bytes/bindings are still checked')
    args = parser.parse_args()
    meta=check_integrity()
    WORK.mkdir(parents=True,exist_ok=True)
    ran = ['integrity']
    if args.lua or args.lua_dll or args.game:
        dll = args.lua_dll
        if args.game and not dll and not args.lua:
            dll = args.game/'EEex/loader/LuaJIT/lua51.dll'
        lua_check(ROOT/'tests/configuration.lua', args.lua, dll)
        lua_check(ROOT/'tests/preference_budget.lua',args.lua,dll)
        ran.append('configuration: persistent enemy choice, session movement and optional settings')
        lua_check(ROOT/'tests/public_logging.lua',args.lua,dll)
        ran.append('quiet public logging and explicit diagnostics')
        lua_check(ROOT/'tests/support_context.lua',args.lua,dll)
        ran.append('safe diagnostic context')
        lua_check(ROOT/'tests/combat_only.lua',args.lua,dll)
        lua_check(ROOT/'tests/overlap_escape.lua',args.lua,dll)
        lua_check(ROOT/'tests/overlap_snapshot.lua',args.lua,dll)
        lua_check(ROOT/'tests/enemy_cooperation.lua',args.lua,dll)
        lua_check(ROOT/'tests/enemy_reservations.lua',args.lua,dll)
        ran.append('enemy cooperation, exclusive positions and bounded wait wrappers')
        ran.append('combat-only timers, selective collision and outward escape')
        ran.append('overlap escape policy and actual profile integration')
        lua_check(ROOT/'tests/profile_selection.lua',args.lua,dll)
        ran.append('profile selection and unsupported-build refusal')
        if args.game:
            game = args.game.resolve()
            executable=executable_path(game)
            profile=next((p for p in meta['profiles'] if p['id']==args.profile),None) if args.profile else next((p for p in meta['profiles'] if p['exe_sha256']==sha(executable)),None)
            assert profile, 'Unfamiliar executable: supply --profile to evaluate a reference layout'
            (WORK/'native').mkdir(exist_ok=True)
            subprocess.run([sys.executable,str(ROOT/'tools/inspect_bindings.py'),'--game',str(game),'--profile',profile['id']],
                           cwd=ROOT,check=True,timeout=30)
            settle_entry=WORK/'settle-signature-entry.lua'
            settle_entry.write_text('MRIP_TEST_EXECUTABLE_PATH='+json.dumps(executable.as_posix())+'\nMRIP_TEST_GAME_PATH='+json.dumps(game.as_posix())+'\nMRIP_TEST_RUNTIME_PATH='+json.dumps(profile['runtime_path'])+'\ndofile(\"tests/settle_native_signature.lua\")\n',encoding='utf-8')
            lua_check(settle_entry,args.lua,dll)
            ran.append(profile['id']+': lazy settle guard and registration against actual bytes')
            fixture=(ROOT/'tests/native_runtime.lua').read_text(encoding='utf-8')
            if profile['revision'] in (54,55,56):
                mappings={int(a,16):b for a,b in json.loads((ROOT/('tests/fixtures/native-rvas-bgee-2.7.json' if profile['revision']==56 else 'tests/fixtures/native-rvas-bgee-2.6.json' if profile['revision']==55 else 'tests/fixtures/native-rvas-2.7.json')).read_text()).items()}
                def rva(match):
                    value=int(match.group(),16)
                    if value in mappings:return f'0x{mappings[value]:X}'
                    for base in (0x140000000,0x180000000):
                        if value-base in mappings:return f'0x{base+mappings[value-base]:X}'
                    return match.group()
                fixture=re.sub(r'0x[\dA-Fa-f]+',rva,fixture)
            fixture_path=WORK/'native_runtime.lua'
            fixture_path.write_text(fixture,encoding='utf-8')
            for enabled,variant,development in ((False,False,False),(True,False,False),(True,True,False),(False,False,True),(True,False,True),(True,True,True)):
                entry = WORK/('native-on.lua' if enabled else 'native-off.lua')
                entry.write_text('MRIP_TEST_REVISION='+str(profile['revision'])+'\nMRIP_TEST_PROTOTYPE=true\n'
                                 'MRIP_TEST_PREFERENCE=true\nMRIP_TEST_RELEASE=true\nMRIP_TEST_DEVELOPMENT='+('true' if development else 'false')+'\n'
                                 'MRIP_TEST_GAME_PATH='+json.dumps(game.as_posix())+'\n'
                                 'MRIP_TEST_EXECUTABLE_PATH='+json.dumps(executable.as_posix())+'\n'
                                 'MRIP_TEST_VARIANT_HEADER='+('true' if variant else 'false')+'\n'
                                 'MRIP_TEST_RUNTIME_PATH='+json.dumps(profile['runtime_path'])+'\n'
                                 +("MRIP_TEST_RELEASE_INITIAL_VALUES={RoutePreference='1'}\n" if enabled else "MRIP_TEST_RELEASE_INITIAL_VALUES={RoutePreference='0'}\n")
                                 +("local fixture_loadfile=loadfile\nloadfile=function(path) if path=='bg-redux-movement/installed-profile.lua' then return function()return {profile="+json.dumps(profile['id'])+"}end end;return fixture_loadfile(path)end\n" if args.profile else '')
                                 +"local original_dofile=dofile\n"
                                 +"dofile=function(path) if path==MRIP_TEST_RUNTIME_PATH then if not MRIP_BaselineRevision then MRIP_DispatchLoaded=nil end;local saved_io=io;local selector=assert(io.open('bg-redux-movement/runtime/M_BGREDX.lua')):read('*a');selector=selector:gsub('MRIP_DevelopmentBuild=false','MRIP_DevelopmentBuild='..tostring(MRIP_TEST_DEVELOPMENT==true));io=nil;local ok,err=pcall(assert(loadstring(selector)));io=saved_io;if not ok then error(err) end;return end;return original_dofile(path) end\n"
                                 +"dofile('tests/.work/native_runtime.lua')\n",encoding='utf-8')
                lua_check(entry,args.lua,dll)
            ran.append(profile['id']+': dispatcher + native runtime, release/dev maps, legacy preference OFF/ON ignored and unfamiliar-header activation')
    result=dict(passed=True,checks=ran,game_launched=False,
                limits='Simulated Lua/EEex state plus actual bytes/layout when --game is supplied. No gameplay emulation.')
    (WORK/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()
