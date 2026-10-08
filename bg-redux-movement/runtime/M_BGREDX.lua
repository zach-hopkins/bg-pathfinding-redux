-- BG Pathfinding Redux 0.1.4-preview: select a verified native runtime.
-- Unknown executable builds never reach either payload or install mod hooks.
if MRIP_BaselineRevision or MRIP_DispatchLoaded then return end
MRIP_DispatchLoaded=true
MRIP_PackageVersion='0.1.4-preview'
local profiles={
    ['6A18D6DC:004F84B0:03524000:006DDF33']={id='bgee-steam-2.7.3.0',revision=56,path='bg-redux-movement/runtime/profiles/bgee-steam-2.7.3.0.lua'},
    ['609432DE:004F74D0:03522000:00000000']={id='bgee-steam-2.6.6.0',revision=55,path='bg-redux-movement/runtime/profiles/bgee-steam-2.6.6.0.lua'},
    ['609437B3:004F74D0:03530000:00000000']={
        id='bg2ee-2.6.6.0',revision=53,
        path='bg-redux-movement/runtime/profiles/bg2ee-2.6.6.0.lua'},
    ['6A18D73D:004F84B0:03532000:006DF0E1']={
        id='bg2ee-steam-2.7.3.0',revision=54,
        path='bg-redux-movement/runtime/profiles/bg2ee-steam-2.7.3.0.lua'},
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
    local ok,result=pcall(function()
        assert(type(EEex_GetImageBase)=='function' and type(EEex_Read32)=='function','EEex image-header APIs unavailable')
        local base=EEex_GetImageBase()
        assert(type(base)=='number' and base>0,'invalid executable image base')
        local function u32(offset)
            local value=EEex_Read32(base+offset)
            return value<0 and value+4294967296 or value
        end
        assert(u32(0)%65536==0x5A4D,'invalid executable DOS header')
        local pe=u32(60)
        assert(pe>=64 and pe<=4096,'invalid PE header offset')
        assert(u32(pe)==0x4550,'invalid PE signature')
        assert(u32(pe+4)%65536==0x8664 and u32(pe+24)%65536==0x20B,'unsupported executable architecture')
        return string.format('%08X:%08X:%08X:%08X',u32(pe+8),u32(pe+40),u32(pe+80),u32(pe+88))
    end)
    if not ok then return nil,result end
    return result
end
local id,err=fingerprint()
if not id then disabled(err);return end
local profile=profiles[id]
if not profile then disabled('unrecognized executable build '..id);return end
if type(loadfile)~='function' then disabled('Lua chunk loader unavailable');return end
local load_ok,payload,load_error=pcall(loadfile,profile.path)
if not load_ok then disabled('profile loading failed: '..tostring(payload));return end
if not payload then disabled('missing or invalid profile '..profile.id..': '..tostring(load_error));return end
print('[BG Pathfinding Redux] PROFILE_SELECTED package='..MRIP_PackageVersion..' profile='..profile.id..' revision='..profile.revision)
local ok,runtime_error=pcall(payload)
if not ok then disabled('profile initialization failed: '..tostring(runtime_error));return end
if not MRIP_TraceEnabled then disabled('native signature or layout validation failed for '..profile.id);return end
MRIP_CompatibilityStatus={supported=true,profile=profile.id,revision=profile.revision,package=MRIP_PackageVersion}
