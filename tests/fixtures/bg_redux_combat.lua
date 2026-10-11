-- Same combat-only predicate as CGameArea::CanSaveGame(checkCombat=1).
-- Quicksave scans all 12 loaded areas; dialogue/quest save restrictions are unrelated.
local combat_state,combat_blocked,combat_last,combat_error=nil,false,nil,false
local combat_grants={}
local function combat_actor(sprite)
    local a={id=sprite.m_id,owner=EEex_UDToPtr(sprite),
        area=sprite.m_pArea and EEex_UDToPtr(sprite.m_pArea) or 0,
        ea=sprite.m_typeAI.m_EnemyAlly,x=sprite.m_pos.x,y=sprite.m_pos.y,personal=sprite:getPersonalSpace()}
    assert(a.personal>=1 and a.personal<=255 and a.x>=0 and a.y>=0,'invalid combat actor')
    return a
end
local function combat_capture()
    local game=EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
    local actors,seen={},{}
    for slot=0,11 do
        local area=game.m_gameAreas:get(slot)
        if area and EEex_UDToPtr(area)~=0 then
            area:forAllOfTypeInRange(0,0,CAIObjectType.ANYONE,32767,function(object)
                if object and EEex_GameObject_IsSprite(object,true) then
                    local s=EEex_CastUD(object,'CGameSprite')
                    if overlap_escape.ally(s.m_typeAI.m_EnemyAlly) and not seen[s.m_id] then
                        assert(#actors<256,'combat ally limit')
                        local a=combat_actor(s);actors[#actors+1]=a;seen[a.id]=true
                    end
                end
            end,0,0)
        end
    end
    return overlap_escape.capture(actors)
end
local function combat_prune()
    -- Resolve IDs anew: never retain sprite userdata across heartbeats.
    for id,r in pairs(combat_grants) do
        local s=EEex_GameObject_Get(id)
        if not s or not EEex_GameObject_IsSprite(s,true) then combat_grants[id]=nil
        else
            local m=combat_actor(EEex_CastUD(s,'CGameSprite'))
            overlap_escape.bind(combat_grants,m)
            if combat_grants[id] then
                for other,g in pairs(r.pairs) do
                    local b=EEex_GameObject_Get(other)
                    local a=b and EEex_GameObject_IsSprite(b,true) and combat_actor(EEex_CastUD(b,'CGameSprite')) or nil
                    if not a or a.owner~=g.owner or a.area~=g.area or not overlap_escape.ally(a.ea)
                        or not overlap_escape.footprint(a,math.floor(m.x/16),math.floor(m.y/12)) then r.pairs[other]=nil end
                end
                if not next(r.pairs) then combat_grants[id]=nil end
            end
        end
    end
end
local function combat_refresh(force)
    local now=clock()
    if not force and now and combat_last and now>=combat_last and now-combat_last<50 then return combat_blocked end
    combat_last=now
    local blocked=false
    if MRIP_OutOfCombatOnly then
        local ok,value=pcall(function()
            local game=EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
            for slot=0,11 do
                local area=game.m_gameAreas:get(slot)
                if area and EEex_UDToPtr(area)~=0 and (area.m_nBattleSongCounter>0 or area.m_nDamageCounter>0) then return true end
            end
            return false
        end)
        blocked=not ok or value
        if not ok and not combat_error then combat_error=true;log('COMBAT_CHECK_ERROR '..tostring(value)) end
    end
    if blocked and not combat_blocked then
        local ok,grants,count=pcall(combat_capture)
        combat_grants=ok and grants or {}
        log('COMBAT_ESCAPE_CAPTURE pairs='..tostring(ok and count or 0)..(ok and '' or ' error='..tostring(grants)))
    elseif not blocked then combat_grants={}
    else
        local ok,err=pcall(combat_prune)
        if not ok then combat_grants={};log('COMBAT_ESCAPE_PRUNE error='..tostring(err)) end
    end
    if blocked~=combat_blocked then log('COMBAT_COLLISION blocked='..tostring(blocked)) end
    combat_blocked=blocked
    MRIP_CombatActive=blocked
    if combat_state then EEex_Write32(combat_state,blocked and 1 or 0) end
    return blocked
end
local function allied_combat_blocked(sprite)
    return combat_refresh(false) and sprite and sprite.m_typeAI.m_EnemyAlly>=2 and sprite.m_typeAI.m_EnemyAlly<=30
end
local function combat_escape_for(a)
    if not combat_blocked then return nil end
    return overlap_escape.bind(combat_grants,a)
end
function MRIP_ToggleCombatOnly()
    MRIP_OutOfCombatOnly=not MRIP_OutOfCombatOnly
    combat_refresh(true)
    feedback('outside-combat-only allied passage '..(MRIP_OutOfCombatOnly and 'ON' or 'OFF'))
end
