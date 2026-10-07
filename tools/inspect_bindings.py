"""Read offset registration constants from the installed LuaBindings binary.

No game launch or DLL initialization. RVAs identify primary registration
instructions; member names, numeric load and values are verified independently
of the prototype's guard and native fixture.
"""
import hashlib
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parent.parent
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--game',type=Path,required=True)
args=parser.parse_args()
binding=args.game/'LuaBindings.dll'

def binding_layout():
    data = binding.read_bytes()
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    table = pe + 24 + struct.unpack_from('<H', data, pe+20)[0]
    sections = [struct.unpack_from('<IIII', data, table+40*i+8)
                for i in range(struct.unpack_from('<H', data, pe+6)[0])]
    def read(rva, size):
        for _,start,length,raw in sections:
            if start <= rva and rva+size <= start+length:
                return data[raw+rva-start:raw+rva-start+size]
        raise AssertionError(f'unmapped binding RVA {rva:X}')
    specs = {
        'CGameObject.m_id': (0x46DE7A, 'm_id', 0x48),
        'CGameObject.m_objectType': (0x46DDAF, 'm_objectType', 8),
        'CGameObject.m_typeAI': (0x46DE5D, 'm_typeAI', 0x30),
        'CAIObjectType.m_EnemyAlly': (0x469034, 'm_EnemyAlly', 8),
        'CGameObject.m_pos': (0x46DDCC, 'm_pos', 0xC),
        'CGameObject.m_pArea': (0x46DE06, 'm_pArea', 0x18),
        'CGameAIBase.m_curAction': (0x47DB1B, 'm_curAction', 0x3F8),
        'CAIAction.m_actionID': (0x4695EA, 'm_actionID', 0),
        'CGameSprite.m_baseStats': (0x486B1D, 'm_baseStats', 0x560),
        'CGameSprite.m_derivedStats': (0x486C96, 'm_derivedStats', 0x1120),
        'CGameSprite.m_tempStats': (0x486CB3, 'm_tempStats', 0x1DC8),
        'CCreatureFileHeader.m_generalState': (0x45D1C7, 'm_generalState', 0x18),
        'CDerivedStats.m_generalState': (0x45859C, 'm_generalState', 0),
        'CGameSprite.m_bAllowEffectListCall': (0x488857, 'm_bAllowEffectListCall', 0x4EA4),
        'EEex_CBaldurChitin.m_pObjectGame': (0x46192A, 'm_pObjectGame', 0x1090),
        'EEex_CInfGame.m_charactersPortrait': (0x44E792, 'm_charactersPortrait', 0x6618),
    }
    members, evidence = {}, []
    for path,(rva,name,expected) in specs.items():
        code=read(rva,7)
        assert code[:3]==b'\x48\x8d\x15',path
        string_rva=rva+7+struct.unpack_from('<i',code,3)[0]
        assert read(string_rva,len(name)+1)==name.encode()+b'\0',path
        prefix=read(rva-8,8)
        if prefix[:4]==b'\xf2\x0f\x10\x15':
            constant_rva=rva+struct.unpack_from('<i',prefix,4)[0]
            value=struct.unpack('<d',read(constant_rva,8))[0]
        else:
            assert prefix[-3:]==b'\x0f\x57\xd2',path
            constant_rva=None;value=0
        assert value==expected, f'{path}: actual {value}, expected {expected}'
        members[path]=int(value)
        evidence.append(dict(path=path,registration_rva=hex(rva),
            constant_rva=hex(constant_rva) if constant_rva else None,offset=int(value)))
    # Verify actual usertype metadata registrations. The LEA r8 preceding
    # LEA rdx of usertype_<member> supplies its declared type string.
    type_specs={
        'CGameObject.m_typeAI': (0x46DCA1,'CAIObjectType'),
        'CGameAIBase.m_curAction': (0x47D34E,'CAIAction'),
        'CGameSprite.m_baseStats': (0x4845F0,'CCreatureFileHeader'),
        'CGameSprite.m_derivedStats': (0x48475C,'CDerivedStats'),
        'CGameSprite.m_tempStats': (0x484778,'CDerivedStats'),
        'EEex_CBaldurChitin.m_pObjectGame': (0x4613D7,'EEex_CInfGame'),
    }
    def cstring(rva):
        result=bytearray()
        while True:
            char=read(rva+len(result),1)[0]
            if not char:return result.decode('ascii')
            result.append(char)
            assert len(result)<128
    usertypes,type_evidence={},[]
    for path,(rva,expected_type) in type_specs.items():
        code=read(rva,7);assert code[:3]==b'\x48\x8d\x15',path
        name_rva=rva+7+struct.unpack_from('<i',code,3)[0]
        assert cstring(name_rva)=='usertype_'+path.split('.')[1],path
        value=read(rva-7,7);assert value[:3]==b'\x4c\x8d\x05',path
        type_rva=rva+struct.unpack_from('<i',value,3)[0]
        declared=cstring(type_rva);assert declared==expected_type,path
        usertypes[path]=declared
        type_evidence.append(dict(path=path,registration_rva=hex(rva),declared_type=declared,type_string_rva=hex(type_rva)))
    fields=[
        'CGameSprite.m_id','CGameSprite.m_objectType',
        'CGameSprite.m_typeAI.m_EnemyAlly','CGameSprite.m_pos',
        'CGameSprite.m_pArea','CGameSprite.m_curAction.m_actionID',
        'CGameSprite.m_baseStats.m_generalState',
        'CGameSprite.m_derivedStats.m_generalState',
        'CGameSprite.m_tempStats.m_generalState',
        'CGameSprite.m_bAllowEffectListCall',
        'EEex_CBaldurChitin.m_pObjectGame','EEex_CInfGame.m_charactersPortrait',
    ]
    parents={'CGameSprite':'CGameAIBase','CGameAIBase':'CGameObject'}
    def member_path(cls,member):
        while cls+'.'+member not in members:
            cls=parents[cls]
        return cls+'.'+member
    offsets={}
    for field in fields:
        cls,*parts=field.split('.');total=0
        for i,member in enumerate(parts):
            path=member_path(cls,member);total+=members[path]
            if i<len(parts)-1:cls=usertypes[path]
        offsets[field]=total
    classes=sorted({p.split('.')[0] for p in members})
    # Names must be entire NUL-delimited binding strings, not substrings of
    # EEex-prefixed or template names (CInfGame is not exposed as a Lua type).
    for name in classes:
        assert b'\0'+name.encode()+b'\0' in data,'missing binding type '+name
    assert b'\0CInfGame\0' not in data
    assert b'\0CBaldurChitin\0' not in data
    return dict(binding_sha256=hashlib.sha256(data).hexdigest().upper(),
        classes=classes,members=members,usertypes=usertypes,
        fields=offsets,evidence=evidence,type_evidence=type_evidence)

if __name__ == '__main__':
    result=binding_layout();out=root/'tests/.work/native'
    (out/'binding-offsets.json').write_text(json.dumps(result,indent=2)+'\n')
    (out/'binding-offsets.lua').write_text('return {\n'+''.join(
        f'    ["{name}"]=0x{value:X},\n' for name,value in result['fields'].items())+'}\n')
    (out/'binding-members.lua').write_text('return {\n'+''.join(
        f'    ["{name}"]=0x{value:X},\n' for name,value in result['members'].items())+'}\n')
    (out/'binding-usertypes.lua').write_text('return {\n'+''.join(
        f'    ["{name}"]="{value}",\n' for name,value in result['usertypes'].items())+'}\n')
    print('Verified 16 offset and 6 usertype registrations; 12 worker fields:',
        {name:hex(value) for name,value in result['fields'].items()})
