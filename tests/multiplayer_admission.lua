local profiles={'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}
local checks=0
local function check(value,message)checks=checks+1;assert(value,message)end
local bit=require('bit')
for _,profile in ipairs(profiles)do
    local path='bg-redux-movement/runtime/profiles/'..profile..'.lua'
    local file=assert(io.open(path));local source=file:read('*a');file:close()
    check(not source:find('EEex_ReadU8(chitin+0x2C9)',1,true),'network refusal remains')
    local start=assert(source:find('local function settle_world()',1,true))
    local finish=assert(source:find('local function settle_safe',start,true))
    local env={base=0,paused=false,dialogue=false,chitin=1,mode=0x800}
    env.worldScreen={CheckIfPaused=function()return env.paused end}
    env.e={GetActiveEngine=function()return env.worldScreen end}
    env.EEex_EngineGlobal_CBaldurChitin={m_pObjectGame={m_gameSave={m_inputMode=env.mode}}}
    env.EEex_BAnd=bit.band
    env.Infinity_IsMenuOnStack=function()return env.dialogue end
    env.EEex_ReadPtr=function()return env.chitin end
    env.EEex_ReadU8=function()error('network flag must not be consulted')end
    setmetatable(env,{__index=_G})
    local chunk=assert(loadstring(source:sub(start,finish-1)..'\nreturn settle_world'))
    setfenv(chunk,env);local allowed=chunk()
    check(allowed(),'network-enabled world not admitted')
    env.paused=true;check(not allowed(),'pause safety lost');env.paused=false
    env.dialogue=true;check(not allowed(),'dialogue safety lost');env.dialogue=false
    env.chitin=0;check(not allowed(),'missing engine safety lost');env.chitin=1
    env.EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_gameSave.m_inputMode=0
    check(not allowed(),'input mode safety lost')
    env.EEex_EngineGlobal_CBaldurChitin.m_pObjectGame=nil
    check(not allowed(),'missing game safety lost')
end
print('Experimental multiplayer admission: '..checks..' assertions across four profiles; no peer synchronization emulated')
