-- Exercise the exact logging/feedback fragment linked to both release profiles.
local checks=0
local function expect(value,message)assert(value,message);checks=checks+1 end
local fragment=assert(io.open('tests/fixtures/bg_redux_public_logging.lua')):read('*a')
local lines,feedback_lines={},{}
local env={MRIP_StartupActivation=false,worldScreen=42,Infinity_DisplayString=function(s)feedback_lines[#feedback_lines+1]=s end,
    print=function(s)lines[#lines+1]=s end,e={GetActiveEngine=function()return 42 end}}
setmetatable(env,{__index=_G})
local chunk=assert(loadstring([[local prefix='[BG Redux]'
local active,event,run,started_ms=false,0,0,nil
local function clock()return 100 end
]]..fragment..[[
return {log=log,feedback=feedback,diagnostic=with_diagnostics,set_active=function(v)active=v end}
]]))
setfenv(chunk,env);local L=chunk()
for _,tag in ipairs({'SETTLE_MOVE','SETTLE_END','SETTLE_KEEP','ATTACK_NATIVE_HANDOFF','PREFERENCE_QUERY','PREFERENCE_USED','MOVEMENT_STATE','PARTY','NATIVE'})do
    local n=#lines;L.log(tag..' fixture');expect(#lines==n,'routine telemetry must be quiet: '..tag)
end
for _,tag in ipairs({'LOADED','HOOKS_READY','PREFERENCE_READY','RELEASE_READY','CONFIG_DEFAULT','CONFIG_WRITE_ERROR','SETTLE_ERROR','ERROR','DISABLED','MOVEMENT_ENABLED','ATTACK_MODE'})do
    local n=#lines;L.log(tag..' fixture');expect(#lines==n+1 and lines[#lines]=='[BG Redux] '..tag..' fixture','important status retained: '..tag)
end
L.set_active(true);L.log('SETTLE_MOVE fixture');expect(lines[#lines]:find('clock_ms=100',1,true)~=nil,'capture includes detailed metadata')
L.set_active(false);L.diagnostic(function()L.log('PARTY fixture')end);expect(lines[#lines]:find('PARTY fixture',1,true)~=nil,'explicit snapshot retained')
local n=#lines;L.log('PARTY fixture');expect(#lines==n,'snapshot verbosity ends')
local ok=pcall(function()L.diagnostic(function()error('fixture snapshot failure')end)end)
expect(not ok,'diagnostic error propagates');n=#lines;L.log('PARTY fixture');expect(#lines==n,'diagnostic error cannot leave verbose mode on')
L.feedback('allied movement ON');expect(#feedback_lines==1 and feedback_lines[1]=='[BG Redux] allied movement ON','manual toggle confirmation retained')
env.MRIP_StartupActivation=true;L.feedback('allied movement ON');expect(#feedback_lines==1,'automatic startup does not add a chat message')
env.MRIP_StartupActivation=false;L.feedback('feature unavailable');expect(#feedback_lines==2,'failure feedback retained')
print('Public logging: '..checks..' assertions; quiet normal play, startup/errors, explicit capture/snapshot and feedback')
