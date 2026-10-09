-- Exercise the shipped Lua policies, not a separate imitation of the runtime.
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local function actor(id,ea,x,y,category)
    return {id=id,ea=ea,x=x or 168,y=y or 126,category=category or 0,
        personal=3,painted=1,removed=0,party=ea==2,state=0,base_state=0,
        action=23,busy=0,bump=0}
end
local function embedded(source,name,next_name,bindings)
    local start=assert(source:find('local '..name,1,true))
    local finish=assert(source:find(next_name,start,true))
    local chunk=source:sub(start,finish-1)
    return assert(loadstring((bindings or '')..chunk..'\nreturn '..name:match('^%w+_?[%w_]*')))()
end
local fragment=assert(io.open('tests/fixtures/bg_redux_overlap_escape.lua')):read('*a')
for _,profile in ipairs({'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}) do
    local source=assert(io.open('bg-redux-movement/runtime/profiles/'..profile..'.lua')):read('*a')
    check(source:find(fragment,1,true)~=nil,'escape fixture differs from shipped profile')
    local escape=embedded(source,'overlap_escape=','local pass_policy')
    overlap_test_escape=escape
    local pass=embedded(source,'pass_policy =','-- Embedded by build_mrip_prototype',
        'local overlap_escape=overlap_test_escape\n')
    local snap=embedded(source,'snapshot_policy=','-- SearchThreadMain',
        'local overlap_escape=overlap_test_escape\n')
    local occupancy=embedded(source,'attack_policy=','local attack_reservations')
    for _,ea in ipairs({128,200,255}) do for category=0,1 do
        local m=actor(1,2);m.painted=0;m.removed=1
        local b=actor(2,ea,nil,nil,category)
        local actors={m,b}
        local weight=category==0 and 16 or 2
        local function raw(x,y)
            local n=0
            for _,a in ipairs(actors) do
                if a.painted==1 and a.removed==0 and escape.footprint(a,x,y) then
                    n=n+(a.category==0 and 16 or 2)
                end
            end
            return n
        end
        local function allowed(x,y,extra)
            return pass.evaluate({mover=m,width=30,height=30,x=x,y=y,
                actors=actors,party={m},cell=raw(x,y)+(extra or 0)})
        end
        check(allowed(11,10),'exact neutral/enemy stack cannot escape')
        check(allowed(9,10),'exact stack cannot escape in opposite direction')
        check(not allowed(11,10,128),'escape opens closed door')
        check(not allowed(11,10,1),'escape opens static obstruction')
        m.x=184 -- cell11, already offset inside blocker footprint
        check(not allowed(10,10),'escape admits inward movement')
        check(not escape.outward(m,b,9,11),'escape crosses behind blocker')
        check(escape.outward(m,b,11,11),'escape rejects outward diagonal')
        m.x=200 -- cell12, now outside: old overlap grants no lasting permission
        check(not allowed(11,10),'separated mover can re-enter blocker')
        m.x=168
        local other=actor(3,128,200,126,1-category);actors[3]=other
        check(not allowed(11,10),'escape opens unrelated blocker')
        actors[3]=nil
        local ally=actor(4,2,nil,nil,1-category);actors[3]=ally
        check(allowed(11,10),'mixed ally/foreign counter accounting fails')
        actors[3]=nil
        check(not pass.evaluate({mover=m,width=30,height=30,x=11,y=10,
            actors=actors,party={m},cell=weight+(category==0 and 2 or 16)}),'unknown paint cleared')
        local patches=snap.plan({mover=m,width=30,height=30,actors=actors,
            read_live=raw,read_snapshot=raw},occupancy)
        check(patches and #patches==9,'search cannot seed escape from exact stack')
        for _,p in ipairs(patches) do check(p.after==0,'private counter not cleared') end
        m.x=184
        patches=snap.plan({mover=m,width=30,height=30,actors=actors,
            read_live=raw,read_snapshot=raw},occupancy)
        for _,p in ipairs(patches) do
            check(escape.outward(m,b,p.key%30,math.floor(p.key/30)),
                'private search opens inward blocker cell')
        end
        m.x=200
        patches=snap.plan({mover=m,width=30,height=30,actors=actors,
            read_live=raw,read_snapshot=raw},occupancy)
        check(patches and #patches==0,'private search removes a blocker from outside')
        m.x=168;b.painted=1;b.removed=1
        check(not allowed(11,10),'unknown paint phase grants escape')
        b.painted=1;b.removed=0
        m.ea=255;check(not allowed(11,10),'enemy mover granted ally escape')
    end end
end
overlap_test_escape=nil
print('Overlap escape: '..checks..' assertions across four actual runtime profiles passed')
