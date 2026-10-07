-- Public logging: normal play reports status/errors; detailed telemetry is opt-in.
local diagnostic_output=false
local function with_diagnostics(callback)
    local previous=diagnostic_output;diagnostic_output=true
    local ok,result=pcall(callback)
    diagnostic_output=previous
    if not ok then error(result) end
    return result
end
local function log(message)
    local tag=message:match('^%S+') or ''
    if not active and not diagnostic_output then
        if not (tag=='LOADED' or tag=='CONFIG_DEFAULT' or tag:match('_READY$')
            or tag:match('_MODE$') or tag=='MOVEMENT_ENABLED' or tag=='MOVEMENT_DISABLED'
            or tag:find('ERROR',1,true) or tag:find('DISABLED',1,true)) then return end
        print(prefix..' '..message)
        return
    end
    event=event+1
    local now=clock()
    local elapsed=now and started_ms and now-started_ms or -1
    print(string.format("%s clock_ms=%s elapsed_ms=%d run=%d event=%d %s", prefix,tostring(now or "unavailable"),math.max(-1,elapsed),run,event,message))
end
local function feedback(message)
    if not MRIP_StartupActivation and e~=nil and worldScreen==e:GetActiveEngine() then
        Infinity_DisplayString(prefix.." "..message)
    end
end
