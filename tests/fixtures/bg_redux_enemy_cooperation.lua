-- Experimental normal-size cooperation, deliberately OFF on every launch.
-- Matching hostile EA is a prototype approximation, not a faction registry.
local P={}
local targets={}
local waits={}
local attacks={[3]=true,[94]=true,[98]=true,[105]=true,[134]=true}
function P.enemy(ea) return ea>=200 and ea<=255 end
function P.enabled() return MRIP_EnemyPrototypeEnabled and MRIP_AttackSpacingEnabled end
function P.mover(a) return P.enabled() and P.enemy(a.ea) and a.personal==3 end
function P.friend(m,a)
    return m and P.mover(m) and a.personal==3 and a.ea==m.ea
        and m.attack_target~=a.id and a.attack_target~=m.id
end
function P.observe(id,owner,area,target,now)
    if not P.enabled() then return end
    local count=0
    for other,r in pairs(targets) do
        if now<r.updated or now-r.updated>1500 then targets[other]=nil
        else count=count+1 end
    end
    if count>=256 and not targets[id] then return end
    targets[id]={owner=owner,area=area,target=target,updated=now}
end
function P.bind(a,owner,area,now)
    local r=targets[a.id]
    if r and r.owner==owner and r.area==area and now and now>=r.updated and now-r.updated<=1500 then
        a.attack_target=r.target
    elseif r then targets[a.id]=nil end
    return a
end
function P.hold(a,r,now)
    return type(now)=='number' and r.enemy_ea and P.mover(a) and a.ea==r.enemy_ea and r.updated
        and now>=r.updated and now-r.updated<=1500
        and (not a.attack_target or a.attack_target==r.target)
        and (attacks[a.action] or (a.action==0 or a.action==83) and now-r.updated<=600)
end
local function same(r,owner,area,target,target_ptr)
    return r and r.owner==owner and r.area==area and r.target==target and r.target_ptr==target_ptr
end
function P.wait_active(id,owner,area,target,target_ptr,now)
    local r=waits[id]
    return type(now)=='number' and same(r,owner,area,target,target_ptr) and now>=r.since and now-r.since<600
end
function P.wait_recent(id,owner,area,target,target_ptr,now)
    local r=waits[id]
    return P.wait_active(id,owner,area,target,target_ptr,now) and now-r.checked<100
end
function P.wait(id,owner,area,target,target_ptr,now)
    local r=waits[id]
    if not same(r,owner,area,target,target_ptr) then
        local count=0;for _ in pairs(waits) do count=count+1 end
        if count>=256 and not r then return false end
        r={owner=owner,area=area,target=target,target_ptr=target_ptr,since=now,checked=now}
        waits[id]=r
    end
    r.checked=now
    -- Keep the expired record until this engagement changes; no endless re-wait.
    return P.wait_active(id,owner,area,target,target_ptr,now)
end
function P.cancel_wait(id) waits[id]=nil end
function P.reset() targets={};waits={} end
function P.clear(id) targets[id]=nil end
return P
