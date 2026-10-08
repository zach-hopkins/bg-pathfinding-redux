-- Exercise the lazy settle factory against the actual executable, without running native code.
local function file(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local source=file(MRIP_TEST_RUNTIME_PATH)
local body=assert(source:match('local settle_native_factory=%(function%(%)\n(.-)\nend%)%(%)'),'embedded settle factory missing')
local factory=assert(loadstring(body))()
local constructor=assert(tonumber(body:match('local address=base%+(0x%x+)')))
local image=file(MRIP_TEST_EXECUTABLE_PATH or MRIP_TEST_GAME_PATH..'/Baldur.exe')
local function u32(p)local a,b,c,d=image:byte(p+1,p+4);return a+b*256+c*65536+d*16777216 end
local pe=u32(60);local count=image:byte(pe+7)+image:byte(pe+8)*256
local table_start=pe+24+image:byte(pe+21)+image:byte(pe+22)*256
local sections={}
for i=0,count-1 do local p=table_start+i*40;sections[#sections+1]={rva=u32(p+12),size=u32(p+16),raw=u32(p+20)}end
local base=0x140000000
local function read(address)
 local rva=address-base
 for _,s in ipairs(sections)do if rva>=s.rva and rva<s.rva+s.size then return image:byte(s.raw+rva-s.rva+1)end end
 error('unmapped settle byte')
end
local registrations,calls,labels=0,0,{}
EEex_DefineAssemblyLabel=function(name,address)labels[name]=address end
EEex_JITNearAsLuaFunction=function(name,parts)
 assert(name=='MRIP_SettleStopNative' and #parts==1)
 assert(parts[1]:find('#L(MRIP_SettleStopConstructor)',1,true))
 registrations=registrations+1
 local f=assert(io.open('tests/.work/native/settle-stop-bridge-expanded.txt','w'))
 f:write((parts[1]:gsub('#L%(Hardcoded_lua_tointegerx%)','native_lua_tointegerx'):gsub('#L%(MRIP_SettleStopConstructor%)','native_settle_stop')));f:close()
 _G[name]=function(storage,id,ptr)assert(storage==0x123456780 and id==42 and ptr==0x123456790);calls=calls+1 end
end
local stack=function(size,fn)assert(size==16);fn(0x123456780)end
local pointer=function(sprite)return sprite.ptr end
local ok,err=pcall(factory,base,function()return 0 end,stack,pointer)
assert(not ok and tostring(err):find('signature mismatch',1,true) and registrations==0)
for _,address in ipairs({0x140000000,0x7FF600000000})do
 base=address
 local stop=factory(base,read,stack,pointer)
 assert(labels.MRIP_SettleStopConstructor==base+constructor)
 stop({m_id=42,ptr=0x123456790})
end
assert(registrations==2 and calls==2)
print('Lazy settle backend passed: actual constructor bytes, corrupted-guard refusal, registration, numeric arguments and relocated base')
