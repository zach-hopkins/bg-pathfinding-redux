local source=assert(io.open('bg-redux-movement/runtime/profiles/bg2ee-2.6.6.0.lua')):read('*a')
local function embedded(name,finish,bindings)
    local start=assert(source:find('local '..name,1,true))
    local stop=assert(source:find(finish,start,true))
    return assert(loadstring((bindings or '')..source:sub(start,stop-1)..'\nreturn '..name:match('^[%w_]+')))()
end
snapshot_enemy_fixture=embedded('enemy_policy=','local overlap_escape')
snapshot_escape_fixture=embedded('overlap_escape=','local pass_policy','local enemy_policy=snapshot_enemy_fixture\n')
local P=embedded('snapshot_policy=','-- SearchThreadMain','local enemy_policy=snapshot_enemy_fixture\nlocal overlap_escape=snapshot_escape_fixture\n')
local occupancy=embedded('attack_policy=','local attack_reservations','local enemy_policy=snapshot_enemy_fixture\n')
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local function actor(id,category,ea)
    return {id=id,x=168,y=126,personal=3,category=category or 0,ea=ea or 2,painted=1,removed=0}
end
local function plan(actors,live,private)
    return P.plan({width=20,height=20,actors=actors,
        read_live=function() return live end,read_snapshot=function() return private end},occupancy)
end
for category=0,1 do
    local weight=category==0 and 16 or 2
    for count=1,7 do
        local actors={};for id=1,count do actors[id]=actor(id,category) end
        local p=plan(actors,count*weight,count*weight)
        check(p and #p==9,'overlapped friendly mask missing')
        for _,patch in ipairs(p) do check(patch.after==0,'friendly counter not cleared') end
        check(#plan(actors,count*weight,0)==0,'already removed selected actors changed')
        check(#plan(actors,count*weight,weight)==9,'partial native removal was subtracted twice')
        check(#plan(actors,count*weight+128,count*weight+128)==0,'closed door cleared')
        check(#plan(actors,count*weight+1,count*weight+1)==0,'static obstruction cleared')
    end
    for enemy_category=0,1 do
        local enemy=actor(2,enemy_category,255)
        local enemy_weight=enemy_category==0 and 16 or 2
        check(#plan({actor(1,category),enemy},weight+enemy_weight,weight+enemy_weight)==0,'mixed hostile cell cleared')
        enemy.painted=0;enemy.removed=1
        check(#plan({actor(1,category),enemy},weight,weight)==0,'unpainted logical enemy ignored')
    end
    for _,count in ipairs({8,9,15}) do
        local actors={};for id=1,count do actors[id]=actor(id,category) end
        check(#plan(actors,(count%8)*weight,(count%8)*weight)==0,'wrapped counter cleared')
    end
    check(#plan({actor(1,category)},2*weight,2*weight)==0,'unaccounted paint cleared')
    check(#plan({actor(1,category)},weight,2*weight)==0,'private counter exceeds live')
end
local a=actor(1)
check(not plan({a,a},32,32),'duplicate actor accepted')
a.painted=1;a.removed=1;check(not plan({a},16,16),'unknown paint phase accepted')
a=actor(1);a.x=-1;check(not plan({a},16,16),'out-of-area actor accepted')
local many={};for i=1,257 do many[i]=actor(i) end
check(not plan(many,16,16),'actor budget ignored')
a=actor(1);a.personal=255;a.x=160*16;a.y=160*12
local p,reason=P.plan({width=320,height=320,actors={a}},occupancy)
check(not p and reason=='cell-budget','large footprint work unbounded')

-- Actual adapter and shared actor_record, under owned request/map fixtures.
local adapter_start=assert(source:find('local function snapshot_select',1,true))
local adapter=source:sub(adapter_start,assert(source:find('local function snapshot_body',adapter_start,true))-1)
local shared=source
shared=assert(shared:match('(local function actor_record.-)local function pass_decision'))
local function fixture()
    local mem,logs,writes={}, {}, {}
    local request,private,live,ap,mp=0x180800000,0x900000,0xA00000,0x200000,0x300000
    local area={ptr=ap};local sprites={}
    local function sprite(id,ptr,x,category)
        local s={m_id=id,ptr=ptr,m_pArea=area,m_pos={x=x,y=126},
            m_typeAI={m_EnemyAlly=2},m_baseStats={m_generalState=0},m_curAction={m_actionID=0},personal=3}
        s.getState=function() return 0 end;s.getPersonalSpace=function() return s.personal end
        mem[ptr+0x5250]=1;mem[ptr+0x5254]=0;mem[ptr+0x492C]=category or 0
        sprites[#sprites+1]=s;return s
    end
    local mover=sprite(41,mp,120);local ally=sprite(42,mp+0x10000,168)
    mem[request]=1;mem[request+4]=0;mem[request+0x38]=41;mem[request+0x18]=ap+0xA60
    mem[mp+0x47F0]=request;mem[ap+0xA60+0x120]=live;mem[ap+0xA60+0x128]=private
    mem[ap+0xA60+0x138]=20;mem[ap+0xA60+0x13C]=20;mem[0x140665098]=0xB00000
    for key=0,399 do
        local x,y=key%20,math.floor(key/20);local raw=0
        for _,s in ipairs(sprites) do
            if occupancy.footprint({personal=s.personal,x=s.m_pos.x,y=s.m_pos.y},x,y) then raw=raw+16 end
        end
        mem[live+key]=raw;mem[private+key]=raw
    end
    EEex_UDToPtr=function(s) return s.ptr end
    EEex_Read32=function(p) return mem[p] or 0 end;EEex_ReadPtr=EEex_Read32;EEex_ReadU8=EEex_Read32
    EEex_Write8=function(p,v)
        check(p>=private and p<private+400,'adapter wrote outside private bitmap')
        mem[p]=v;writes[#writes+1]={p,v}
    end
    EEex_GameObject_Get=function(id) for _,s in ipairs(sprites) do if s.m_id==id then return s end end end
    EEex_GameObject_IsSprite=function() return true end;EEex_CastUD=function(s) return s end
    EEex_Sprite_GetInPortrait=function(slot) return sprites[slot+1] end
    CAIObjectType={ANYONE={}}
    area.forAllOfTypeInRange=function(_,x,y,kind,r,callback,los,nonsprites)
        check(kind==CAIObjectType.ANYONE and r==32767 and los==0 and nonsprites==0,'enumeration filters changed')
        for _,s in ipairs(sprites) do callback(s) end
    end
    snapshot_test={policy=P,occupancy=occupancy,log=function(s) logs[#logs+1]=s end,on=true}
    assert(loadstring('local enemy_policy=snapshot_enemy_fixture\nlocal function clock() return 1000 end\nlocal base=0x140000000\nlocal active=true\nlocal log=snapshot_test.log\n'
        ..'local snapshot_policy,attack_policy=snapshot_test.policy,snapshot_test.occupancy\n'
        ..'local function movement_ready() return snapshot_test.on and 1000 or nil end\n'..shared..adapter))()
    return {mem=mem,logs=logs,writes=writes,mover=mover,ally=ally,sprites=sprites,area=area,
        request=request,private=private,live=live,ap=ap,mp=mp}
end
local f=fixture();local before={};for k,v in pairs(f.mem) do before[k]=v end
check(MRIP_SearchSnapshot(f.request,f.private),'unselected ally was not filtered')
check(#f.writes==18,'friendly mask differs from two native footprints')
for k,v in pairs(before) do
    if k<f.private or k>=f.private+400 then check(f.mem[k]==v,'live bitmap/actor/request changed') end
end
check(not MRIP_SearchSnapshot(f.request,f.private) and #f.writes==18,'second invocation decremented empty cells')
f=fixture();f.mover.m_typeAI.m_EnemyAlly=128
check(not MRIP_SearchSnapshot(f.request,f.private) and #f.writes==0,'neutral mover snapshot modified')
f=fixture();f.ally.m_typeAI.m_EnemyAlly=128
MRIP_SearchSnapshot(f.request,f.private)
check(f.mem[f.private+10*20+10]==16,'neutral body cleared from search snapshot')
for _,kind in ipairs({'off','cancelled','request-type','owner','request-area','snapshot-pointer','alias-live','dimensions',
    'enemy-mover','mover-size','network','missing-mover','missing-party','duplicate','foreign-area','paint-phase','error'}) do
    f=fixture()
    if kind=='off' then snapshot_test.on=false
    elseif kind=='cancelled' then f.mem[f.request]=4
    elseif kind=='request-type' then f.mem[f.request+4]=1
    elseif kind=='owner' then f.mem[f.mp+0x47F0]=0
    elseif kind=='request-area' then f.mem[f.request+0x18]=1
    elseif kind=='snapshot-pointer' then f.mem[f.ap+0xA60+0x128]=1
    elseif kind=='alias-live' then f.mem[f.ap+0xA60+0x120]=f.private
    elseif kind=='dimensions' then f.mem[f.ap+0xA60+0x138]=321
    elseif kind=='enemy-mover' then f.mover.m_typeAI.m_EnemyAlly=255
    elseif kind=='mover-size' then f.mover.personal=5
    elseif kind=='network' then f.mem[0xB00000+0x2C9]=1
    elseif kind=='missing-mover' then table.remove(f.sprites,1)
    elseif kind=='missing-party' then EEex_Sprite_GetInPortrait=function(slot) return slot==5 and {m_id=99,ptr=99,m_pArea=f.area} or f.sprites[slot+1] end
    elseif kind=='duplicate' then f.sprites[#f.sprites+1]=f.ally
    elseif kind=='foreign-area' then f.ally.m_pArea={ptr=1}
    elseif kind=='paint-phase' then f.mem[f.ally.ptr+0x5254]=1
    else f.area.forAllOfTypeInRange=function() error('fixture callback error') end end
    check(not MRIP_SearchSnapshot(f.request,f.private) and #f.writes==0,'refusal wrote bitmap: '..kind)
end
-- A changed last cell must reject the entire plan, before earlier cells write.
f=fixture();local old=EEex_ReadU8;local reads=0;local final=f.private+231
EEex_ReadU8=function(p)
    if p==final then reads=reads+1;if reads>1 then return old(p)+2 end end
    return old(p)
end
check(not MRIP_SearchSnapshot(f.request,f.private) and #f.writes==0,'changed-cell plan partially committed')
print('Search snapshot passed: '..checks..' policy/adapter assertions')

-- Real adapter handoff for the recorded dismissed-companion overlap.
for _,ea in ipairs({128,255}) do
    f=fixture();f.mover.m_pos.x=168;f.ally.m_typeAI.m_EnemyAlly=ea
    f.mem[f.mp+0x5250]=0;f.mem[f.mp+0x5254]=1
    for key=0,399 do
        local raw=occupancy.footprint({personal=3,x=168,y=126},key%20,math.floor(key/20)) and 16 or 0
        f.mem[f.live+key]=raw;f.mem[f.private+key]=raw
    end
    local original={};for k,v in pairs(f.mem)do original[k]=v end
    check(MRIP_SearchSnapshot(f.request,f.private),'actual adapter omitted overlap origin')
    check(#f.writes==9,'actual adapter did not open the escape footprint')
    for k,v in pairs(original)do
        if k<f.private or k>=f.private+400 then check(f.mem[k]==v,'escape changed live map/actor/request')end
    end
    -- Permission expires immediately when the mover is outside the blocker.
    f.mover.m_pos.x=200
    for key=0,399 do f.mem[f.private+key]=f.mem[f.live+key] end
    f.writes={}
    check(not MRIP_SearchSnapshot(f.request,f.private),'outside mover retains private escape permission')
    check(f.mem[f.private+10*20+10]==16,'normal blocker footprint lost after separation')
end
MRIP_EnemyPrototypeEnabled=true;MRIP_AttackSpacingEnabled=true
f=fixture();f.mover.m_typeAI.m_EnemyAlly=255;f.ally.m_typeAI.m_EnemyAlly=255
check(MRIP_SearchSnapshot(f.request,f.private),'enemy adapter did not open cooperating footprints')
check(#f.writes==18,'enemy adapter footprint count differs from native paint')
f=fixture();f.mover.m_typeAI.m_EnemyAlly=255
MRIP_SearchSnapshot(f.request,f.private)
check(f.mem[f.private+210]==16,'enemy adapter removed opposing party footprint')
f=fixture();f.mover.m_typeAI.m_EnemyAlly=255;f.ally.m_typeAI.m_EnemyAlly=128
MRIP_SearchSnapshot(f.request,f.private)
check(f.mem[f.private+210]==16,'enemy adapter removed neutral footprint')
f=fixture();f.mover.m_typeAI.m_EnemyAlly=255
f.area.forAllOfTypeInRange=function(_,x,y,kind,r,callback) callback(f.mover) end
check(MRIP_SearchSnapshot(f.request,f.private),'enemy search failed when native scan omitted opposing portrait')
check(f.mem[f.private+210]==16,'omitted opposing portrait lost its blocking footprint')
f=fixture();f.mover.m_typeAI.m_EnemyAlly=255
f.area.forAllOfTypeInRange=function(_,x,y,kind,r,callback) callback(f.mover) end
f.mem[f.ally.ptr+0x5254]=1
check(not MRIP_SearchSnapshot(f.request,f.private) and #f.writes==0,'unknown omitted portrait paint phase bypassed proof')
MRIP_EnemyPrototypeEnabled=false
snapshot_escape_fixture=nil
print('Overlap snapshot adapter: '..checks..' assertions passed; writes confined to owned private bitmap')
