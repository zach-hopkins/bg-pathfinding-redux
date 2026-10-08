-- Read-only context, emitted only by explicitly requested snapshots/captures.
local S={}
local function safe(callback)
    local ok,value=pcall(callback)
    if not ok or value==nil then return 'unavailable' end
    return tostring(value):gsub('[%c]',' '):sub(1,256)
end
function S.header()
    local status=MRIP_CompatibilityStatus or {}
    return 'package='..tostring(MRIP_PackageVersion or 'unavailable')
        ..' profile='..tostring(status.profile or 'unavailable')
        ..' revision='..tostring(MRIP_BaselineRevision or 'unavailable')
        ..' paused='..safe(function()return worldScreen:CheckIfPaused()end)
end
function S.party(sprite)
    local area=safe(function()return sprite.m_pArea.m_resref:get()end)
    local creature=safe(function()return sprite.m_resref:get()end)
    local queued=safe(function()
        assert(type(EEex_Utility_IterateCPtrList)=='function' and sprite.m_queuedActions)
        local count=0
        EEex_Utility_IterateCPtrList(sprite.m_queuedActions,function()
            count=count+1;return count>=64
        end)
        return count>=64 and '64-or-more' or count
    end)
    return string.format('area=%q creature=%q queued=%s',area,creature,queued)
end
return S
