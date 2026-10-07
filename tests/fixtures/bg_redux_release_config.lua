-- Persistent release switches, using EEex's installed INI API.
local R={path='.\\bg-redux-movement.ini',section='Movement',keys={
    {'Movement',true},{'AttackSpacing',true},{'GentleSettle',true},{'RoutePreference',false}}}
function R.read(getter)
    assert(type(getter)=='function','EEex INI reader unavailable')
    local options,warnings={},{}
    for _,entry in ipairs(R.keys)do
        local key,default=entry[1],entry[2]
        local raw=getter(R.path,R.section,key,default and '1' or '0')
        if raw=='1' then options[key]=true
        elseif raw=='0' then options[key]=false
        else options[key]=default;warnings[#warnings+1]=key end
    end
    return options,warnings
end
function R.write(writer,options,key,value)
    assert(type(writer)=='function','EEex INI writer unavailable')
    options[key]=value
    writer(R.path,R.section,key,value and '1' or '0')
end
return R
