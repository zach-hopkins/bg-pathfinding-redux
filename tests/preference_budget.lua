-- Execute the actual shipped slow-budget branches, including their side effects.
local checks=0
for _,profile in ipairs({'bg2ee-2.6.6.0','bg2ee-steam-2.7.3.0','bgee-steam-2.6.6.0','bgee-steam-2.7.3.0'}) do
 local source=assert(io.open('bg-redux-movement/runtime/profiles/'..profile..'.lua')):read('*a')
 local branches={
  {start='    if elapsed>4 then',finish='    if status~=1',reason='elapsed-budget',limit=4},
  {start='    if clock()-evaluation_started>8 then',finish='    if allied_combat_blocked(sprite)',reason='evaluation-budget',limit=8}}
 for _,b in ipairs(branches) do
  local start=assert(source:find(b.start,1,true))
  while true do local next_start=source:find(b.start,start+1,true);if not next_start then break end;start=next_start end
  local stop=assert(source:find(b.finish,start,true))
  local branch=source:sub(start,stop-1)
  for _,slow in ipairs({false,true,false,true}) do
   local duration=slow and b.limit+1 or b.limit
   local logs={};local env={MRIP_PreferenceEnabled=true,elapsed=duration,evaluation_started=100,preference_state=123,sprite={},
    clock=function()return 100+duration end,log=function(line)logs[#logs+1]=line end,
    EEex_Write32=function()error('budget branch changed native preference flag')end,
    feedback=function()error('budget branch printed shutdown notification')end,
    preference_keep=function(_,reason)return reason end}
   setmetatable(env,{__index=_G});local c=assert(loadstring(branch..'\nreturn false'));setfenv(c,env)
   local result=c();assert(result==(slow and b.reason or false));checks=checks+1
   assert(env.MRIP_PreferenceEnabled and #logs==(slow and 1 or 0));checks=checks+1
  end
 end
end
print('Visual preference budget: '..checks..' assertions; slow requests fall back without disabling later preference')
