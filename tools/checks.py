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
PIN = '33B7B782E0EC975608AD98D01A30F760707F4015A8DE2B3898B52D21FC3526E0'
PROFILE_PINS = {
    'bg2ee-2.6.6.0': '50A501510936EC4099700E1AE9921EDFFF6B9588B10C68E03D0372FDFC4CF230',
    'bg2ee-steam-2.7.3.0': 'C8563E03D0D251C34CB47FA2FD89F5F3D07BBF56F8000BA9CBABA660C7F018AA',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def check_integrity():
    meta = json.loads((ROOT/'release.json').read_text(encoding='utf-8'))
    assert sha(RUNTIME) == PIN == meta['runtime_sha256'], 'Shipped selector changed'
    assert meta['revision'] == 54 and meta['policy_revision'] == 52
    profiles=json.loads((ROOT/'profiles.json').read_text(encoding='utf-8'))
    assert profiles==meta['profiles'] and {p['id'] for p in profiles}==set(PROFILE_PINS)
    loader=RUNTIME.read_text(encoding='utf-8')
    for profile in profiles:
        assert sha(ROOT/profile['runtime_path'])==profile['runtime_sha256']==PROFILE_PINS[profile['id']]
        assert profile['fingerprint'] in loader and profile['runtime_path'] in loader
    assert meta['project_license'] == 'MIT'
    license_text = (ROOT/'LICENSE').read_text(encoding='utf-8')
    assert license_text.startswith('MIT License\n')
    assert 'Copyright (c) 2026 Zach Hopkins' in license_text
    assert 'The above copyright notice and this permission notice shall be included' in license_text
    config = configparser.ConfigParser()
    config.read(ROOT/'bg-redux-movement/defaults.ini', encoding='utf-8')
    for key in ('Movement','AttackSpacing','GentleSettle','RoutePreference'):
        assert config.get('Movement',key) == '1' and meta['defaults'][key]
    for profile in profiles:
        source=(ROOT/profile['runtime_path']).read_text(encoding='utf-8')
        for name in ('bg_redux_release_config.lua','bg_redux_release_bootstrap.lua','bg_redux_public_logging.lua'):
            fragment = (ROOT/'tests/fixtures'/name).read_text(encoding='utf-8')
            assert source.count(fragment) == 1, 'Fixture no longer matches accepted profile: '+name
    tp2 = (ROOT/'bg-redux-movement/bg-redux-movement.tp2').read_text(encoding='utf-8')
    for text in ('GAME_IS ~bg2ee eet~','DESIGNATED 0','FILE_EXISTS ~EEex.dll~',
                 'FILE_EXISTS ~InfinityLoader.exe~','NOT FILE_EXISTS ~bg-redux-movement.ini~',
                 'COPY + ~bg-redux-movement/defaults.ini~ ~bg-redux-movement.ini~',
                 'COPY ~bg-redux-movement/runtime/M_BGREDX.lua~ ~override/M_BGREDX.lua~',
                 'NOT MOD_IS_INSTALLED ~mrdx-movement/mrdx-movement.tp2~ 0',
                 'NOT FILE_EXISTS ~override/M_MRIP.lua~',
                 'COPY + ~mrdx-movement.ini~ ~bg-redux-movement.ini~'):
        assert text in tp2, text
    for profile in profiles:
        assert 'FILE_MD5 ~Baldur.exe~ ~'+profile['exe_md5']+'~' in tp2
    print('Integrity: MIT license, dispatcher and both shipped profile hashes, metadata, four ON defaults, fixture linkage, exact executable installer gates passed')
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
    args = parser.parse_args()
    meta=check_integrity()
    WORK.mkdir(parents=True,exist_ok=True)
    ran = ['integrity']
    if args.lua or args.lua_dll or args.game:
        dll = args.lua_dll
        if args.game and not dll and not args.lua:
            dll = args.game/'EEex/loader/LuaJIT/lua51.dll'
        lua_check(ROOT/'tests/configuration.lua', args.lua, dll)
        ran.append('configuration: 326 assertions')
        lua_check(ROOT/'tests/public_logging.lua',args.lua,dll)
        ran.append('quiet public logging and explicit diagnostics')
        lua_check(ROOT/'tests/profile_selection.lua',args.lua,dll)
        ran.append('profile selection and unsupported-build refusal')
        if args.game:
            game = args.game.resolve()
            profile=next((p for p in meta['profiles'] if p['exe_sha256']==sha(game/'Baldur.exe')),None)
            assert profile, 'Unsupported executable for native fixture'
            (WORK/'native').mkdir(exist_ok=True)
            subprocess.run([sys.executable,str(ROOT/'tools/inspect_bindings.py'),'--game',str(game),'--profile',profile['id']],
                           cwd=ROOT,check=True,timeout=30)
            fixture=(ROOT/'tests/native_runtime.lua').read_text(encoding='utf-8')
            if profile['revision']==54:
                mappings={int(a,16):b for a,b in json.loads((ROOT/'tests/fixtures/native-rvas-2.7.json').read_text()).items()}
                def rva(match):
                    value=int(match.group(),16)
                    if value in mappings:return f'0x{mappings[value]:X}'
                    for base in (0x140000000,0x180000000):
                        if value-base in mappings:return f'0x{base+mappings[value-base]:X}'
                    return match.group()
                fixture=re.sub(r'0x[\dA-Fa-f]+',rva,fixture)
            fixture_path=WORK/'native_runtime.lua'
            fixture_path.write_text(fixture,encoding='utf-8')
            for enabled in (False,True):
                entry = WORK/('native-on.lua' if enabled else 'native-off.lua')
                entry.write_text('MRIP_TEST_REVISION='+str(profile['revision'])+'\nMRIP_TEST_PROTOTYPE=true\n'
                                 'MRIP_TEST_PREFERENCE=true\nMRIP_TEST_RELEASE=true\n'
                                 'MRIP_TEST_GAME_PATH='+json.dumps(game.as_posix())+'\n'
                                 'MRIP_TEST_RUNTIME_PATH='+json.dumps(profile['runtime_path'])+'\n'
                                 +("MRIP_TEST_RELEASE_INITIAL_VALUES={RoutePreference='1'}\n" if enabled else '')
                                 +"local original_open,original_dofile=io.open,dofile\n"
                                 +"io.open=function(path,mode) return original_open(path=='Baldur.exe' and MRIP_TEST_GAME_PATH..'/Baldur.exe' or path,mode) end\n"
                                 +"dofile=function(path) if path==MRIP_TEST_RUNTIME_PATH then if not MRIP_BaselineRevision then MRIP_DispatchLoaded=nil end;return original_dofile('bg-redux-movement/runtime/M_BGREDX.lua') end;return original_dofile(path) end\n"
                                 +"dofile('tests/.work/native_runtime.lua')\n",encoding='utf-8')
                lua_check(entry,args.lua,dll)
            ran.append(profile['id']+': dispatcher + native runtime, preference OFF and ON')
    result=dict(passed=True,checks=ran,game_launched=False,
                limits='Simulated Lua/EEex state plus actual bytes/layout when --game is supplied. No gameplay emulation.')
    (WORK/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()
