-- Offline Lua checks against the actual disposable executable's site bytes.
local original_print=print
local source_path=MRIP_TEST_RUNTIME_PATH or "bg-redux-movement/runtime/profiles/bg2ee-2.6.6.0.lua"
local expected_revision=MRIP_TEST_REVISION or (MRIP_TEST_PROTOTYPE and (MRIP_TEST_PREFERENCE and 47 or 38) or 3)
local expected_hooks=MRIP_TEST_PROTOTYPE and (MRIP_TEST_PREFERENCE and 35 or 24) or 6
local image=assert(io.open(MRIP_TEST_GAME_PATH.."/Baldur.exe","rb")):read("*a")
local function image_u32(offset)
    local a,b,c,d=image:byte(offset+1,offset+4)
    return a+b*256+c*65536+d*16777216
end
local pe=image_u32(0x3C)
local sections={}
-- PE offsets above are zero-based; Lua string indexes are one-based.
local table_start=pe+24+image:byte(pe+22)*256+image:byte(pe+21)
local section_count=image:byte(pe+8)*256+image:byte(pe+7)
for i=0,section_count-1 do
    local p=table_start+i*40
    sections[#sections+1]={rva=image_u32(p+12),size=image_u32(p+16),raw=image_u32(p+20)}
end
local exe_base=0x140000000
local function executable_byte(address)
    local rva=address-exe_base
    for _,s in ipairs(sections) do
        if rva>=s.rva and rva<s.rva+s.size then return image:byte(s.raw+rva-s.rva+1) end
    end
    error("unmapped executable byte "..address)
end
local output,feedback,hooks,memory={}, {}, {}, {}
local buffer=0x200000000
local clock_ms=10000
local modifiers=false
local key_listener,action_listener
local release_initialized,release_values,release_writes
if MRIP_TEST_RELEASE then
    release_values=MRIP_TEST_RELEASE_INITIAL_VALUES or {};release_writes={}
    EEex={GetINIString=function(path,section,key,default)
        assert(path=='.\\bg-redux-movement.ini' and section=='Movement')
        return release_values[key] or default
    end,SetINIString=function(path,section,key,value)
        release_values[key]=value;release_writes[#release_writes+1]={key,value}
    end}
    EEex_GameState_AddInitializedListener=function(callback) release_initialized=callback end
end
local corrupt_site=nil
local sprites={
    {m_id=42,m_pos={x=120,y=240},m_typeAI={m_EnemyAlly=2},m_curAction={m_actionID=23,m_dest={x=420,y=240}}},
    {m_id=43,m_pos={x=220,y=240},m_typeAI={m_EnemyAlly=2},m_curAction={m_actionID=0,m_dest={x=0,y=0}}},
}
for i,sprite in ipairs(sprites) do
    local slot=i-1
    sprite.getPortraitIndex=function() return slot end
    sprite.getName=function() return slot==0 and "Mover" or "Imoen" end
    sprite.getPersonalSpace=function() return 3 end
    sprite.getState=function() return 0 end
    sprite.m_baseStats={m_generalState=0}
    sprite.ptr=0x500000+i*0x10000
    sprite.m_pArea={ptr=0x600000}
end
EEex_UDToPtr=function(ud) return ud.ptr end
print=function(line) output[#output+1]=line end
os=nil
Infinity_GetClockTicks=function() return clock_ms end
worldScreen={CheckIfPaused=function() return false end}
e={GetActiveEngine=function() return worldScreen end}
Infinity_DisplayString=function(line) feedback[#feedback+1]=line end
Infinity_TextEditHasFocus=function() return 0 end
EEex_Key_GetFromName=function(name) return name end
EEex_Key_IsDown=function() return modifiers end
EEex_Key_AddPressedListener=function(callback) key_listener=callback end
EEex_Action_AddSpriteStartedActionListener=function(callback) action_listener=callback end
EEex_Sprite_GetInPortrait=function(slot) return sprites[slot+1] end
EEex_Label=function(name)
    local labels={["CMessageHandler::AddMessage"]=0x204C60,["CGameSprite::ClearBumpPath"]=0x34EB90,["CGameSprite::JumpToPoint"]=0x3A02D0,
        ["CGameObjectArray::GetShare"]=0x276490,["g_pBaldurChitin"]=0x6650A0}
    return exe_base+assert(labels[name],name)
end
-- Generated independently from the actual installed LuaBindings offset
-- registrations; do not repeat the prototype's assumed offsets here.
local worker_offsets=dofile("tests/.work/native/binding-offsets.lua")
-- Exercise the installed resolver itself against independently extracted
-- member metadata and the actual public type names, including inheritance.
local binding_members=dofile("tests/.work/native/binding-members.lua")
local metadata={}
for path,offset in pairs(binding_members) do
    local class,member=path:match("^([^.]+)%.(.+)$")
    _G[class]=_G[class] or {}
    local offsets=rawget(_G[class],".offsetof") or {}
    rawset(_G[class],".offsetof",offsets)
    offsets[member]=offset
    _G[class]["usertype_"..member]="scalar"
    metadata[_G[class]]={{mt=_G[class],offset=0}}
end
local binding_usertypes=dofile("tests/.work/native/binding-usertypes.lua")
for path,declared in pairs(binding_usertypes) do
    local class,member=path:match("^([^.]+)%.(.+)$")
    assert(_G[class] and _G[declared],path)
    _G[class]["usertype_"..member]=declared
end
metadata[CGameSprite][2]={mt=CGameAIBase,offset=0}
metadata[CGameSprite][3]={mt=CGameObject,offset=0}
metadata[CGameAIBase][2]={mt=CGameObject,offset=0}
-- Public binding tables expose inherited usertype fields through lookup.
setmetatable(CGameAIBase,{__index=CGameObject})
setmetatable(CGameSprite,{__index=CGameAIBase})
EEex_GetUTBaseclassMetadata=function(binding) return metadata[binding] end
EEex_Split=function(value)
    local parts={};for part in value:gmatch("[^.]+") do parts[#parts+1]=part end;return parts
end
EEex_Error=error
local assembly_file=assert(io.open(MRIP_TEST_GAME_PATH.."/EEex_scripts/EEex_Assembly.lua","rb"))
local assembly_source=assembly_file:read("*a");assembly_file:close()
local resolver=assert(assembly_source:match("(function EEex_Assembly_Private_FindOffsetOf.-)function EEex_PreprocessAssemblyStr"))
assert(loadstring(resolver))()
for path,offset in pairs(worker_offsets) do assert(EEex_OffsetOf(path)==offset,path) end
for _,path in ipairs({"CInfGame.m_charactersPortrait","CBaldurChitin.m_pObjectGame"}) do
    local ok,err=pcall(EEex_OffsetOf,path)
    assert(not ok and tostring(err):find('Invalid usertype encountered in #OFFSET_OF',1,true),'unexposed native name must fail: '..path)
end
EEex_ReadU8=function(address)
    if corrupt_site and address==exe_base+corrupt_site then return 0 end
    return executable_byte(address)
end
EEex_Read32=function(address)
    local value=memory[address]
    if value==nil then
        value=executable_byte(address)+executable_byte(address+1)*256+executable_byte(address+2)*65536+executable_byte(address+3)*16777216
    end
    return value>=0x80000000 and value-0x100000000 or value
end
EEex_Write32=function(address,value) memory[address]=value end
EEex_ReadPtr=function(address)
    return (memory[address] or 0)+(memory[address+4] or 0)*0x100000000
end
EEex_Malloc=function(size) assert(size==64+4096*128 or MRIP_TEST_PROTOTYPE and (size==48 or size==24 or MRIP_TEST_PREFERENCE and size==64)); return size==64 and buffer+0x300000 or size==24 and buffer+0x200000 or size==48 and buffer+0x100000 or buffer end
EEex_Memcpy=function() end
EEex_Memset=function() end
EEex_JITNear=function() return exe_base+0x800000 end
EEex_JITAt=function(address,body) hooks[#hooks+1]={address=address,body=body} end
EEex_WritePtr=function(p,v) memory[p]=v%0x100000000;memory[p+4]=math.floor(v/0x100000000) end
EEex_DefineAssemblyLabel=function() end
EEex_JITNearAsLuaFunction=function(name) _G[name]=function() end end
EEex_HookBeforeCallWithLabels=function(address,labels,body) hooks[#hooks+1]={address=address,body=body} end
EEex_DisableCodeProtection=function() end
EEex_EnableCodeProtection=function() end
EEex_HookAfterCallWithLabels=function(address,labels,body) hooks[#hooks+1]={address=address,body=body} end
EEex_HookBeforeAndAfterCallWithLabels=function(address,labels,before,after) hooks[#hooks+1]={address=address,before=before,after=after} end
EEex_HookConditionalJumpWithLabels=function(address,restore,labels,fail,success)
    error("RIP-relative early-wait load must never be copied by a conditional hook")
end
EEex_HookBeforeRestoreWithLabels=function(address,delay,size,ret,labels,body)
    if address==exe_base+0x3461B2 then assert(delay==0 and size==7 and ret==7) end
    if address==exe_base+0x24DC1B or address==exe_base+0x24DC6B then assert(delay==0 and size==5 and ret==5) end
    hooks[#hooks+1]={address=address,body=body}
end
EEex_HookAfterRestoreWithLabels=function(address,delay,size,ret,labels,body)
    assert(delay==0 and size==ret)
    if address==exe_base+0x346D63 then
        assert(size==10 and address+size==exe_base+0x346D6D)
        local names={}
        for _,label in ipairs(labels) do names[label[1]]=label[2] end
        assert(names.manual_return and names.MRIP_yield_return==exe_base+0x346D6D and names.MRIP_yield_continue==exe_base+0x346DCA)
        MRIP_TestYieldHook=body
    elseif address==exe_base+0x24DC6B then
        assert(size==5)
        local names={}
        for _,label in ipairs(labels) do names[label[1]]=label[2] end
        assert(names.manual_return and names.MRIP_worker_remove==exe_base+0x24DC20 and names.MRIP_worker_keep==exe_base+0x24DC70)
    elseif address==exe_base+0x388E32 or address==exe_base+0x389744 then
        assert(size==7)
    else
        assert(address==exe_base+0x24C620 and size==6)
    end
    hooks[#hooks+1]={address=address,body=body}
end
EEex_FlattenTable=function(value)
    local result={}
    local function visit(v) if type(v)=="table" then for _,item in ipairs(v) do visit(item) end else result[#result+1]=v end end
    visit(value)
    return result
end
EEex_HookIntegrityWatchdogRegister={RAX=1,RDX=2,RCX=3,R8=4}
EEex_LuaCallReturnType={Boolean=0,Number=1}
EEex_HookRemoveCallWithLabels=function(address,labels,body)
    assert(address==exe_base+0x388F29 or address==exe_base+0x3898F9)
    hooks[#hooks+1]={address=address,body=body}
end
EEex_GenLuaCall=function(name,meta)
    if name=='MRIP_PreferenceDelivered' then
        assert(MRIP_TEST_PREFERENCE and #meta.args==1)
        return {'mov rcx,rbx #ENDL call mock_delivered #ENDL'}
    end
    if name=='MRIP_PreferencePath' then
        assert(MRIP_TEST_PREFERENCE and meta.returnType==1 and #meta.args==6)
        local args={}
        for i,producer in ipairs(meta.args) do
            local fragment,ut=producer((i-1)*8)
            assert(ut==(i==1 and 'CGameSprite' or nil))
            args[#args+1]=fragment[1]:gsub('#%$%(1%)',tostring(fragment[2][1]))
        end
        args[#args+1]='mov rcx,[rsp] #ENDL mov rdx,[rsp+8] #ENDL mov r8,[rsp+16] #ENDL mov r9,[rsp+24] #ENDL call mock_preference #ENDL'
        return args
    end
    if name=='MRIP_PreferenceCommit' then
        assert(MRIP_TEST_PREFERENCE and #meta.args==3 and meta.labelSuffix=='_commit')
        local args={}
        for i,producer in ipairs(meta.args) do
            local fragment,ut=producer((i-1)*8)
            assert(ut==(i==1 and 'CGameSprite' or nil))
            args[#args+1]=fragment[1]:gsub('#%$%(1%)',tostring(fragment[2][1]))
        end
        args[#args+1]='mov rcx,[rsp] #ENDL mov rdx,[rsp+8] #ENDL mov r8,[rsp+16] #ENDL call mock_commit #ENDL'
        return args
    end
    if name=='MRIP_SearchSnapshot' then
        assert(meta.returnType==0 and #meta.args==2)
        local args={}
        for i,producer in ipairs(meta.args) do
            local fragment,ut=producer((i-1)*8)
            assert(ut==nil,'snapshot arguments must be scalar addresses')
            args[#args+1]=fragment[1]:gsub('#%$%(1%)',tostring(fragment[2][1]))
        end
        args[#args+1]='mov rcx,[rsp] #ENDL mov rdx,[rsp+8] #ENDL call mock_snapshot #ENDL'
        return args
    end
    if name=='MRIP_AttackPosition' or name=='MRIP_AttackContinue' then
        assert(meta.returnType==0 and #meta.args==(name=='MRIP_AttackPosition' and 4 or 3))
        local args={}
        for i,producer in ipairs(meta.args) do
            local fragment,ut=producer(64+(i-1)*8)
            assert(ut==({"CGameSprite","CGameObject",false,"CPoint"})[i] or (i==3 and ut==nil))
            local text=fragment[1]:gsub('#%$%(1%)',tostring(fragment[2][1]))
            args[#args+1]=text
        end
        args[#args+1]='mov rcx,[rsp+64] #ENDL mov rdx,[rsp+72] #ENDL mov r8,[rsp+80] #ENDL'
        if name=='MRIP_AttackPosition' then args[#args+1]='mov r9,[rsp+88] #ENDL' end
        args[#args+1]='call '..(name=='MRIP_AttackPosition' and 'mock_attack' or 'mock_attack_continue')..' #ENDL'
        return args
    end
    if name=="MRIP_PassCost" or name=="MRIP_RouteCost" or name=="MRIP_YieldCost" then
        assert(MRIP_TEST_PROTOTYPE and meta.returnType==0 and #meta.args==2)
        local _,first_type=meta.args[1](80)
        local _,second_type=meta.args[2](88)
        assert(first_type=="CGameSprite" and second_type=="CPoint")
        return {"call "..(name=="MRIP_PassCost" and "mock_pass" or name=="MRIP_YieldCost" and "mock_yield" or "mock_route").." #ENDL"}
    end
    assert(name=="MRIP_Tick"); return {"call mock_lua #ENDL"}
end

dofile(source_path)
assert(MRIP_TraceEnabled and MRIP_BaselineRevision==expected_revision,table.concat(output,"\n"))
assert(table.concat(output,"\n"):find("LOADED revision="..expected_revision.." trace_enabled=true",1,true),'logged revision must match loaded revision')
assert(#hooks==expected_hooks)
if MRIP_TEST_RELEASE then
    local initially_preferred=release_values.RoutePreference=='1'
    assert(release_initialized and memory[buffer+56]==0 and memory[buffer]==0)
    local startup_feedback=#feedback
    release_initialized()
    assert(#feedback==startup_feedback,'automatic startup must not print prototype instructions to game chat')
    assert(memory[buffer+56]==1 and memory[buffer]==0,'automatic startup must not record')
    assert(MRIP_AttackSpacingEnabled and MRIP_SettleEnabled and MRIP_PreferenceEnabled==initially_preferred)
    if initially_preferred then
        assert(memory[buffer+0x300000]==1,'configured startup must arm optional native preference')
        MRIP_TogglePreference();assert(release_values.RoutePreference=='0')
    end
    assert(table.concat(output,'\n'):find('RELEASE_READY',1,true))
    MRIP_TogglePreference();assert(release_values.RoutePreference=='1')
    MRIP_TogglePreference();assert(release_values.RoutePreference=='0')
    MRIP_ToggleAttackSpacing();assert(release_values.AttackSpacing=='0')
    MRIP_ToggleAttackSpacing();assert(release_values.AttackSpacing=='1')
    MRIP_ToggleSettle();assert(release_values.GentleSettle=='0')
    MRIP_ToggleSettle();assert(release_values.GentleSettle=='1')
    MRIP_TogglePass();assert(release_values.Movement=='0' and memory[buffer+56]==0)
    assert(#release_writes==8+(initially_preferred and 1 or 0),'startup and independent switch writes expected')
end
if MRIP_TEST_PROTOTYPE then
    assert(MRIP_TransitEnabled==nil and MRIP_TransitNativeBody==nil,'shelved lane code remains active')
    for _,hook in ipairs(hooks) do
        assert((MRIP_TEST_PREFERENCE or hook.address~=exe_base+0x375899) and hook.address~=exe_base+0x37595E,'shelved native hook installed')
    end
end
assert(table.concat(output,"\n"):find("HOOKS_READY",1,true),'native hooks ready after profile selection')
key_listener("F7")
assert(memory[buffer]==0,"capture requires modifiers")
if MRIP_TEST_PREFERENCE then
    key_listener('F3');assert(not MRIP_PreferenceEnabled,'F3 requires modifiers')
end
if MRIP_TEST_PROTOTYPE then
    key_listener('F5')
    assert(MRIP_AttackSpacingEnabled,'spacing requires modifiers')
end
modifiers=true
if MRIP_TEST_PREFERENCE then
    key_listener('F3');assert(MRIP_PreferenceEnabled and memory[buffer+0x300000]==1)
    key_listener('F3');assert(not MRIP_PreferenceEnabled and memory[buffer+0x300000]==0)
end
key_listener("F7")
assert(memory[buffer]==1 and memory[buffer+32]==42 and memory[buffer+36]==43)
if MRIP_TEST_PROTOTYPE then
    sprites[1].getState=function() return 0x8000 end
    sprites[1].m_baseStats.m_generalState=0x8000
    MRIP_Snapshot()
    assert(table.concat(output,"\n"):find("state=0x8000 base_state=0x8000",1,true))
    sprites[1].getState=function() return 0 end
    sprites[1].m_baseStats.m_generalState=0
end
MRIP_Tick()
local count=#output
MRIP_Tick()
assert(#output==count,"unchanged positions must not spam")
clock_ms=10060
sprites[2].m_pos.x=188
MRIP_Tick()
assert(output[#output]:find("pos=188,240",1,true))
-- Inject one committed native event to exercise the UI consumer.
local p=buffer+64
for offset=0,124,4 do memory[p+offset]=-1 end
memory[p]=5
memory[p+4]=1
memory[p+8]=10060
memory[p+12]=0x34F46D
memory[p+16]=42
memory[p+20]=43
memory[p+24]=120
memory[p+28]=240
memory[p+32]=220
memory[p+36]=240
memory[p+48]=188
memory[p+52]=216
memory[buffer+8]=1
clock_ms=10120
MRIP_Tick()
assert(memory[buffer+12]==1)
local all=table.concat(output,"\n")
assert(all:find("kind=JUMP_ENTER_A site=0x34F46D mover=42 other=43",1,true))
assert(all:find("target=188,216",1,true))
if MRIP_TEST_PROTOTYPE then
    local p2=p+128
    for offset=0,124,4 do memory[p2+offset]=-1 end
    memory[p2]=11
    memory[p2+4]=1
    memory[p2+8]=10120
    memory[p2+12]=0x3461B2
    memory[p2+16]=42
    memory[p2+44]=0x703
    memory[p2+104],memory[p2+108]=0x33445566,0x1122
    memory[p2+112],memory[p2+116]=0x11223344,0x2233
    memory[p2+120],memory[p2+124]=7,2
    memory[p2+48],memory[p2+52]=0,1
    memory[p2+56],memory[p2+60]=1,0x100
    memory[buffer+8]=2
    MRIP_Tick()
    assert(memory[buffer+12]==2)
    local diagnostic=table.concat(output,"\n")
    assert(diagnostic:find("kind=WALK_READY site=0x3461B2",1,true))
    assert(diagnostic:find("path_ptr=112233445566 request_ptr=223311223344 request_status=3 request_delay=7 path_length=7 path_cursor=2 result_return=0 result_count=1",1,true))
    assert(diagnostic:find("request_type=1 request_selected_count=0 request_aux_count=1 request_point_count=0",1,true))
    local p3=p2+128
    for offset=0,124,4 do memory[p3+offset]=0 end
    memory[p3],memory[p3+4],memory[p3+12]=12,1,0x24DC6B
    memory[p3+16],memory[p3+20],memory[p3+40]=43,42,0
    memory[p3+48],memory[p3+52],memory[p3+56],memory[p3+60]=83,6,2,3
    memory[p3+112],memory[p3+116]=0x11223344,0x2233
    memory[p3+124]=0x302
    memory[buffer+8]=3
    MRIP_Tick()
    assert(memory[buffer+12]==3)
    assert(table.concat(output,"\n"):find("worker_actor=43 worker_job_mover=42 worker_selected_remove=0 worker_request_ptr=223311223344",1,true))
    assert(table.concat(output,"\n"):find("worker_actor_action=83 worker_actor_sequence=6 worker_selected_index=2 worker_selected_count=3",1,true))
    assert(table.concat(output,"\n"):find("worker_aux_count=2 worker_aux2_count=3",1,true))
    local p4=p3+128
    for offset=0,124,4 do memory[p4+offset]=memory[p3+offset] end
    memory[p4],memory[p4+40]=13,1
    memory[buffer+8]=4
    MRIP_Tick()
    assert(memory[buffer+12]==4)
    assert(table.concat(output,"\n"):find("kind=WORKER_OVERRIDE",1,true))
end
action_listener(sprites[1],sprites[1].m_curAction)
assert(output[#output]:find("ACTION_START",1,true))
clock_ms=10300
key_listener("F9")
assert(memory[buffer]==0)
count=#output
action_listener(sprites[1],sprites[1].m_curAction)
MRIP_Tick()
assert(#output==count)
MRIP_Start("clear")
clock_ms=30300
MRIP_Tick()
assert(memory[buffer]==0 and table.concat(output,'\n'):find("END reason=timeout",1,true))
clock_ms=31000
MRIP_Start("clock reset")
clock_ms=30000
MRIP_Tick()
assert(memory[buffer]==0 and table.concat(output,'\n'):find("END reason=clock-reset",1,true))
if MRIP_TEST_PROTOTYPE then
    assert(memory[buffer+56]==0,"prototype defaults OFF")
    clock_ms=32000
    key_listener("F6")
    assert(memory[buffer+56]==1 and memory[buffer]==0,"F6 enables movement without recording")
    key_listener("F7")
    assert(memory[buffer+56]==1,"armed capture enables the experiment")
    clock_ms=52000
    MRIP_Tick()
    assert(memory[buffer+56]==1 and memory[buffer]==0,"timeout stops recording only")
    clock_ms=53000
    key_listener("F7")
    assert(memory[buffer+56]==1)
    key_listener("F6")
    assert(memory[buffer]==0 and memory[buffer+56]==0,"mode change ends capture")
    key_listener("F7")
    assert(memory[buffer+56]==0,"OFF capture preserves normal behavior")
    key_listener("F9")
    key_listener('F6')
    key_listener('F7')
    assert(memory[buffer+56]==1 and MRIP_AttackSpacingEnabled)
    key_listener('F5')
    assert(memory[buffer]==0 and memory[buffer+56]==1 and not MRIP_AttackSpacingEnabled,'spacing mode change keeps continuous noclip')
    key_listener('F7')
    assert(memory[buffer+56]==1 and not MRIP_AttackSpacingEnabled,'spacing OFF must preserve armed noclip')
    assert(table.concat(output,'\n'):find('ATTACK_RUN enabled=false',1,true))
    key_listener('F9')
    key_listener('F5')
    key_listener('F7')
    assert(memory[buffer+56]==1 and MRIP_AttackSpacingEnabled,'spacing ON restores only its own mode')
    key_listener('F9')
    assert(memory[buffer]==0 and memory[buffer+56]==1,'F9 keeps movement ON')
    key_listener('F4')
    assert(not MRIP_SettleEnabled and memory[buffer+56]==1,'F4 changed traversal')
    key_listener('F4')
    assert(MRIP_SettleEnabled and memory[buffer+56]==1,'F4 did not restore settlement')
    key_listener('F6')
    assert(memory[buffer+56]==0,'F6 switches movement OFF')
end
count=#hooks
dofile(source_path)
assert(#hooks==count,"duplicate load must not repatch")
assert(not table.concat(output,"\n"):find("ERROR",1,true))

for i,body in ipairs(MRIP_TraceNativeBodies) do
    local file=assert(io.open(string.format("tests/.work/native/body-%02d.txt",i),"wb"))
    file:write(table.concat(body,"\n")); file:close()
end
local tick_body
for _,hook in ipairs(hooks) do if hook.address==exe_base+0x2FC580 then tick_body=table.concat(hook.body,"\n") end end
assert(tick_body)
local file=assert(io.open("tests/.work/native/tick.txt","wb"))
file:write(tick_body);file:close()
-- Mismatched builds install zero hooks and refuse capture.
if MRIP_TEST_PROTOTYPE then
    -- Report every remaining layout mismatch in one pre-hook refusal.
    local id_offsets=rawget(CGameObject,".offsetof")
    local portrait_offsets=rawget(EEex_CInfGame,".offsetof")
    local id_original,portrait_original=id_offsets.m_id,portrait_offsets.m_charactersPortrait
    id_offsets.m_id=id_original+1
    portrait_offsets.m_charactersPortrait=portrait_original+1
    hooks={};MRIP_BaselineRevision=nil;MRIP_TraceEnabled=nil;corrupt_site=nil
    local first_new=#output+1
    dofile(source_path)
    assert(not MRIP_TraceEnabled and #hooks==0)
    local refusal=table.concat(output,"\n",first_new)
    assert(refusal:find('CGameSprite.m_id expected=',1,true) and refusal:find('EEex_CInfGame.m_charactersPortrait expected=',1,true),'all mismatches must be reported together')
    id_offsets.m_id=id_original
    portrait_offsets.m_charactersPortrait=portrait_original
end
for _,site in ipairs(MRIP_TEST_PROTOTYPE and {0x388F1B,0x3898F3,0x388DA8,0x1308E0,0x3A5CF0,0x388E32,0x389744,0x3896C7,0x389808,0x34F074,0x34EF63,0x276490,0x161710,0x276300,0x161700,0x161F10,0x24DB79,0x24DC7A,0x5986DF,0x24DC1B,0x24DC6B,0x24DC20,0x24DC70,0x3461B2,0x346E0B,0x346D63,0x346D69,0x346D6D,0x346D6F,0x3A6011,0x24C620,0x215542,0x3462C0,0x346457,0x346FEA,0x347022,0x3A699C} or {0x346E0B}) do
    MRIP_BaselineRevision=nil
    MRIP_TraceEnabled=nil
    hooks={}
    corrupt_site=site
    dofile(source_path)
    assert(not MRIP_TraceEnabled and #hooks==0)
    assert(MRIP_Start()==false and memory[buffer]==0)
end
if MRIP_TEST_PROTOTYPE then
    for field,offset in pairs(worker_offsets) do
        hooks={};MRIP_BaselineRevision=nil;MRIP_TraceEnabled=nil;corrupt_site=nil
        local parts=EEex_Split(field)
        local binding=_G[parts[1]]
        for i=2,#parts-1 do binding=_G[binding["usertype_"..parts[i]]] end
        local member=parts[#parts]
        local leaf
        for _,base in ipairs(metadata[binding]) do
            local offsets=rawget(base.mt,".offsetof")
            if offsets and offsets[member]~=nil then leaf=offsets;break end
        end
        assert(leaf,field)
        local original=leaf[member]
        leaf[member]=original+1
        dofile(source_path)
        assert(not MRIP_TraceEnabled and #hooks==0,'bad field layout must install no hooks: '..field)
        leaf[member]=original
    end
    if MRIP_TEST_PREFERENCE then
        for _,site in ipairs({0x2250A0,0x2251D0,0x225650,0x225D60,0x225220,0x225F00,0x374690,0x375894,0x375CEE}) do
            hooks={};MRIP_BaselineRevision=nil;MRIP_TraceEnabled=nil;corrupt_site=site
            dofile(source_path)
            assert(MRIP_TraceEnabled and #hooks==24 and not MRIP_PreferenceEnabled,'optional mismatch must preserve base movement')
            key_listener('F3');assert(not MRIP_PreferenceEnabled,'unavailable optional feature must refuse enable')
        end
    end
    hooks={};MRIP_BaselineRevision=nil;MRIP_TraceEnabled=nil;corrupt_site=nil
    dofile(source_path)
    assert(MRIP_TraceEnabled and #hooks==expected_hooks)
end
-- Expand the tick's stack macros with the installed EEex macro handlers.
EEex_Once=function(_,callback) callback() end
EEex_Error=error
EEex_RoundUp=function(value,multiple) return math.ceil(value/multiple)*multiple end
EEex_DistanceToMultiple=function(value,multiple) return (multiple-value%multiple)%multiple end
dofile(MRIP_TEST_GAME_PATH.."/EEex/copy/EEex_scripts/EEex_Assembly_x86-64.lua")
local function expand(body,stack_mod,output_path)
local state={}
EEex_Assembly_Private_InitState(state)
state.curStackTop=stack_mod
local pieces,pos={},1
while true do
    local first,last,name=body:find("#([%w_]+)",pos)
    if not first then pieces[#pieces+1]=body:sub(pos);break end
    pieces[#pieces+1]=body:sub(pos,first-1)
    local args={}
    if body:sub(last+1,last+1)=="(" then
        local closing=assert(body:find(")",last+2,true))
        args[1]=body:sub(last+2,closing-1)
        last=closing
    end
    local replacement
    if name=="L" then
        replacement=({MRIP_route_context="MRIP_CONTEXT_POINTER",MRIP_yield_return="native_wait_branch",MRIP_yield_continue="native_continue",
            MRIP_worker_remove="native_worker_remove",MRIP_worker_keep="native_worker_keep",MRIP_bump_next="native_bump_next",
            MRIP_attack_context="MRIP_ATTACK_CONTEXT_POINTER",MRIP_move_point="native_move_point",MRIP_move_object="native_move_object",MRIP_attack_return="native_attack_return",
            MRIP_attack_stop="native_attack_stop",MRIP_attack_approach="native_attack_approach",
            ["CGameObjectArray::GetShare"]="native_get_share",g_pBaldurChitin="NATIVE_CHITIN_SLOT",
            MRIP_PlannerState='PREFERENCE_STATE_POINTER',MRIP_DirectReturnA='PREFERENCE_DIRECT_A',MRIP_DirectReturnB='PREFERENCE_DIRECT_B',
            MRIP_MessageReturn='PREFERENCE_MESSAGE_RETURN',MRIP_PathMalloc='pref_api_MRIP_PathMalloc',
            MRIP_PlannerFree='pref_api_MRIP_PlannerFree'})[args[1]] or (MRIP_PREF_LABELS and 'pref_api_'..args[1]:gsub('[^%w_]','_') or "MRIP_RING_POINTER")
    elseif name=="MANUAL_HOOK_EXIT" then
        -- Installed defaults disable the watchdog. Still run its real exit
        -- handler so an unbalanced stack frame refuses the offline build.
        EEex_PreprocessAssembly=function(t) assert(#t==0); return "" end
        replacement=EEex_Assembly_Private_MacroSwitch[name](state,args)
    elseif name=="ENDL" then replacement="\n"
    else replacement=assert(EEex_Assembly_Private_MacroSwitch[name],name)(state,args) or "" end
    pieces[#pieces+1]=replacement
    pos=last+1
end
assert(state.curStackTop==stack_mod and state.shadowSpaceStackTop==0,"hook stack macros must balance")
file=assert(io.open(output_path,"wb"))
local expanded=table.concat(pieces):gsub("#ENDL","\n")
file:write(expanded);file:close()
end
expand(tick_body,8,"tests/.work/native/tick-expanded.txt")
if MRIP_TEST_PROTOTYPE then
    if MRIP_TEST_PREFERENCE then
        expand(table.concat(MRIP_PreferenceNativeBody,'\n'),0,'tests/.work/native/preference-expanded.txt')
        expand(table.concat(MRIP_PreferenceAllocationBody,'\n'),0,'tests/.work/native/preference-allocation-expanded.txt')
        -- Match EEex's concatenation; inserting newlines hid revision39's failure.
        for i,body in ipairs(MRIP_PreferenceDepthBodies) do expand(table.concat(body),0,'tests/.work/native/preference-depth-'..i..'-expanded.txt') end
    end
    expand(table.concat(MRIP_SnapshotNativeBody,'\n'),0,'tests/.work/native/snapshot-expanded.txt')
    expand(table.concat(MRIP_PassNativeBody,"\n"),0,"tests/.work/native/pass-expanded.txt")
    expand(table.concat(MRIP_YieldNativeBody,"\n"),0,"tests/.work/native/yield-expanded.txt")
    expand(table.concat(MRIP_TestYieldHook,"\n"),0,"tests/.work/native/yield-hook-expanded.txt")
    for i,body in ipairs(MRIP_RouteNativeBodies) do
        expand(table.concat(body,"\n"),0,"tests/.work/native/route-"..i.."-expanded.txt")
    end
    for i,body in ipairs(MRIP_RequestNativeBodies) do
        expand(table.concat(body,"\n"),0,"tests/.work/native/request-"..i.."-expanded.txt")
    end
    expand(table.concat(MRIP_WorkerNativeBody,"\n"),0,"tests/.work/native/worker-expanded.txt")
    expand(table.concat(MRIP_BumpNativeBody,"\n"),0,"tests/.work/native/bump-expanded.txt")
    expand(table.concat(MRIP_AttackNativeBody,"\n"),0,"tests/.work/native/attack-expanded.txt")
    expand(table.concat(MRIP_AttackContinueBody,"\n"),0,"tests/.work/native/attack-continue-expanded.txt")
    expand(table.concat(MRIP_AttackReevaluateBody,"\n"),0,"tests/.work/native/attack-reevaluate-expanded.txt")
    expand(table.concat(MRIP_AttackReevaluateContinueBody,"\n"),0,"tests/.work/native/attack-reevaluate-continue-expanded.txt")
    expand(table.concat(MRIP_AttackCaptureBody,"\n"),0,"tests/.work/native/attack-capture-expanded.txt")
    expand(table.concat(MRIP_WorkerHookBody,"\n"),0,"tests/.work/native/worker-hook-expanded.txt")
    -- Exercise the installed wrapper, including its five restored bytes.
    -- Only allocation and writes are mocked; the watchdog's shipped setting
    -- is false. The wrapper's trailing #IF false block emits no return jump.
    EEex_HookIntegrityWatchdog_Load=false
    local labels={}
    EEex_RunWithAssemblyLabels=function(pairs,callback)
        local previous={}
        for _,entry in ipairs(pairs) do previous[entry[1]]=labels[entry[1]];labels[entry[1]]=entry[2] end
        local result=callback()
        for _,entry in ipairs(pairs) do labels[entry[1]]=previous[entry[1]] end
        return result
    end
    EEex_TryLabel=function(name) return labels[name] end
    local wrapper_output="worker-full-hook-expanded.txt"
    EEex_JITNear=function(t)
        local fragments={}
        for _,v in ipairs(t) do fragments[#fragments+1]=tostring(v) end
        local joined=table.concat(fragments," ")
        while true do
            local first,last,condition=joined:find("#IF%s+(%a+)%s*{")
            if not first then break end
            assert(condition=="true" or condition=="false")
            local level,close=1,last+1
            while level>0 do
                local c=joined:sub(close,close)
                assert(c~="","unterminated wrapper conditional")
                if c=="{" then level=level+1 elseif c=="}" then level=level-1 end
                close=close+1
            end
            joined=joined:sub(1,first-1)..(condition=="true" and joined:sub(last+1,close-2) or "")..joined:sub(close)
        end
        expand(joined,0,"tests/.work/native/"..wrapper_output)
        return exe_base+0x800000
    end
    EEex_JITAt=function(address,t) assert(address==exe_base+0x24DF96 or address==exe_base+0x24DC6B or address==exe_base+0x34EF63 or address==exe_base+0x388F29 or address==exe_base+0x388E32 or address==exe_base+0x388DA8 or address==exe_base+0x3898F9 or address==exe_base+0x389744) end
    wrapper_output='snapshot-full-hook-expanded.txt'
    EEex_HookBeforeRestoreWithLabels(exe_base+0x24DF96,0,7,7,{{'MRIP_ring',buffer}},MRIP_SnapshotNativeBody)
    wrapper_output='worker-full-hook-expanded.txt'
    EEex_HookAfterRestoreWithLabels(exe_base+0x24DC6B,0,5,5,{
        {"manual_return",true},{"MRIP_worker_remove",exe_base+0x24DC20},{"MRIP_worker_keep",exe_base+0x24DC70}
    },MRIP_WorkerHookBody)
    wrapper_output="bump-full-hook-expanded.txt"
    EEex_HookBeforeRestoreWithLabels(exe_base+0x34EF63,0,8,8,{
        {"MRIP_ring",buffer},{"MRIP_bump_next",exe_base+0x34F074}
    },EEex_FlattenTable({MRIP_TraceNativeBodies[4],MRIP_BumpNativeBody}))
    wrapper_output='attack-full-hook-expanded.txt'
    EEex_HookRemoveCallWithLabels(exe_base+0x388F29,{
        {'MRIP_ring',buffer},{'manual_return',true},{'MRIP_move_point',exe_base+0x3A5CF0},
        {'MRIP_move_object',exe_base+0x3A5630},{'MRIP_attack_return',exe_base+0x388F2E},
    },MRIP_AttackNativeBody)
    wrapper_output='attack-continue-full-hook-expanded.txt'
    EEex_HookAfterRestoreWithLabels(exe_base+0x388E32,0,7,7,{
        {'MRIP_ring',buffer},{'manual_return',true},{'MRIP_attack_stop',exe_base+0x388E39},{'MRIP_attack_approach',exe_base+0x388F1B},
    },MRIP_AttackContinueBody)
    wrapper_output='attack-capture-full-hook-expanded.txt'
    EEex_HookBeforeRestoreWithLabels(exe_base+0x388DA8,0,9,9,{
        {'MRIP_attack_context',buffer+0x200000},
    },MRIP_AttackCaptureBody)
    wrapper_output='attack-reevaluate-full-hook-expanded.txt'
    EEex_HookRemoveCallWithLabels(exe_base+0x3898F9,{
        {'MRIP_ring',buffer},{'manual_return',true},{'MRIP_move_point',exe_base+0x3A5CF0},
        {'MRIP_move_object',exe_base+0x3A5630},{'MRIP_attack_return',exe_base+0x3898FE},
    },MRIP_AttackReevaluateBody)
    wrapper_output='attack-reevaluate-continue-full-hook-expanded.txt'
    EEex_HookAfterRestoreWithLabels(exe_base+0x389744,0,7,7,{
        {'MRIP_ring',buffer},{'manual_return',true},{'MRIP_attack_stop',exe_base+0x38974B},{'MRIP_attack_approach',exe_base+0x389808},
    },MRIP_AttackReevaluateContinueBody)
    -- Parse the installed production bridge as well as the ABI fixture.
    EEex_FlattenTable=function(t)
        local out={}
        for _,v in ipairs(t) do
            if type(v)=='table' then for _,item in ipairs(v) do out[#out+1]=item end
            else out[#out+1]=v end
        end
        return out
    end
    EEex_WriteStringCache=function() return exe_base+0x900800 end
    local adapter=assert(io.open('tests/fixtures/bg_redux_attack_adapter.lua')):read('*a')
    local approach,continuation=assert(loadstring(adapter..'\nreturn attack_body,attack_continue_body'))()
    local function real_bridge(body,path)
        local t,i,pieces=body,1,{}
        while i<=#t do
            local v=t[i]
            if type(v)=='string' and v:find('#%$%(') then
                local args=assert(t[i+1])
                v=v:gsub('#%$%((%d+)%)',function(n) return tostring(args[tonumber(n)]) end)
                i=i+1
            end
            assert(type(v)~='table','unconsumed bridge parameters')
            pieces[#pieces+1]=tostring(v);i=i+1
        end
        local joined=table.concat(pieces,' ')
        while true do
            local first,last,condition=joined:find('#IF%s+(%a+)%s*{')
            if not first then break end
            local level,close=1,last+1
            while level>0 do
                local c=joined:sub(close,close);assert(c~='')
                if c=='{' then level=level+1 elseif c=='}' then level=level-1 end
                close=close+1
            end
            joined=joined:sub(1,first-1)..(condition=='true' and joined:sub(last+1,close-2) or '')..joined:sub(close)
        end
        expand(joined,0,path)
    end
    real_bridge(approach(),'tests/.work/native/attack-real-luacall-expanded.txt')
    real_bridge(continuation(),'tests/.work/native/attack-continue-real-luacall-expanded.txt')
    real_bridge(approach(true),'tests/.work/native/attack-reevaluate-real-luacall-expanded.txt')
    real_bridge(continuation(true),'tests/.work/native/attack-reevaluate-continue-real-luacall-expanded.txt')
    local snapshotSource=assert(io.open('tests/fixtures/bg_redux_snapshot_native.lua')):read('*a')
    local snapshotFactory=assert(loadstring(snapshotSource..'\nreturn snapshot_body'))()
    real_bridge(snapshotFactory(),'tests/.work/native/snapshot-real-luacall-expanded.txt')
    if MRIP_TEST_PREFERENCE then
        local source=assert(io.open('tests/fixtures/bg_redux_preference_native.lua')):read('*a')
        local factory=assert(loadstring(source..'\nreturn preference_path_body'))()
        MRIP_PREF_LABELS=true
        real_bridge(factory(),'tests/.work/native/preference-real-luacall-expanded.txt')
        MRIP_PREF_LABELS=nil
    end
end
print=original_print
print("MRIP revision "..expected_revision.." Lua checks passed: actual site bytes, hook setup, keys, automatic samples, ring drain, timeout, clock reset, duplicate guard, mismatch refusal")
