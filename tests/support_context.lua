local fragment=assert(io.open('tests/fixtures/bg_redux_support_context.lua')):read('*a')
local S=assert(loadstring(fragment))()
MRIP_PackageVersion='fixture';MRIP_BaselineRevision=56
MRIP_CompatibilityStatus={profile='bgee-steam-2.7.3.0'}
worldScreen={CheckIfPaused=function()return true end}
assert(S.header():find('paused=true',1,true))
assert(S.header():find('profile=bgee-steam-2.7.3.0',1,true))
local sprite={m_pArea={m_resref={get=function()return 'ARTEST' end}},
    m_resref={get=function()return 'TESTCRE' end},m_queuedActions={1,2}}
EEex_Utility_IterateCPtrList=function(list,fn)for _,v in ipairs(list)do if fn(v)then break end end end
assert(S.party(sprite)=='area="ARTEST" creature="TESTCRE" queued=2')
sprite.m_queuedActions={};for i=1,100 do sprite.m_queuedActions[i]=i end
assert(S.party(sprite):find('queued=64-or-more',1,true))
assert(S.party({})=='area="unavailable" creature="unavailable" queued=unavailable')
worldScreen=nil;MRIP_CompatibilityStatus=nil
assert(S.header():find('paused=unavailable',1,true))
assert(S.header():find('profile=unavailable',1,true))
sprite.m_pArea.m_resref.get=function()return 'area\nname' end
assert(S.party(sprite):find('area="area name"',1,true))
print('Support context: missing fields, bounded queue, safe area/creature IDs and package/profile status passed')
