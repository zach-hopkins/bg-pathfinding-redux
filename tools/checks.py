"""Release integrity and offline Lua checks. Never launches the game."""
import argparse
import configparser
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / 'tests/.work'
RUNTIME = ROOT / 'mrdx-movement/runtime/M_MRIP.lua'
PIN = '5B4B657326FEE0E3DE868C01753965C71C7995C4E3F07719BBBFEF75CAD9D218'
GAME_PIN = 'FC821A4806A0305B84FD85F1AAD2BD472C8DB642ED34B4494AE62351CAE1C580'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def check_integrity():
    meta = json.loads((ROOT/'release.json').read_text(encoding='utf-8'))
    assert sha(RUNTIME) == PIN == meta['runtime_sha256'], 'Accepted runtime changed'
    assert meta['revision'] == 53 and meta['policy_revision'] == 52
    assert meta['executable_sha256'] == GAME_PIN
    assert meta['project_license'] == 'MIT'
    license_text = (ROOT/'LICENSE').read_text(encoding='utf-8')
    assert license_text.startswith('MIT License\n')
    assert 'Copyright (c) 2026 Zach Hopkins' in license_text
    assert 'The above copyright notice and this permission notice shall be included' in license_text
    config = configparser.ConfigParser()
    config.read(ROOT/'mrdx-movement/defaults.ini', encoding='utf-8')
    for key in ('Movement','AttackSpacing','GentleSettle','RoutePreference'):
        assert config.get('Movement',key) == '1' and meta['defaults'][key]
    source = RUNTIME.read_text(encoding='utf-8')
    for name in ('mrip_release_config.lua','mrip_release_bootstrap.lua'):
        fragment = (ROOT/'tests/fixtures'/name).read_text(encoding='utf-8')
        assert source.count(fragment) == 1, 'Fixture no longer matches installed runtime: '+name
    tp2 = (ROOT/'mrdx-movement/mrdx-movement.tp2').read_text(encoding='utf-8')
    for text in ('GAME_IS ~bg2ee eet~','DESIGNATED 0','FILE_EXISTS ~EEex.dll~',
                 'FILE_EXISTS ~InfinityLoader.exe~','NOT FILE_EXISTS ~mrdx-movement.ini~',
                 'COPY + ~mrdx-movement/defaults.ini~ ~mrdx-movement.ini~',
                 'COPY ~mrdx-movement/runtime/M_MRIP.lua~ ~override/M_MRIP.lua~'):
        assert text in tp2, text
    print('Integrity: MIT license, accepted runtime hash, release metadata, four ON defaults, fixture linkage, and BG2EE/EET installer gates passed')
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
    check_integrity()
    WORK.mkdir(parents=True,exist_ok=True)
    ran = ['integrity']
    if args.lua or args.lua_dll or args.game:
        dll = args.lua_dll
        if args.game and not dll and not args.lua:
            dll = args.game/'EEex/loader/LuaJIT/lua51.dll'
        lua_check(ROOT/'tests/configuration.lua', args.lua, dll)
        ran.append('configuration: 326 assertions')
        if args.game:
            game = args.game.resolve()
            assert sha(game/'Baldur.exe') == GAME_PIN, 'Unsupported executable for native fixture'
            (WORK/'native').mkdir(exist_ok=True)
            subprocess.run([sys.executable,str(ROOT/'tools/inspect_bindings.py'),'--game',str(game)],
                           cwd=ROOT,check=True,timeout=30)
            for enabled in (False,True):
                entry = WORK/('native-on.lua' if enabled else 'native-off.lua')
                entry.write_text('MRIP_TEST_REVISION=53\nMRIP_TEST_PROTOTYPE=true\n'
                                 'MRIP_TEST_PREFERENCE=true\nMRIP_TEST_RELEASE=true\n'
                                 'MRIP_TEST_GAME_PATH='+json.dumps(game.as_posix())+'\n'
                                 +("MRIP_TEST_RELEASE_INITIAL_VALUES={RoutePreference='1'}\n" if enabled else '')
                                 +"dofile('tests/native_runtime.lua')\n",encoding='utf-8')
                lua_check(entry,args.lua,dll)
            ran.append('native runtime: preference OFF and ON')
    result=dict(passed=True,checks=ran,game_launched=False,
                limits='Simulated Lua/EEex state plus actual bytes/layout when --game is supplied. No gameplay emulation.')
    (WORK/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__ == '__main__':
    main()
