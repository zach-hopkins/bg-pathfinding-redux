-- Portable tests: no game image, native DLL, or hook writes.
local original_open,original_loadfile,original_print=io.open,loadfile,print
local loader='bg-redux-movement/runtime/M_BGREDX.lua'
local source=assert(original_open(loader,'rb')):read('*a')
local run=assert(loadstring(source))
local checks=0
local function expect(value,message) checks=checks+1;assert(value,message) end
local function put32(t,offset,n)
    for i=0,3 do t[offset+i+1]=string.char(math.floor(n/256^i)%256) end
end
local function image(newer)
    local t={};for i=1,240 do t[i]='\0' end
    t[1]='M';t[2]='Z';put32(t,60,128)
    t[129]='P';t[130]='E';t[133]='\100';t[134]='\134';t[153]='\11';t[154]='\2'
    put32(t,136,newer and 0x6A18D73D or 0x609437B3)
    put32(t,168,newer and 0x4F84B0 or 0x4F74D0)
    put32(t,208,newer and 0x3532000 or 0x3530000)
    put32(t,216,newer and 0x6DF0E1 or 0)
    return table.concat(t),newer and 7202696 or 7182336
end
local function test(data,size,expected,mode)
    MRIP_BaselineRevision=nil;MRIP_DispatchLoaded=nil;MRIP_TraceEnabled=nil;MRIP_CompatibilityStatus=nil
    local loads,closed,printed,listeners,displayed=0,0,{}, {},{}
    io.open=function(path)
        expect(path=='Baldur.exe','only executable header is opened')
        if not data then return nil,'fixture missing file' end
        local position=0
        return {seek=function(_,where,offset)
            if where=='end' then position=size;return size end
            position=offset;return offset
        end,read=function(_,n) local value=data:sub(position+1,position+n);position=position+#value;return value end,
            close=function() closed=closed+1 end}
    end
    loadfile=function(path)
        loads=loads+1
        expect(path=='bg-redux-movement/runtime/profiles/'..expected..'.lua','correct profile selected')
        if mode=='missing' then return nil,'missing payload fixture' end
        return function()
            if mode=='throw' then error('runtime fixture failed') end
            MRIP_TraceEnabled=mode~='guard'
            MRIP_BaselineRevision=expected=='bg2ee-2.6.6.0' and 53 or 54
        end
    end
    print=function(s) printed[#printed+1]=s end
    EEex_GameState_AddInitializedListener=function(f) listeners[#listeners+1]=f end
    Infinity_DisplayString=function(s) displayed[#displayed+1]=s end
    run()
    local supported=expected~=nil and mode==nil
    expect(MRIP_CompatibilityStatus.supported==supported,'compatibility status')
    expect(loads==(expected and 1 or 0),'unknown builds never load a payload')
    expect(closed==(data and 1 or 0),'header handle closed')
    if not supported then
        expect(#listeners==1,'one visible refusal message')
        listeners[1]();expect(#displayed==1 and displayed[1]:find('Native movement remains active',1,true),'refusal preserves native fallback')
        expect(table.concat(printed):find('COMPATIBILITY_DISABLED',1,true),'refusal logged')
    else
        expect(#listeners==0 and MRIP_CompatibilityStatus.profile==expected,'accepted profile state')
    end
    local before=loads;run();expect(loads==before,'duplicate guard')
end
local old,old_size=image(false);local new,new_size=image(true)
test(old,old_size,'bg2ee-2.6.6.0')
test(new,new_size,'bg2ee-steam-2.7.3.0')
test(new,new_size+1,nil)
test(new:sub(1,136)..'\0\0\0\0'..new:sub(141),new_size,nil)
test(nil,0,nil)
test('not an executable',300,nil)
test(new:sub(1,180),new_size,nil)
test(new:sub(1,128)..'NO'..new:sub(131),new_size,nil)
test(new:sub(1,132)..'\0\0'..new:sub(135),new_size,nil)
test(new,new_size,'bg2ee-steam-2.7.3.0','missing')
test(new,new_size,'bg2ee-steam-2.7.3.0','throw')
test(new,new_size,'bg2ee-steam-2.7.3.0','guard')
io.open,loadfile,print=original_open,original_loadfile,original_print
MRIP_BaselineRevision=nil;MRIP_DispatchLoaded=nil;MRIP_TraceEnabled=nil
print('Profile selection: '..checks..' assertions; known versions, updates, invalid headers, missing files, initialization failure and duplicate guard')
