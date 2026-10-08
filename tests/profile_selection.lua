-- Run the real selector without the io library exposed by luaL_openlibs().
local original_io,original_loadfile,original_print=io,loadfile,print
local original_base,original_read=EEex_GetImageBase,EEex_Read32
local loader='bg-redux-movement/runtime/M_BGREDX.lua'
local source=assert(original_io.open(loader,'rb')):read('*a')
local run=assert(loadstring(source))
local checks=0
local function expect(value,message)checks=checks+1;assert(value,message)end
local function put32(t,offset,n)
    for i=0,3 do t[offset+i+1]=string.char(math.floor(n/256^i)%256)end
end
local function image(newer,change)
    local t={};for i=1,240 do t[i]='\0' end
    t[1]='M';t[2]='Z';put32(t,60,128)
    t[129]='P';t[130]='E';t[133]='\100';t[134]='\134';t[153]='\11';t[154]='\2'
    put32(t,136,newer and 0x6A18D73D or 0x609437B3)
    put32(t,168,newer and 0x4F84B0 or 0x4F74D0)
    put32(t,208,newer and 0x3532000 or 0x3530000)
    put32(t,216,newer and 0x6DF0E1 or 0)
    if change then put32(t,change[1],change[2])end
    return table.concat(t)
end
local function test(data,expected,mode)
    MRIP_BaselineRevision=nil;MRIP_DispatchLoaded=nil;MRIP_TraceEnabled=nil;MRIP_CompatibilityStatus=nil
    local loads,printed,listeners,displayed=0,{}, {},{}
    io=nil
    EEex_GetImageBase=function()return mode=='bad-base' and 0 or 0x140000000 end
    EEex_Read32=function(address)
        local offset=address-0x140000000
        expect(offset>=0 and offset+4<=#data,'reads remain inside bounded header fixture')
        local a,b,c,d=data:byte(offset+1,offset+4);local n=a+b*256+c*65536+d*16777216
        return n>=0x80000000 and n-4294967296 or n
    end
    if mode=='missing-api' then EEex_Read32=nil end
    loadfile=function(path)
        loads=loads+1
        expect(path=='bg-redux-movement/runtime/profiles/'..expected..'.lua','correct profile selected')
        if mode=='missing' then return nil,'missing payload fixture' end
        if mode=='load-throw' then error('loader fixture failed')end
        return function()
            expect(io==nil,'selected payload runs without io')
            if mode=='throw' then error('runtime fixture failed')end
            MRIP_TraceEnabled=mode~='guard'
            MRIP_BaselineRevision=expected=='bg2ee-2.6.6.0' and 53 or 54
        end
    end
    if mode=='missing-loader' then loadfile=nil end
    print=function(s)printed[#printed+1]=s end
    EEex_GameState_AddInitializedListener=function(f)listeners[#listeners+1]=f end
    Infinity_DisplayString=function(s)displayed[#displayed+1]=s end
    expect(pcall(run),'selector must not throw with io absent')
    local supported=expected~=nil and mode==nil
    expect(MRIP_CompatibilityStatus.supported==supported,'compatibility status')
    expect(loads==((expected and mode~='missing-loader') and 1 or 0),'unknown builds never load a payload')
    if not supported then
        expect(#listeners==1,'one visible refusal message');listeners[1]()
        expect(#displayed==1 and displayed[1]:find('Native movement remains active',1,true),'native fallback')
        expect(table.concat(printed):find('COMPATIBILITY_DISABLED',1,true),'refusal logged')
    else expect(#listeners==0 and MRIP_CompatibilityStatus.profile==expected,'accepted profile state')end
    local before=loads;run();expect(loads==before,'duplicate guard')
end
local bg1=image(false);local bg1t={};for i=1,#bg1 do bg1t[i]=bg1:sub(i,i)end
put32(bg1t,136,1620325086)
put32(bg1t,168,5207248)
put32(bg1t,208,55713792)
put32(bg1t,216,0)
test(table.concat(bg1t),'bgee-steam-2.6.6.0')
put32(bg1t,136,1780012764)
put32(bg1t,168,5211312)
put32(bg1t,208,55721984)
put32(bg1t,216,7200563)
test(table.concat(bg1t),'bgee-steam-2.7.3.0')
local old,new=image(false),image(true)
test(old,'bg2ee-2.6.6.0');test(new,'bg2ee-steam-2.7.3.0')
for _,change in ipairs({{208,0x3532001},{136,0},{60,0x1001},{128,0},{132,0},{152,0}})do test(image(true,change),nil)end
test(new,nil,'missing-api');test(new,nil,'bad-base')
for _,mode in ipairs({'missing','load-throw','throw','guard','missing-loader'})do test(new,'bg2ee-steam-2.7.3.0',mode)end
io,loadfile,print=original_io,original_loadfile,original_print
EEex_GetImageBase,EEex_Read32=original_base,original_read
MRIP_BaselineRevision=nil;MRIP_DispatchLoaded=nil;MRIP_TraceEnabled=nil
print('Profile selection: '..checks..' assertions; io=nil, loaded PE identity, safe refusal, missing APIs/loader and duplicate guard')
