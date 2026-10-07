-- BG Pathfinding Redux 0.1.1-preview: select a verified native runtime.
-- Unknown executable builds never reach either payload or install mod hooks.
if MRIP_BaselineRevision or MRIP_DispatchLoaded then return end
MRIP_DispatchLoaded=true
MRIP_PackageVersion='0.1.1-preview'
local profiles={
    ['609437B3:004F74D0:03530000:00000000:7182336']={
        id='bg2ee-2.6.6.0',revision=53,
        path='mrdx-movement/runtime/profiles/bg2ee-2.6.6.0.lua'},
    ['6A18D73D:004F84B0:03532000:006DF0E1:7202696']={
        id='bg2ee-steam-2.7.3.0',revision=54,
        path='mrdx-movement/runtime/profiles/bg2ee-steam-2.7.3.0.lua'},
}
local function disabled(reason)
    MRIP_CompatibilityStatus={supported=false,reason=tostring(reason),package=MRIP_PackageVersion}
    local message='BG Pathfinding Redux disabled: '..tostring(reason)..'. Native movement remains active; update the mod and EEex for this game build.'
    print('[BG Pathfinding Redux] COMPATIBILITY_DISABLED '..message)
    if type(EEex_GameState_AddInitializedListener)=='function' then
        EEex_GameState_AddInitializedListener(function()
            if type(Infinity_DisplayString)=='function' then Infinity_DisplayString(message) end
        end)
    end
end
local function fingerprint()
    local file,err=io.open('Baldur.exe','rb')
    if not file then return nil,'cannot read Baldur.exe: '..tostring(err) end
    local ok,result=pcall(function()
        local size=assert(file:seek('end'),'cannot determine executable size')
        assert(file:seek('set',0)==0,'cannot read executable header')
        local header=assert(file:read(64),'missing executable header')
        assert(#header==64 and header:sub(1,2)=='MZ','invalid executable header')
        local function u32(text,offset)
            local a,b,c,d=text:byte(offset+1,offset+4)
            assert(d,'truncated executable header')
            return a+b*256+c*65536+d*16777216
        end
        local pe=u32(header,60)
        assert(pe>=64 and pe<=4096 and pe+112<=size,'invalid PE header offset')
        assert(file:seek('set',pe)==pe,'cannot seek PE header')
        local fields=assert(file:read(112),'missing PE header')
        assert(#fields==112 and fields:sub(1,4)=='PE\0\0','invalid PE signature')
        assert(fields:sub(5,6)=='\100\134' and fields:sub(25,26)=='\11\2','unsupported executable architecture')
        return string.format('%08X:%08X:%08X:%08X:%d',u32(fields,8),u32(fields,40),u32(fields,80),u32(fields,88),size)
    end)
    file:close()
    if not ok then return nil,result end
    return result
end
local id,err=fingerprint()
if not id then disabled(err);return end
local profile=profiles[id]
if not profile then disabled('unrecognized executable build '..id);return end
local payload,load_error=loadfile(profile.path)
if not payload then disabled('missing or invalid profile '..profile.id..': '..tostring(load_error));return end
print('[BG Pathfinding Redux] PROFILE_SELECTED package='..MRIP_PackageVersion..' profile='..profile.id..' revision='..profile.revision)
local ok,runtime_error=pcall(payload)
if not ok then disabled('profile initialization failed: '..tostring(runtime_error));return end
if not MRIP_TraceEnabled then disabled('native signature or layout validation failed for '..profile.id);return end
MRIP_CompatibilityStatus={supported=true,profile=profile.id,revision=profile.revision,package=MRIP_PackageVersion}
