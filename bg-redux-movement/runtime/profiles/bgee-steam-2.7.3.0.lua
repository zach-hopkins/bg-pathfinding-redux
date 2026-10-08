-- BG1EE Steam 2.7.3.0 / SoD candidate: live acceptance pending.
-- BG Redux Movement: guarded native profile; public package 0.1.2-preview.
-- Fresh installs enable all four features; existing settings are preserved.
-- Generated from frozen52; persistent switches in bg-redux-movement.ini.
if MRIP_BaselineRevision then return end
MRIP_BaselineRevision = 56
MRIP_TraceEnabled = false
local release_config=(function()
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

end)()
local release_options,release_config_warnings=release_config.read(EEex.GetINIString)
MRIP_ReleaseOptions=release_options
local prefix = "[BG Redux]"
local run, event, active, started_ms = 0, 0, false, nil
local last_sample, last_summary = -1, -1
local previous_party = {}
local key_start, key_snapshot, key_end = EEex_Key_GetFromName("F7"), EEex_Key_GetFromName("F8"), EEex_Key_GetFromName("F9")
local key_preference=EEex_Key_GetFromName("F3")
local key_settle = EEex_Key_GetFromName("F4")
local key_attack = EEex_Key_GetFromName("F5")
local key_pass = EEex_Key_GetFromName("F6")
local key_ctrl, key_shift = EEex_Key_GetFromName("Left Ctrl"), EEex_Key_GetFromName("Left Shift")
local queue_size, stride, header_size = 4096, 128, 64
local buffer, base, route_context
local kinds = {"WALK_COST", "BUMP_ENTER", "BUMP_EXIT", "BUMP_CANDIDATE", "JUMP_ENTER_A", "JUMP_EXIT_A", "JUMP_ENTER_B", "JUMP_EXIT_B", "TARGET_ENTER", "TARGET_EXIT", "WALK_READY", "WORKER_SELECT", "WORKER_OVERRIDE", "BUMP_SKIP"}
local route_sites={0x2157A2,0x346900,0x346A97,0x34762A,0x347662,0x3A6651,0x3A6FDC}
local specs = {
    {name="serialized-search-worker", rva=0x24D5E0, bytes={64,85,65,86,72,141,172,36,8,112,254,255,184,248,144,1,0,232,122,167,42,0,72,43,224,72,139,5,216,115,65,0,72,51,196,72,137,133,208,143,1,0,72,139,5,55,159,65,0,69,51,246,15,87,192,68,137,116,36,104,243,15,127,69,184,68,137,117,144,72,139,136,144,16,0,0,68,57,177,16,148,0,0,117,13,68,57,177,72,148,0,0,15,132,60,15,0,0,72,137,156,36,16,145,1,0,72,139,93,168,72,137,180,36,24,145,1,0,139,177,108,148,0,0,72,137,188,36,32,145,1,0,76,137,164,36,240,144,1,0,76,137,172,36,232,144,1,0,76,137,188,36,224,144,1,0,137,116,36,96,72,137,92,36,112,73,199,199,255,255,255,255,15,31,64,0,72,139,5,177,158,65,0,72,139,136,144,16,0,0,131,185,16,148,0,0,0,117,20,131,185,72,148,0,0,0,15,132,154,14,0,0,184,48,148,0,0,235,5,184,248,147,0,0,72,3,200,232,40,163,27,0,72,139,248,128,56,4,117,79,72,133,192,116,187,72,139,72,72,72,133,201,116,5,232,173,15,33,0,72,139,79,80,72,133,201,116,5,232,159,15,33,0,72,139,79,88,72,133,201,116,5,232,145,15,33,0,72,139,79,120,72,133,201,116,5,232,131,15,33,0,186,128,0,0,0,72,139,207,232,118,15,33,0,233,113,255,255,255,133,246,116,8,198,0,5,233,101,255,255,255,128,120,16,0,117,33,72,139,5,16,158,65,0,72,139,136,144,16,0,0,131,185,16,148,0,0,0,117,10,199,129,104,148,0,0,1,0,0,0,131,127,4,0,198,7,1,72,139,5,232,157,65,0,72,139,136,144,16,0,0,117,14,72,139,145,152,102,0,0,139,71,48,137,2,235,10,72,139,129,152,102,0,0,68,137,48,15,182,71,11,15,182,87,10,72,3,208,184,8,0,0,0,131,127,4,0,116,84,72,247,226,73,15,64,199,72,139,200,232,30,160,42,0,15,182,79,10,76,139,224,72,255,193,232,15,160,42,0,15,182,79,10,76,139,232,72,137,69,168,72,255,193,184,4,0,0,0,72,247,225,73,15,64,199,72,139,200,232,237,159,42,0,15,182,79,10,76,139,240,72,255,193,184,8,0,0,0,72,247,225,235,110,15,182,79,9,72,3,202,72,247,225,73,15,64,199,72,139,200,232,195,159,42,0,15,182,79,10,76,139,224,15,182,71,9,72,255,192,72,3,200,232,173,159,42,0,15,182,79,10,76,139,232,15,182,87,9,72,255,193,72,137,69,168,72,3,209,184,4,0,0,0,72,247,226,73,15,64,199,72,139,200,232,132,159,42,0,15,182,79,10,76,139,240,15,182,87,9,72,255,193,72,3,209,184,8,0,0,0,72,247,226,73,15,64,199,76,137,117,128,72,139,200,232,91,159,42,0,72,137,69,176,76,139,248,77,133,228,15,132,83,12,0,0,77,133,237,15,132,66,12,0,0,77,133,246,15,132,57,12,0,0,72,133,192,15,132,48,12,0,0,131,127,4,0,117,91,15,182,79,9,232,33,159,42,0,72,137,68,36,112,72,139,216,72,133,192,117,69,73,139,204,232,216,13,33,0,73,139,205,232,208,13,33,0,73,139,206,232,200,13,33,0,73,139,207,232,192,13,33,0,128,63,4,15,133,224,11,0,0,72,133,255,15,132,130,11,0,0,141,83,1,72,139,207,232,99,234,255,255,69,51,246,233,144,253,255,255,15,182,71,11,132,192,116,28,72,139,87,88,73,139,204,68,15,182,192,73,193,224,3,232,255,205,42,0,199,68,36,104,1,0,0,0,139,79,56,72,141,84,36,88,232,218,141,2,0,132,192,15,133,62,11,0,0,131,127,12,0,116,19,72,139,76,36,88,72,139,1,255,80,120,133,192,15,132,37,11,0,0,72,139,71,24,76,139,68,36,88,72,139,136,64,1,0,0,73,57,72,24,15,133,11,11,0,0,73,139,88,12,15,182,13,148,214,52,0,139,195,153,247,249,15,182,13,137,214,52,0,68,139,208,137,68,36,120,72,139,195,72,193,232,32,153,247,249,137,68,36,124,68,139,200,69,133,210,120,12,15,191,13,104,214,52,0,68,59,209,126,8,51,246,137,116,36,120,235,2,51,246,69,133,201,120,12,15,191,5,81,214,52,0,68,59,200,126,4,137,116,36,124,73,139,64,24,73,139,200,72,137,69,136,139,71,112,137,68,36,108,73,139,0,255,80,8,58,5,65,189,52,0,117,84,72,139,76,36,88,246,129,72,60,0,0,4,116,14,15,182,177,80,60,0,0,64,136,116,36,80,235,25,72,139,137,64,60,0,0,72,139,1,255,144,192,0,0,0,72,139,76,36,88,136,68,36,80,139,177,44,73,0,0,72,139,17,137,117,152,255,82,32,15,182,13,188,244,51,0,51,246,56,72,8,118,15,235,9,50,192,137,117,152,136,68,36,80,137,116,36,108,128,127,10,0,15,183,206,102,137,76,36,100,15,134,66,2,0,0,68,139,246,102,102,15,31,132,0,0,0,0,0,72,139,71,80,72,141,84,36,88,72,15,191,241,139,12,176,232,139,140,2,0,132,192,116,66,72,139,71,80,72,199,194,255,255,255,255,137,20,176,15,182,71,11,65,3,198,72,152,65,137,20,196,15,182,71,11,65,3,198,72,152,65,137,84,196,4,72,139,69,128,66,198,4,46,1,199,4,176,0,0,0,0,73,137,20,247,233,182,1,0,0,72,139,76,36,88,72,139,1,255,80,120,133,192,15,132,102,1,0,0,72,139,76,36,88,72,139,69,136,72,59,65,24,15,133,83,1,0,0,72,139,1,255,80,8,72,139,76,36,88,58,5,45,188,52,0,72,139,1,117,13,72,141,85,160,255,80,48,72,139,69,160,235,47,255,80,8,58,5,14,188,52,0,117,23,72,139,76,36,88,72,141,85,144,72,137,93,144,232,143,215,244,255,72,139,0,235,9,72,139,68,36,88,72,139,64,12,72,137,69,160,15,182,79,11,65,3,206,72,99,201,73,137,4,204,15,182,13,184,212,52,0,15,182,71,11,65,3,198,72,152,77,141,4,196,65,139,4,196,153,247,249,65,137,0,15,182,71,11,15,182,13,151,212,52,0,65,3,198,72,152,77,141,4,196,65,139,68,196,4,153,247,249,65,137,64,4,72,139,76,36,88,72,139,1,255,80,8,58,5,143,187,52,0,117,117,72,139,76,36,88,246,129,72,60,0,0,4,116,9,15,182,129,80,60,0,0,235,16,72,139,137,64,60,0,0,72,139,1,255,144,192,0,0,0,66,136,4,46,77,141,4,247,72,139,68,36,88,139,136,44,73,0,0,72,139,69,128,137,12,176,72,139,68,36,88,15,182,13,33,212,52,0,139,64,12,153,247,249,65,137,0,72,139,68,36,88,15,182,13,13,212,52,0,139,64,16,153,247,249,65,137,64,4,199,69,144,1,0,0,0,235,106,72,139,69,128,77,141,4,247,66,198,4,46,0,199,4,176,0,0,0,0,184,255,255,255,255,65,199,0,255,255,255,255,65,137,64,4,199,69,144,1,0,0,0,235,61,72,139,71,80,72,199,193,255,255,255,255,137,12,176,15,182,71,11,65,3,198,72,152,65,137,12,196,15,182,71,11,65,3,198,72,152,65,137,76,196,4,72,139,69,128,66,198,4,46,1,199,4,176,0,0,0,0,73,137,12,247,15,183,76,36,100,15,182,71,10,102,255,193,68,15,191,241,102,137,76,36,100,68,59,240,15,140,209,253,255,255,76,139,117,128,51,246,131,124,36,104,0,117,100,131,125,144,0,117,94,131,127,4,0,72,139,92,36,112,117,8,72,139,203,232,219,9,33,0,73,139,204,232,211,9,33,0,73,139,205,232,203,9,33,0,73,139,206,232,195,9,33,0,73,139,207,232,187,9,33,0,128,63,4,15,133,52,6,0,0,72,133,255,15,132,121,7,0,0,186,1,0,0,0,72,139,207,232,92,230,255,255,139,116,36,96,69,51,246,233,133,249,255,255,131,127,4,0,15,133,76,2,0,0,128,127,9,0,15,134,66,2,0,0,51,192,139,216,15,31,132,0,0,0,0,0,72,139,71,72,72,141,84,36,88,72,15,191,206,139,12,136,232,203,137,2,0,132,192,15,133,155,1,0,0,72,139,76,36,88,72,139,1,255,80,120,133,192,15,132,136,1,0,0,72,139,84,36,88,72,139,69,136,72,59,66,24,15,133,117,1,0,0,15,182,71,10,15,182,79,11,3,195,3,200,72,139,66,12,72,99,201,73,137,4,204,15,182,79,11,15,182,71,10,3,195,3,193,15,182,13,115,210,52,0,72,152,77,141,4,196,65,139,4,196,153,247,249,65,137,0,15,182,79,11,15,182,71,10,3,195,3,193,15,182,13,81,210,52,0,72,152,77,141,4,196,65,139,68,196,4,153,247,249,65,137,64,4,72,139,76,36,88,72,139,1,255,80,8,58,5,76,185,52,0,15,133,178,0,0,0,72,139,76,36,88,246,129,72,60,0,0,4,116,9,15,182,129,80,60,0,0,235,16,72,139,137,64,60,0,0,72,139,1,255,144,192,0,0,0,15,182,79,10,3,203,76,15,191,198,72,99,201,66,136,4,41,15,182,71,10,3,195,72,99,208,72,139,68,36,88,139,136,44,73,0,0,65,137,12,150,15,182,13,208,209,52,0,72,139,68,36,88,139,64,12,153,247,249,67,137,4,199,15,182,13,187,209,52,0,72,139,68,36,88,139,64,16,153,247,249,67,137,68,199,4,72,139,76,36,88,15,182,5,116,240,53,0,102,57,129,16,71,0,0,116,16,15,183,5,166,234,51,0,102,57,129,248,3,0,0,117,80,72,139,76,36,112,176,1,66,136,4,1,233,185,0,0,0,15,182,71,10,51,201,3,195,76,15,191,198,72,152,66,198,4,40,0,15,182,71,10,3,195,72,152,65,137,12,134,15,182,71,10,3,195,72,152,65,199,4,199,255,255,255,255,15,182,71,10,3,195,72,152,65,199,68,199,4,255,255,255,255,72,139,76,36,112,50,192,66,136,4,1,235,108,72,139,71,72,72,199,194,255,255,255,255,76,15,191,198,66,137,20,128,15,182,71,10,15,182,79,11,3,195,3,193,72,152,65,137,20,196,15,182,71,10,15,182,79,11,3,195,3,193,51,201,72,152,65,137,84,196,4,15,182,71,10,3,195,72,152,66,198,4,40,1,15,182,71,10,3,195,72,152,65,137,12,134,15,182,71,10,3,195,72,152,65,137,20,199,15,182,71,10,3,195,72,152,65,137,84,199,4,15,182,71,9,102,255,198,15,191,222,59,216,15,140,202,253,255,255,72,139,71,24,15,182,116,36,80,139,136,56,1,0,0,255,201,137,77,192,72,139,71,24,139,136,60,1,0,0,72,141,71,32,255,201,137,77,196,72,139,87,24,15,182,79,8,72,137,130,48,1,0,0,72,141,69,208,72,137,130,40,1,0,0,139,130,60,1,0,0,15,175,130,56,1,0,0,136,138,72,1,0,0,72,141,77,208,64,136,178,73,1,0,0,72,139,146,32,1,0,0,76,99,192,232,76,199,42,0,72,139,69,136,199,128,0,5,0,0,1,0,0,0,51,192,15,183,216,56,71,10,118,54,15,31,64,0,72,139,71,80,72,15,191,211,131,60,144,255,116,22,69,139,12,150,70,15,182,4,42,73,139,20,215,72,139,79,24,232,252,8,0,0,15,182,79,10,102,255,195,102,59,217,124,208,51,192,131,127,4,0,117,104,128,127,9,0,15,183,216,118,95,72,139,116,36,112,68,139,192,15,31,128,0,0,0,0,72,139,71,72,72,15,191,203,139,20,136,131,250,255,116,43,128,60,49,0,116,37,59,87,56,116,32,15,182,71,10,72,139,79,24,65,3,192,72,99,208,69,139,12,150,70,15,182,4,42,73,139,20,215,232,149,8,0,0,15,182,71,9,102,255,195,68,15,191,195,68,59,192,124,181,15,182,116,36,80,131,127,12,0,15,132,108,1,0,0,68,139,77,152,68,15,182,198,72,139,84,36,120,72,139,79,24,232,96,8,0,0,131,127,4,0,15,132,76,1,0,0,68,139,92,36,120,72,139,76,36,120,76,139,87,24,69,133,219,15,136,53,1,0,0,76,139,193,73,193,232,32,69,133,192,15,136,37,1,0,0,65,129,251,64,1,0,0,15,141,24,1,0,0,65,129,248,64,1,0,0,15,141,11,1,0,0,64,15,182,198,255,200,153,43,194,209,248,68,15,182,200,69,59,217,120,125,69,59,193,120,56,65,139,130,56,1,0,0,69,139,195,69,43,193,72,139,209,72,193,234,32,65,43,209,15,175,194,65,3,192,76,99,192,77,3,130,40,1,0,0,65,15,182,0,141,80,16,50,208,128,226,112,50,208,65,136,16,76,139,193,73,193,232,32,69,3,193,69,59,130,60,1,0,0,125,45,65,139,130,56,1,0,0,139,209,65,15,175,192,65,43,209,3,194,76,99,192,77,3,130,40,1,0,0,65,15,182,0,141,80,16,50,208,128,226,112,50,208,65,136,16,65,139,146,56,1,0,0,67,141,4,11,59,194,125,107,76,139,217,73,193,235,32,69,139,195,69,43,193,120,37,65,15,175,208,66,141,4,9,3,208,76,99,194,77,3,130,40,1,0,0,65,15,182,0,141,80,16,50,208,128,226,112,50,208,65,136,16,67,141,20,11,65,59,146,60,1,0,0,125,42,65,15,175,146,56,1,0,0,66,141,4,9,3,208,72,99,202,73,139,146,40,1,0,0,72,3,209,15,182,2,141,72,16,50,200,128,225,112,50,200,136,10,15,182,79,11,69,51,192,65,139,208,65,15,183,240,137,84,36,104,132,201,15,132,181,0,0,0,76,139,117,136,68,139,124,36,108,15,31,128,0,0,0,0,72,15,191,198,73,141,28,196,65,139,4,196,131,248,255,116,113,68,139,67,4,65,131,248,255,116,103,131,127,52,0,116,13,133,210,116,9,72,199,3,255,255,255,255,235,84,15,182,13,171,205,52,0,153,247,249,69,139,207,137,3,65,139,192,15,182,13,154,205,52,0,153,247,249,76,139,195,73,139,206,137,67,4,184,10,0,0,0,72,139,84,36,120,102,137,68,36,32,232,105,206,243,255,131,248,1,116,13,139,84,36,104,72,199,3,255,255,255,255,235,9,186,1,0,0,0,137,84,36,104,15,182,79,11,102,255,198,102,59,241,15,140,110,255,255,255,76,139,125,176,76,139,109,168,76,139,117,128,133,210,117,95,69,51,192,131,125,144,0,117,86,72,139,69,136,72,139,92,36,112,68,137,128,0,5,0,0,131,127,4,0,117,8,72,139,203,232,167,3,33,0,73,139,204,232,159,3,33,0,73,139,205,232,151,3,33,0,73,139,206,232,143,3,33,0,73,139,207,232,135,3,33,0,128,63,4,15,132,235,0,0,0,139,116,36,96,69,51,246,198,7,2,233,100,243,255,255,15,182,71,10,68,15,182,201,102,68,3,200,72,139,5,20,146,65,0,128,127,16,0,72,139,136,144,16,0,0,72,139,137,152,102,0,0,117,15,68,139,71,96,72,141,84,36,120,68,139,87,100,235,12,68,139,71,104,72,141,87,60,68,139,87,108,72,141,69,184,72,137,68,36,72,139,68,36,108,137,68,36,64,72,139,71,24,72,137,124,36,56,72,137,68,36,48,68,137,84,36,40,68,137,68,36,32,77,139,196,232,28,117,253,255,72,139,92,36,112,51,201,102,137,71,116,72,139,69,136,137,136,0,5,0,0,57,79,4,117,8,72,139,203,232,218,2,33,0,73,139,204,232,210,2,33,0,73,139,205,232,202,2,33,0,73,139,206,232,194,2,33,0,73,139,207,232,186,2,33,0,72,139,5,107,145,65,0,72,141,87,118,72,139,136,144,16,0,0,72,139,137,152,102,0,0,232,204,123,253,255,128,63,4,72,137,71,120,117,86,72,133,255,116,94,72,139,79,72,72,133,201,116,5,232,128,2,33,0,72,139,79,80,72,133,201,116,5,232,114,2,33,0,72,139,79,88,72,133,201,116,5,232,100,2,33,0,72,139,79,120,72,133,201,116,5,232,86,2,33,0,186,128,0,0,0,72,139,207,232,73,2,33,0,139,116,36,96,69,51,246,233,50,242,255,255,198,7,3,102,102,15,31,132,0,0,0,0,0,139,116,36,96,69,51,246,233,25,242,255,255,131,127,4,0,117,8,72,139,203,232,22,2,33,0,73,139,204,232,14,2,33,0,73,139,205,232,6,2,33,0,73,139,206,232,254,1,33,0,73,139,207,232,246,1,33,0,128,63,4,117,26,72,133,255,116,192,186,1,0,0,0,72,139,207,232,159,222,255,255,69,51,246,233,204,241,255,255,198,7,5,69,51,246,233,193,241,255,255,73,139,204,232,196,1,33,0,77,133,237,116,8,73,139,205,232,183,1,33,0,77,133,246,116,8,73,139,206,232,170,1,33,0,77,133,255,116,8,73,139,207,232,157,1,33,0,128,63,4,117,193,72,133,255,15,132,99,255,255,255,72,139,79,72,72,133,201,116,5,232,129,1,33,0,72,139,79,80,72,133,201,116,5,232,115,1,33,0,72,139,79,88,72,133,201,116,5,232,101,1,33,0,72,139,79,120,72,133,201,116,5,232,87,1,33,0,186,128,0,0,0,72,139,207,232,74,1,33,0,69,51,246,233,55,241,255,255,76,139,172,36,232,144,1,0,76,139,164,36,240,144,1,0,72,139,188,36,32,145,1,0,72,139,180,36,24,145,1,0,72,139,156,36,16,145,1,0,76,139,188,36,224,144,1,0,72,139,141,208,143,1,0,72,51,204,232,19,146,42,0,72,129,196,248,144,1,0,65,94,93,195,204,204,204,204,204,204,204,204}},
    {name="serialized-search-caller", rva=0x41CBAF, bytes={232,44,10,227,255}},
    {name="attack-approach", rva=0x38955B, bytes={76,141,123,12,76,141,118,12,72,139,214,72,139,203,232,2,199,1,0}},
    {name="attack-reevaluate-approach", rva=0x389F33, bytes={72,139,211,72,139,206,232,50,189,1,0}},
    {name="attack-range-arithmetic", rva=0x3893E8, bytes={15,182,200,255,201,65,15,182,199,255,200,209,249,209,248,255,200,3,193,15,182,208,65,15,191,198,3,208,139,194,15,175,194}},
    {name="attack-count-squares", rva=0x130900, bytes={68,139,9,69,139,209,68,139,2,69,43,208,139,82,4,65,139,192,65,43,193,69,59,200,68,139,65,4,139,202,69,139,200,68,15,78,208,65,43,200,68,43,202,68,59,194,68,15,78,201,69,59,209,69,15,78,209,65,139,194,195}},
    {name="attack-move-point", rva=0x3A6330, bytes={72,137,92,36,16,87,72,131,236,32,68,139,18,72,139,250,68,15,182,13,184,76,31,0,65,139,194,153,72,139,217,65,247,249,68,139,192,139,65,12,153,65,247,249,68,59,192,117,46,68,15,182,5,152,76,31,0,139,71,4,153,65,247,248,139,200,139,67,16,153,65,247,248,59,200,117,18,15,183,5,236,145,30,0,72,139,92,36,56,72,131,196,32,95,195,69,133,210,15,136,151,1,0,0,72,139,83,24,15,191,130,120,6,0,0,68,59,208,15,143,131,1,0,0,139,79,4,133,201,15,136,120,1,0,0,15,191,130,124,6,0,0,59,200,15,143,105,1,0,0,72,139,139,64,60,0,0,186,0,240,0,0,15,183,65,8,102,35,194,186,0,48,0,0,102,59,194,117,55,72,139,1,255,144,152,1,0,0,133,192,116,26,72,139,203,232,168,20,254,255,15,183,5,117,145,30,0,72,139,92,36,56,72,131,196,32,95,195,15,182,5,186,106,32,0,102,57,131,16,71,0,0,116,222,72,131,187,88,71,0,0,0,117,39,72,131,187,240,71,0,0,0,117,29,102,131,187,158,73,0,0,0,126,19,15,191,5,253,103,30,0,57,131,72,4,0,0,15,132,228,0,0,0,72,139,131,168,74,0,0,57,7,117,9,72,193,232,32,57,71,4,116,153,72,139,7,185,128,0,0,0,72,137,131,168,74,0,0,232,21,22,21,0,72,133,192,15,132,179,0,0,0,72,139,200,232,156,93,234,255,72,139,248,72,133,192,15,132,159,0,0,0,72,139,75,24,72,129,193,96,10,0,0,72,137,72,24,72,139,139,64,60,0,0,72,139,17,255,82,120,58,5,119,50,31,0,117,9,15,16,131,41,60,0,0,235,7,15,16,131,9,60,0,0,15,17,71,32,72,139,139,64,60,0,0,72,139,1,255,80,120,51,201,58,5,76,50,31,0,15,149,193,137,79,12,72,139,139,64,60,0,0,72,139,1,255,144,184,0,0,0,137,71,48,185,8,0,0,0,139,67,72,137,71,56,198,71,11,1,199,71,52,1,0,0,0,232,179,18,21,0,72,137,71,88,72,133,192,117,39,72,139,207,232,222,93,234,255,186,128,0,0,0,72,139,207,232,97,129,11,0,15,183,5,70,144,30,0,72,139,92,36,56,72,131,196,32,95,195,72,139,67,24,139,83,72,72,139,136,40,2,0,0,72,129,193,176,102,0,0,232,69,70,215,255,133,192,116,48,72,139,67,24,72,139,136,40,2,0,0,15,182,129,208,102,0,0,136,71,9,72,139,67,24,72,139,136,40,2,0,0,72,129,193,176,102,0,0,232,85,21,215,255,72,137,71,72,72,139,131,168,74,0,0,72,139,79,88,72,137,1,15,182,67,56,136,71,8,72,139,5,157,15,44,0,139,83,72,72,139,136,144,16,0,0,232,182,255,236,255,102,131,248,255,117,26,72,139,67,24,72,133,192,116,17,139,128,176,16,0,0,137,71,100,57,71,96,126,3,137,71,96,15,191,5,91,102,30,0,57,131,72,4,0,0,117,87,15,182,5,72,129,31,0,136,71,16,76,139,67,12,15,182,13,2,74,31,0,65,139,192,153,73,193,232,32,247,249,15,182,13,242,73,31,0,137,68,36,48,65,139,192,153,199,71,104,110,0,0,0,247,249,137,68,36,52,72,139,68,36,48,72,137,71,60,139,5,149,78,43,0,137,71,108,68,15,182,13,250,128,31,0,235,8,68,15,182,13,238,128,31,0,69,51,192,72,139,215,72,139,203,232,90,246,252,255,15,183,5,23,143,30,0,72,139,92,36,56,72,131,196,32,95,195}},
    {name="attack-stop-path", rva=0x389472, bytes={72,57,187,88,71,0,0,116,64}},
    {name="attack-reevaluate-stop-path", rva=0x389D84, bytes={76,57,182,88,71,0,0,116,64}},
    {name="attack-reevaluate-range", rva=0x389D07, bytes={15,182,200,255,201,65,15,182,199,255,200,209,249,209,248,255,200,3,193,15,182,208,15,191,199,3,208,139,194,15,175,194}},
    {name="attack-reevaluate-out-of-range", rva=0x389E48, bytes={139,134,72,4,0,0,72,141,85,167,102,255,134,164,76,0,0,72,141,77,175,137,69}},
    {name="worker-get-share", rva=0x276700, bytes={72,199,2,0,0,0,0,131,249,255,116,73,139,193,65,184,255,127,0,0,193,248,16,102,65,35,192,102,57,5,210,145,65,0,124,49,102,133,201,120,44,102,57,13,200,145,65,0,126,35,15,183,192,76,141,5,212,145,65,0,72,193,224,4,102,66,57,12,0,116,3,176,2,195,74,139,68,0,8,72,137,2,50,192,195,176,3,195}},
    {name="worker-active-stats", rva=0x161920, bytes={131,185,164,78,0,0,0,72,141,129,32,17,0,0,117,7,72,141,129,200,29,0,0,195}},
    {name="worker-portrait-index", rva=0x276570, bytes={131,250,255,116,34,51,192,102,15,31,132,0,0,0,0,0,76,15,191,192,66,57,148,129,24,102,0,0,116,14,102,255,192,102,131,248,6,124,233,184,255,255,255,255,195}},
    {name="worker-ai-type", rva=0x161910, bytes={72,141,65,48,195}},
    {name="worker-object-type", rva=0x162120, bytes={15,182,65,8,195}},
    {name="worker-captured-footprint", rva=0x24DDD9, bytes={72,139,76,36,88,246,129,72,60,0,0,4,116,9,15,182,129,80,60,0,0,235,16,72,139,137,64,60,0,0,72,139,1,255,144,192,0,0,0,15,182,79,10,3,203,76,15,191,198,72,99,201,66,136,4,41,15,182,71,10,3,195,72,99,208,72,139,68,36,88,139,136,44,73,0,0,65,137,12,150,15,182,13,208,209,52,0,72,139,68,36,88,139,64,12,153,247,249,67,137,4,199,15,182,13,187,209,52,0,72,139,68,36,88,139,64,16,153,247,249,67,137,68,199,4,72,139,76,36,88,15,182,5,116,240,53,0,102,57,129,16,71,0,0,116,16,15,183,5,166,234,51,0,102,57,129,248,3,0,0,117,80,72,139,76,36,112,176,1,66,136,4,1,233,185,0,0,0,15,182,71,10,51,201,3,195,76,15,191,198,72,152,66,198,4,40,0,15,182,71,10,3,195,72,152,65,137,12,134,15,182,71,10,3,195,72,152,65,199,4,199,255,255,255,255,15,182,71,10,3,195,72,152,65,199,68,199,4,255,255,255,255,72,139,76,36,112,50,192,66,136,4,1,235,108,72,139,71}},
    {name="worker-sprite-type", rva=0x59971F, bytes={49}},
    {name="worker-selected-remove", rva=0x24DE7B, bytes={72,139,76,36,112,176,1,66,136,4,1}},
    {name="worker-selected-keep", rva=0x24DECB, bytes={72,139,76,36,112,50,192,66,136,4,1}},
    {name="walk-readiness", rva=0x3467F2, bytes={76,139,137,88,71,0,0}},
    {name="moving-wait-test", rva=0x3473A3, bytes={65,3,200,72,99,209,246,4,2,112,116,91,72,139,5,146,1,50,0}},
    {name="route-context-215542", rva=0x2157A2, bytes={232,9,5,22,0}, target=0x375CB0},
    {name="route-context-3462C0", rva=0x346900, bytes={232,171,243,2,0}, target=0x375CB0},
    {name="route-context-346457", rva=0x346A97, bytes={232,20,242,2,0}, target=0x375CB0},
    {name="route-context-346FEA", rva=0x34762A, bytes={232,129,230,2,0}, target=0x375CB0},
    {name="route-context-347022", rva=0x347662, bytes={232,73,230,2,0}, target=0x375CB0},
    {name="route-context-3A6011", rva=0x3A6651, bytes={232,90,246,252,255}, target=0x375CB0},
    {name="route-context-3A699C", rva=0x3A6FDC, bytes={232,207,236,252,255}, target=0x375CB0},
    {name="route-cost-cell", rva=0x24C880, bytes={15,182,20,1,132,210}},
    {name="bump-next-candidate", rva=0x34F6B4, bytes={72,139,77,208,72,133,201}},
    {name="walk-cost", rva=0x34744B, bytes={232,128,85,240,255}, target=0x24C9D0},
    {name="walk-bump", rva=0x347463, bytes={232,104,125,0,0}, target=0x34F1D0},
    {name="resolved-candidate", rva=0x34F5A3, bytes={65,131,189,44,73,0,0,0}},
    {name="jump-a", rva=0x34FAAD, bytes={232,94,14,5,0}, target=0x3A0910},
    {name="jump-b", rva=0x34FBCF, bytes={232,60,13,5,0}, target=0x3A0910},
    {name="world-tick", rva=0x2FCBC0, bytes={72,137,92,36,8}},
}
local function clock() return type(Infinity_GetClockTicks)=="function" and Infinity_GetClockTicks() or nil end
local function u32(value) return value<0 and value+0x100000000 or value end
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
local support_context=(function()
-- Read-only context, emitted only by explicitly requested snapshots/captures.
local S={}
local function safe(callback)
    local ok,value=pcall(callback)
    if not ok or value==nil then return 'unavailable' end
    return tostring(value):gsub('[%c]',' '):sub(1,256)
end
function S.header()
    local status=MRIP_CompatibilityStatus or {}
    return 'package='..tostring(MRIP_PackageVersion or 'unavailable')
        ..' profile='..tostring(status.profile or 'unavailable')
        ..' revision='..tostring(MRIP_BaselineRevision or 'unavailable')
        ..' paused='..safe(function()return worldScreen:CheckIfPaused()end)
end
function S.party(sprite)
    local area=safe(function()return sprite.m_pArea.m_resref:get()end)
    local creature=safe(function()return sprite.m_resref:get()end)
    local queued=safe(function()
        assert(type(EEex_Utility_IterateCPtrList)=='function' and sprite.m_queuedActions)
        local count=0
        EEex_Utility_IterateCPtrList(sprite.m_queuedActions,function()
            count=count+1;return count>=64
        end)
        return count>=64 and '64-or-more' or count
    end)
    return string.format('area=%q creature=%q queued=%s',area,creature,queued)
end
return S

end)()
local function describe(sprite)
    local action=sprite.m_curAction
    local dest=action and action.m_dest
    return string.format("slot=%d id=%d name=%q pos=%d,%d ea=%d personal=%d state=0x%X base_state=0x%X action=%d dest=%d,%d", sprite:getPortraitIndex(),sprite.m_id,tostring(sprite:getName()),sprite.m_pos.x,sprite.m_pos.y,sprite.m_typeAI.m_EnemyAlly,sprite:getPersonalSpace(),sprite:getState(),sprite.m_baseStats.m_generalState,action and action.m_actionID or -1,dest and dest.x or -1,dest and dest.y or -1)
end
local function snapshot(label)
    log("SNAPSHOT "..label)
    log("SUPPORT_CONTEXT "..support_context.header())
    for slot=0,5 do
        local sprite=EEex_Sprite_GetInPortrait(slot)
        if sprite then
            local ok,result=pcall(function()return describe(sprite).." "..support_context.party(sprite)end)
            log((ok and "PARTY " or "ERROR snapshot ")..tostring(result))
        end
    end
end

-- Header: enabled, writer lock, published/consumed sequence, busy/full drops,
-- run, preceding UI clock, six party IDs. Native writers never call Lua or wait.
-- Producer publishes only complete records; consumer releases slots after reading.
local function recorder(kind,site,mover,other,target,point2,result,mover_setup)
    local label=string.format("mrip_%d_%X_",kind,site)
    local body=[[
        pushfq
        push rax
        push rcx
        push rdx
        push r8
        push r9
        push r10
        push r11
        mov r10, #L(MRIP_ring)
        cmp dword ptr ds:[r10], 1
        jne @exit
        xor eax, eax
        mov r11d, 1
        lock cmpxchg dword ptr ds:[r10+4], r11d
        jne @busy
        cmp dword ptr ds:[r10], 1
        jne @unlock
        @mover_setup
        mov r9, @other
        test r8, r8
        jz @unlock
        @party_id
    ]]
    for offset=32,52,4 do body=body..string.format("cmp eax, dword ptr ds:[r10+%d] #ENDL je @party #ENDL ",offset) end
    body=body..[[
        jmp @unlock
        @party:
        mov eax, dword ptr ds:[r10+8]
        mov ecx, eax
        sub ecx, dword ptr ds:[r10+12]
        cmp ecx, 4096
        jae @full
        and eax, 4095
        shl rax, 7
        lea r11, qword ptr ds:[r10+rax+64]
        mov dword ptr ds:[r11], @kind
        mov eax, dword ptr ds:[r10+24]
        mov dword ptr ds:[r11+4], eax
        mov eax, dword ptr ds:[r10+28]
        mov dword ptr ds:[r11+8], eax
        mov dword ptr ds:[r11+12], @site
        mov eax, dword ptr ds:[r8+48h]
        mov dword ptr ds:[r11+16], eax
        mov rax, qword ptr ds:[r8+0Ch]
        mov qword ptr ds:[r11+24], rax
        mov qword ptr ds:[r11+64], r8
        mov qword ptr ds:[r11+72], r9
        mov dword ptr ds:[r11+20], -1
        mov dword ptr ds:[r11+32], -1
        mov dword ptr ds:[r11+36], -1
        test r9, r9
        jz @no_other
        mov eax, dword ptr ds:[r9+48h]
        mov dword ptr ds:[r11+20], eax
        mov rax, qword ptr ds:[r9+0Ch]
        mov qword ptr ds:[r11+32], rax
        @no_other:
        @result
        mov dword ptr ds:[r11+40], eax
        mov dword ptr ds:[r11+44], -1
        @target
        mov qword ptr ds:[r11+48], rax
        @point2
        mov qword ptr ds:[r11+56], rax
        mov eax, dword ptr ds:[r8+492Ch]
        mov dword ptr ds:[r11+84], eax
        mov eax, dword ptr ds:[r8+493Ch]
        mov dword ptr ds:[r11+88], eax
        movzx eax, byte ptr ds:[r8+4930h]
        mov dword ptr ds:[r11+92], eax
        mov rax, qword ptr ds:[r8+4934h]
        mov qword ptr ds:[r11+96], rax
        @request_fields
        mov eax, dword ptr ds:[r10+8]
        mov dword ptr ds:[r11+80], eax
        inc eax
        mov dword ptr ds:[r10+8], eax
        jmp @unlock
        @full:
        inc dword ptr ds:[r10+20]
        @unlock:
        mov dword ptr ds:[r10+4], 0
        jmp @exit
        @busy:
        lock inc dword ptr ds:[r10+16]
        @exit:
        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rax
        popfq
    ]]
    local values={party_id=(kind==12 or kind==13) and "mov eax, dword ptr ds:[rdi+38h]" or "mov eax, dword ptr ds:[r8+48h]",mover_setup=mover_setup or "mov r8, "..mover,other=other or "0",kind=tostring(kind),site=string.format("0%Xh",site),result=result or "mov eax, -1",target=target or "mov rax, -1",point2=point2 or "mov rax, -1"}
    values.request_fields=kind>=9 and kind<=13 and [[
        mov rax, qword ptr ds:[r8+4758h]
        mov qword ptr ds:[r11+104], rax
        mov rax, qword ptr ds:[r8+47F0h]
        mov qword ptr ds:[r11+112], rax
        test rax, rax
        jz @no_request
        movzx ecx, word ptr ds:[rax]
        mov dword ptr ds:[r11+44], ecx
        mov ecx, dword ptr ds:[rax+4]
        mov dword ptr ds:[r11+56], ecx
        mov ecx, dword ptr ds:[rax+8]
        shr ecx, 8
        mov dword ptr ds:[r11+60], ecx
        cmp byte ptr ds:[rax], 3
        jne @no_request
        movzx ecx, word ptr ds:[rax+74h]
        mov dword ptr ds:[r11+48], ecx
        movzx ecx, word ptr ds:[rax+76h]
        mov dword ptr ds:[r11+52], ecx
        @no_request:
        movsx eax, word ptr ds:[r8+4760h]
        mov dword ptr ds:[r11+120], eax
        movzx eax, word ptr ds:[r8+47D8h]
        mov dword ptr ds:[r11+124], eax
    ]] or ""
    if kind==12 or kind==13 then values.request_fields=[[
        mov eax, dword ptr ds:[rdi+38h]
        mov dword ptr ds:[r11+20], eax
        mov qword ptr ds:[r11+112], rdi
        mov rax, qword ptr ds:[rdi+18h]
        mov qword ptr ds:[r11+104], rax
        movzx eax, word ptr ds:[rdi]
        mov dword ptr ds:[r11+44], eax
        movzx eax, word ptr ds:[r8+3F8h]
        mov dword ptr ds:[r11+48], eax
        movzx eax, word ptr ds:[r8+4710h]
        mov dword ptr ds:[r11+52], eax
        movsx eax, si
        mov dword ptr ds:[r11+56], eax
        movzx eax, byte ptr ds:[rdi+9]
        mov dword ptr ds:[r11+60], eax
        mov dword ptr ds:[r11+120], 0
        movzx eax, word ptr ds:[rdi+0Ah]
        mov dword ptr ds:[r11+124], eax
    ]] end
    -- Expand placeholders inside the injected fragment before the outer pass.
    values.request_fields=values.request_fields:gsub("@([%w_]+)",function(key) return label..key end)
    values.mover_setup=values.mover_setup:gsub("@([%w_]+)",function(key) return label..key end)
    body=body:gsub("@([%w_]+)",function(key) return values[key] or label..key end)
    return {body}
end
-- Revision 22: observe owned request shapes, results and selected-actor decisions.
-- All reads use the current sprite's owned fields. Never retain or dereference
-- an incoming request after SetTarget, which can free it on its direct-path arm.
local function request_recorder(kind,site)
    return recorder(kind,site,nil,nil,nil,nil,nil,[[
        mov rax, #L(MRIP_route_context)
        mov r8, qword ptr gs:[48h]
        cmp qword ptr ds:[rax], r8
        jne @unlock
        mov r8, qword ptr ds:[rax+8]
    ]])
end
local function request_drain(p,kind)
    if kind<9 or kind>13 then return "" end
    local packed=EEex_Read32(p+44)
    local status=packed==-1 and -1 or packed%256
    local delay=packed==-1 and -1 or math.floor(packed/256)%256
    if kind==12 or kind==13 then
        local auxiliary=EEex_Read32(p+124)
        return string.format(" worker_actor=%d worker_job_mover=%d worker_selected_remove=%d worker_request_ptr=%X worker_bitmap_ptr=%X worker_status=%d worker_actor_action=%d worker_actor_sequence=%d worker_selected_index=%d worker_selected_count=%d worker_aux_count=%d worker_aux2_count=%d",
            EEex_Read32(p+16),EEex_Read32(p+20),EEex_Read32(p+40),EEex_ReadPtr(p+112),EEex_ReadPtr(p+104),status,
            EEex_Read32(p+48),EEex_Read32(p+52),EEex_Read32(p+56),EEex_Read32(p+60),auxiliary%256,math.floor(auxiliary/256)%256)
    end
    local counts=EEex_Read32(p+60)
    return string.format(" path_ptr=%X request_ptr=%X request_status=%d request_delay=%d path_length=%d path_cursor=%d result_return=%d result_count=%d request_type=%d request_selected_count=%d request_aux_count=%d request_point_count=%d",
        EEex_ReadPtr(p+104),EEex_ReadPtr(p+112),status,delay,EEex_Read32(p+120),EEex_Read32(p+124),EEex_Read32(p+48),EEex_Read32(p+52),
        EEex_Read32(p+56),counts==-1 and -1 or counts%256,counts==-1 and -1 or math.floor(counts/256)%256,counts==-1 and -1 or math.floor(counts/65536)%256)
end

local function drain()
    if not buffer then return end
    local read,published=u32(EEex_Read32(buffer+12)),u32(EEex_Read32(buffer+8))
    for seq=read,math.min(published,read+queue_size)-1 do
        local p=buffer+header_size+(seq%queue_size)*stride
        local function field(offset) return EEex_Read32(p+offset) end
        log(string.format("NATIVE seq=%d capture_generation=%d ui_clock_sample_ms=%d kind=%s site=0x%X mover=%d other=%d pos=%d,%d other_pos=%d,%d raw_result=%d target=%d,%d point2=%d,%d move_field=%d busy_field=%d bump_state=%d return_point=%d,%d",seq,field(4),u32(field(8)),kinds[field(0)] or "UNKNOWN",u32(field(12)),field(16),field(20),field(24),field(28),field(32),field(36),field(40),field(48),field(52),field(56),field(60),field(84),field(88),field(92),field(96),field(100))..request_drain(p,field(0)))
        EEex_Write32(buffer+12,seq+1)
    end
end
local function summary()
    log(string.format("TRACE_SUMMARY published=%d consumed=%d dropped_busy=%d dropped_full=%d",u32(EEex_Read32(buffer+8)),u32(EEex_Read32(buffer+12)),u32(EEex_Read32(buffer+16)),u32(EEex_Read32(buffer+20))))
end
local pass_policy = (function()
-- Allies pass through allies regardless of action or movement status.
-- Pure decision code; never writes actor data or search-map bytes.
local P = {}
-- Pinned EA.IDS: PC2 through GOODCUTOFF30; NEUTRAL128 is not allied.
function P.ally(ea) return ea>=2 and ea<=30 end
local function allied(a)
    return P.ally(a.ea) and a.personal >= 0 and a.personal <= 255 and a.x >= 0 and a.y >= 0
end
function P.mover_eligible(a)
    return allied(a) and a.personal == 3 and a.painted == 0 and a.removed == 1
end
function P.mover_evidence(a)
    return string.format("mover_id=%d party=%s ea=%d state=0x%X base_state=0x%X personal=%d action=%d category=%d busy=%d bump=%d painted=%d removed=%d pos=%d,%d",
        a.id,tostring(a.party),a.ea,a.state,a.base_state,a.personal,a.action,
        a.category,a.busy,a.bump,a.painted,a.removed,a.x,a.y)
end
local function eligible_ally(a)
    return allied(a) and a.painted == 1 and a.removed == 0
end
local function rejected_actor(a,dx,dy,envelope)
    local failed={}
    for _,check in ipairs({
        {"ea",P.ally(a.ea)},{"personal",a.personal>=1 and a.personal<=255},
        {"position",a.x>=0 and a.y>=0},{"painted",a.painted==1},{"removed",a.removed==0},
    }) do
        if not check[2] then failed[#failed+1]=check[1] end
    end
    return string.format("rejected_id=%d party=%s ea=%d state=0x%X base_state=0x%X personal=%d action=%d category=%d busy=%d bump=%d painted=%d removed=%d pos=%d,%d dx=%d dy=%d envelope=%d rejected_fields=%s",
        a.id,tostring(a.party),a.ea,a.state,a.base_state,a.personal,a.action,
        a.category,a.busy,a.bump,a.painted,a.removed,a.x,a.y,dx,dy,envelope,table.concat(failed,","))
end
function P.evaluate(q)
    local m = q.mover
    if not P.mover_eligible(m) then
        return false, "mover-state", P.mover_evidence(m)
    end
    if q.width < 1 or q.width > 320 or q.height < 1 or q.height > 320
        or q.x < 0 or q.y < 0 or q.x >= q.width or q.y >= q.height then
        return false, "bounds"
    end
    -- For personal space 3, GetMobileCost reads only the target cell.
    -- AddObject/RemoveObject choose the counter by category's zero/nonzero
    -- value, not allegiance. Account for BOTH counters, never the live byte.
    local low, high = math.floor(q.cell / 2) % 8, math.floor(q.cell / 16) % 8
    if q.cell >= 128 or q.cell % 2 ~= 0 then
        return false, "other-obstruction"
    end
    if low + high == 0 or low + high > 14 then return false, "count" end
    local ids, states, included, seen, saw_mover = {}, {}, {}, {}, false
    local expected_low, expected_high = 0, 0
    if #q.actors > 4096 then return false, "actor-limit" end
    for _, a in ipairs(q.actors) do
        if seen[a.id] then return false, "duplicate-actor" end
        seen[a.id] = true
        if a.id == m.id then
            saw_mover = true
        else
            if a.personal < 0 or a.personal > 255 or a.x < 0 or a.y < 0 then
                return false, "unknown-actor"
            end
            local dx, dy = math.abs(q.x - math.floor(a.x / 16)), math.abs(q.y - math.floor(a.y / 12))
            if eligible_ally(a) then
                -- Match the pinned AddObject footprint, including larger creatures.
                local radius=math.max(0,math.floor((a.personal-1)/2))
                if dx<=radius and dy<=radius and dx+dy<=math.floor(a.personal/2)+1 then
                    ids[#ids + 1] = a.id
                    states[#states+1] = string.format("%d:%d:%d:%d:%d",a.id,a.action,a.category,a.x,a.y)
                    if a.category == 0 then expected_high=expected_high+1 else expected_low=expected_low+1 end
                    included[a.id] = true
                end
            else
                -- Use the pinned AddObject footprint for foreign actors too;
                -- nearby enemies must not make unrelated allies solid.
                local envelope = math.max(0,math.floor((a.personal-1)/2))
                if not (a.painted==0 and a.removed==1) and dx<=envelope and dy<=envelope and dx+dy<=math.floor(a.personal/2)+1 then
                    return false, "foreign-or-ineligible", string.format("occupancy=0x%02X ",q.cell)..rejected_actor(a,dx,dy,envelope)
                end
            end
        end
    end
    if not saw_mover then return false, "incomplete-enumeration" end
    -- Portraits are fetched separately; each eligible contribution must appear
    -- in the area's enumeration. No stale position cache or stored sprite pointers.
    for _, a in ipairs(q.party) do
        if a.id ~= m.id and eligible_ally(a)
            and math.abs(q.x - math.floor(a.x / 16)) <= math.max(0,math.floor((a.personal-1)/2))
            and math.abs(q.y - math.floor(a.y / 12)) <= math.max(0,math.floor((a.personal-1)/2))
            and math.abs(q.x - math.floor(a.x / 16))+math.abs(q.y - math.floor(a.y / 12)) <= math.floor(a.personal/2)+1
            and not included[a.id] then return false, "missing-party-actor" end
    end
    if expected_low>7 or expected_high>7 or expected_low ~= low or expected_high ~= high then
        return false, "unaccounted-occupancy", string.format("occupancy=0x%02X expected_low=%d actual_low=%d expected_high=%d actual_high=%d ally_states=id:action:category:x:y/%s",
            q.cell,expected_low,low,expected_high,high,table.concat(states,"/"))
    end
    table.sort(ids)
    table.sort(states)
    return true, table.concat(ids, ","), string.format("occupancy=0x%02X ally_states=id:action:category:x:y/%s",q.cell,table.concat(states,"/"))
end
return P

end)()
-- Embedded by build_mrip_prototype.py after the tracer's locals/functions.
local pass_mode, pass_checks, pass_allowed, pass_denied = false, 0, 0, 0
local pass_reasons = {}
local movement_ready
-- Revision 10: preserve the decision, record each refusal up to a bounded cap.
local keep_detail_limit=128
local function keep_detail(kind,mover,point,reason,evidence,ordinal)
    if not active then return end
    if ordinal<=keep_detail_limit then
        log(string.format("%s_KEEP reason=%s mover=%d target=%d,%d refusal=%d %s",
            kind,reason,mover.m_id,point.x,point.y,ordinal,evidence or "evidence=unavailable"))
    elseif ordinal==keep_detail_limit+1 then
        log(kind.."_KEEP_TRUNCATED limit="..keep_detail_limit.."; remaining refusals counted in summary")
    end
end
local function actor_record(sprite, party_ids)
    local ptr = EEex_UDToPtr(sprite)
    return {id=sprite.m_id, party=party_ids[sprite.m_id] == ptr,
        ea=sprite.m_typeAI.m_EnemyAlly, state=sprite:getState(),
        base_state=sprite.m_baseStats.m_generalState, personal=sprite:getPersonalSpace(),
        x=sprite.m_pos.x, y=sprite.m_pos.y, action=sprite.m_curAction.m_actionID,
        category=EEex_Read32(ptr+0x492C), busy=EEex_Read32(ptr+0x493C),
        bump=EEex_ReadU8(ptr+0x4930), painted=EEex_Read32(ptr+0x5250),
        removed=EEex_Read32(ptr+0x5254)}
end
local function pass_decision(mover, point)
    if not movement_ready() then return false, "movement-off" end
    local area = mover.m_pArea
    if not area then return false, "no-area" end
    local area_ptr = EEex_UDToPtr(area)
    local party_ids, party = {}, {}
    for slot=0,5 do
        local s = EEex_Sprite_GetInPortrait(slot)
        if s and s.m_pArea and EEex_UDToPtr(s.m_pArea)==area_ptr then
            party_ids[s.m_id] = EEex_UDToPtr(s)
            party[#party+1] = s
        end
    end
    local m = actor_record(mover,party_ids)
    if not pass_policy.mover_eligible(m) then
        return false,"mover-state",pass_policy.mover_evidence(m)
    end
    local bitmap = area_ptr+0xA60
    local width,height = EEex_Read32(bitmap+0x138),EEex_Read32(bitmap+0x13C)
    local x,y = point.x,point.y
    if width<1 or width>320 or height<1 or height>320 or x<0 or y<0 or x>=width or y>=height then
        return false,"bounds"
    end
    local cells = EEex_ReadPtr(bitmap+0x120)
    if not cells or cells==0 then return false,"no-bitmap" end
    local cell = EEex_ReadU8(cells+y*width+x)
    if cell>=128 or cell%2~=0 then return false,"other-obstruction" end
    local actors = {}
    -- Integer zero explicitly disables LOS (false is replaced by 1 in EEex's
    -- wrapper). The radius covers a 320x320 search map in world coordinates.
    -- ANYONE is the engine's existing wildcard, not a parsed/filterable cache.
    area:forAllOfTypeInRange(x*16,y*12,CAIObjectType.ANYONE,32767,function(object)
        if not object then error("unresolved area object") end
        if EEex_GameObject_IsSprite(object,true) then
            if #actors>=4096 then error("area actor limit") end
            actors[#actors+1] = actor_record(EEex_CastUD(object,"CGameSprite"),party_ids)
        end
    end,0,0)
    local records = {}
    for _,s in ipairs(party) do records[#records+1]=actor_record(s,party_ids) end
    return pass_policy.evaluate({mover=m,x=x,y=y,width=width,height=height,cell=cell,actors=actors,party=records})
end
function MRIP_PassCost(mover,point)
    pass_checks=pass_checks+1
    local ok,allowed,reason,evidence=pcall(pass_decision,mover,point)
    if not ok then
        EEex_Write32(buffer+56,0)
        pass_mode=false
        log("PASS_ERROR disabled="..tostring(allowed))
        return false
    end
    if allowed then
        pass_allowed=pass_allowed+1
        if active then log(string.format("PASS_ALLOW mover=%d target=%d,%d allies=%s raw=255 effective=0 %s",mover.m_id,point.x,point.y,reason,evidence)) end
    else
        pass_denied=pass_denied+1
        pass_reasons[reason]=(pass_reasons[reason] or 0)+1
        keep_detail("PASS",mover,point,reason,evidence,pass_denied)
    end
    return allowed
end
-- MRIP_TogglePass and movement_ready are supplied by mrip_runtime.lua.
local function pass_summary()
    log(string.format("PASS_SUMMARY armed=%s checks=%d allowed=%d kept=%d detail_logged=%d detail_suppressed=%d",tostring(pass_mode),pass_checks,pass_allowed,pass_denied,
        math.min(pass_denied,keep_detail_limit),math.max(0,pass_denied-keep_detail_limit)))
end
local function pass_body()
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        cmp al, 0FFh
        jne mrip_pass_fast_exit
        mov rax, #L(MRIP_ring)
        cmp dword ptr ds:[rax+56], 1
        jne mrip_pass_fast_exit
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(152)
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
    ]]}, EEex_GenLuaCall("MRIP_PassCost", {
        args={
            function(offset) return {"mov qword ptr ss:[rsp+#$(1)], rsi #ENDL",{offset}},"CGameSprite" end,
            function(offset) return {"lea rax, [rbp-19h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL",{offset}},"CPoint" end,
        }, returnType=EEex_LuaCallReturnType.Boolean,
    }), {[[
        test rax, rax
        jz mrip_pass_restore
        mov byte ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], 0
        jmp mrip_pass_restore
        call_error:
        mrip_pass_restore:
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
        #DESTROY_SHADOW_SPACE
        jmp mrip_pass_flags
        mrip_pass_fast_exit:
        pop rax
        mrip_pass_flags:
        popfq
        #STACK_MOD(-8)
    ]]}})
end

-- Revision 7: same synchronous context, accounting for both party counters.
-- This reuses the walking predicate and changes a register, never map bytes.
local route_checks, route_allowed, route_denied = 0, 0, 0
local route_reasons = {}
function MRIP_RouteCost(mover,point)
    route_checks=route_checks+1
    local ok,allowed,reason,evidence=pcall(pass_decision,mover,point)
    if not ok then
        EEex_Write32(buffer+56,0)
        pass_mode=false
        log("ROUTE_ERROR disabled="..tostring(allowed))
        return false
    end
    if allowed then
        route_allowed=route_allowed+1
        if active then log(string.format("ROUTE_ALLOW mover=%d target=%d,%d allies=%s %s",mover.m_id,point.x,point.y,reason,evidence)) end
    else
        route_denied=route_denied+1
        route_reasons[reason]=(route_reasons[reason] or 0)+1
        keep_detail("ROUTE",mover,point,reason,evidence,route_denied)
    end
    return allowed
end
local function route_reset()
    route_checks,route_allowed,route_denied=0,0,0
    route_reasons={}
    if route_context then
        for offset=16,40,4 do EEex_Write32(route_context+offset,0) end
    end
end
local function route_summary()
    log(string.format("ROUTE_SUMMARY checks=%d allowed=%d kept=%d detail_logged=%d detail_suppressed=%d",route_checks,route_allowed,route_denied,
        math.min(route_denied,keep_detail_limit),math.max(0,route_denied-keep_detail_limit)))
    if route_context then
        log(string.format("ROUTE_NATIVE entries=%d cells=%d candidates=%d other_area=%d radius=%d other_bits=%d empty=%d",
            EEex_Read32(route_context+16),EEex_Read32(route_context+20),EEex_Read32(route_context+24),
            EEex_Read32(route_context+28),EEex_Read32(route_context+32),EEex_Read32(route_context+36),EEex_Read32(route_context+40)))
    end
end
local function route_context_body(enter)
    local body=[[
        pushfq
        push rax
        push rdx
        push r11
        mov rdx, #L(MRIP_route_context)
        mov r11, qword ptr gs:[48h]
    ]]
    if enter then body=body..[[
        mov rax, #L(MRIP_ring)
        cmp dword ptr ds:[rax+56], 1
        jne route_context_done
        xor eax, eax
        lock cmpxchg qword ptr ds:[rdx], r11
        jne route_context_occupied
        mov qword ptr ds:[rdx+8], rcx
        inc dword ptr ds:[rdx+16]
        jmp route_context_done
        route_context_occupied:
        cmp rax, r11
        jne route_context_done
        ; Nested entry on the same thread disables filtering conservatively.
        mov qword ptr ds:[rdx+8], 0
    ]] else body=body..[[
        cmp qword ptr ds:[rdx], r11
        jne route_context_done
        mov qword ptr ds:[rdx+8], 0
        mov qword ptr ds:[rdx], 0
    ]] end
    body=body..[[
        route_context_done:
        pop r11
        pop rdx
        pop rax
        popfq
    ]]
    -- EEex emits both halves into one JIT allocation; labels must be unique.
    return {(body:gsub("route_context_",enter and "route_enter_" or "route_leave_"))}
end
local function route_cost_body()
    -- GetCost has just loaded DL from the live bitmap. With radius RBP=0
    -- the examined cell is exactly R12's CPoint (space 3). Both register
    -- context and callback run only on the thread owning the SetTarget call.
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_ring)
        cmp dword ptr ds:[rax+56], 1
        jne route_fast_exit
        mov rax, #L(MRIP_route_context)
        mov rax, qword ptr ds:[rax]
        cmp rax, qword ptr gs:[48h]
        jne route_fast_exit
        mov rax, #L(MRIP_route_context)
        cmp qword ptr ds:[rax+8], 0
        jz route_fast_exit
        inc dword ptr ds:[rax+20]
        test dl, 07Eh
        jz route_empty
        test dl, 081h
        jnz route_other_bits
        test rbp, rbp
        jnz route_radius
        mov rax, qword ptr ds:[rax+8]
        mov rax, qword ptr ds:[rax+18h]
        add rax, 0A60h
        cmp rax, r14
        jne route_other_area
        mov rax, #L(MRIP_route_context)
        inc dword ptr ds:[rax+24]
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(152)
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
    ]]},EEex_GenLuaCall("MRIP_RouteCost",{
        args={
            function(offset) return {"mov rax, #L(MRIP_route_context) #ENDL mov rax, qword ptr ds:[rax+8] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL",{offset}},"CGameSprite" end,
            function(offset) return {"mov qword ptr ss:[rsp+#$(1)], r12 #ENDL",{offset}},"CPoint" end,
        },returnType=EEex_LuaCallReturnType.Boolean,
    }),{[[
        test rax, rax
        jz route_restore
        and byte ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], 081h
        jmp route_restore
        call_error:
        route_restore:
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
        #DESTROY_SHADOW_SPACE
        jmp route_flags
        route_empty:
        inc dword ptr ds:[rax+40]
        jmp route_fast_exit
        route_other_bits:
        inc dword ptr ds:[rax+36]
        jmp route_fast_exit
        route_radius:
        inc dword ptr ds:[rax+32]
        jmp route_fast_exit
        route_other_area:
        mov rax, #L(MRIP_route_context)
        inc dword ptr ds:[rax+28]
        route_fast_exit:
        pop rax
        route_flags:
        popfq
        #STACK_MOD(-8)
    ]]}})
end

-- Revision 9: restore only position-independent instructions before the wait branch.
local yield_checks,yield_allowed,yield_denied=0,0,0
local yield_reasons={}
function MRIP_YieldCost(mover,point)
    yield_checks=yield_checks+1
    local ok,allowed,reason,evidence=pcall(pass_decision,mover,point)
    if not ok then
        EEex_Write32(buffer+56,0)
        pass_mode=false
        log("YIELD_ERROR disabled="..tostring(allowed))
        return false
    end
    if allowed then
        yield_allowed=yield_allowed+1
        if active then log(string.format("YIELD_ALLOW mover=%d target=%d,%d allies=%s %s",mover.m_id,point.x,point.y,reason,evidence)) end
    else
        yield_denied=yield_denied+1
        yield_reasons[reason]=(yield_reasons[reason] or 0)+1
        keep_detail("YIELD",mover,point,reason,evidence,yield_denied)
    end
    return allowed
end
local function yield_reset()
    yield_checks,yield_allowed,yield_denied=0,0,0
    yield_reasons={}
end
local function yield_summary()
    log(string.format("YIELD_SUMMARY checks=%d allowed=%d kept=%d detail_logged=%d detail_suppressed=%d",yield_checks,yield_allowed,yield_denied,
        math.min(yield_denied,keep_detail_limit),math.max(0,yield_denied-keep_detail_limit)))
end
local function yield_body()
    -- AfterRestore executes add/movsxd/test; preserve the original empty-cell exit.
    -- An allow jumps to the original no-wait destination; a refusal executes
    -- the original wait branch. Every GPR, XMM and original flag is restored.
    local saves,restores={},{}
    for i,reg in ipairs({"rax","rcx","rdx","r8","r9","r10","r11"}) do
        saves[#saves+1]=string.format("mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-%d)], %s #ENDL",i*8,reg)
        table.insert(restores,1,string.format("mov %s, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-%d)] #ENDL",reg,i*8))
    end
    for i=0,5 do
        saves[#saves+1]=string.format("movdqu [rsp+#SHADOW_SPACE_BOTTOM(-%d)], xmm%d #ENDL",72+i*16,i)
        table.insert(restores,1,string.format("movdqu xmm%d, [rsp+#SHADOW_SPACE_BOTTOM(-%d)] #ENDL",i,72+i*16))
    end
    return EEex_FlattenTable({{[[
        jz jmp_success
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_ring)
        cmp dword ptr ds:[rax+56], 1
        jne yield_off
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(152)
    ]]},saves,EEex_GenLuaCall("MRIP_YieldCost",{
        args={
            function(offset) return {"mov qword ptr ss:[rsp+#$(1)], rsi #ENDL",{offset}},"CGameSprite" end,
            function(offset) return {"lea rax, [rbp-19h] #ENDL mov qword ptr ss:[rsp+#$(1)], rax #ENDL",{offset}},"CPoint" end,
        },returnType=EEex_LuaCallReturnType.Boolean,
    }),{[[
        test rax, rax
        jz yield_deny
    ]]},restores,{[[
        #DESTROY_SHADOW_SPACE(KEEP_ENTRY)
        popfq
        #STACK_MOD(-8)
        jmp jmp_success
        ; Resume compile-time frame state for the alternate runtime path.
        #STACK_MOD(8)
        #RESUME_SHADOW_ENTRY
        call_error:
        yield_deny:
    ]]},restores,{[[
        #DESTROY_SHADOW_SPACE
        popfq
        #STACK_MOD(-8)
        jmp jmp_fail
        yield_off:
        pop rax
        popfq
        jmp jmp_fail
    ]]}})
end

-- Revision 20: accept ordinary single-point jobs; extend only selected-KEEP. Native worker
-- code calls no Lua. The engine's later SnapshotRemoveObject subtracts one
-- captured footprint from the private bitmap; no occupancy bits are cleared.
local function worker_body()
    local guard=[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        push rcx
        #STACK_MOD(8)
        push rdx
        #STACK_MOD(8)
        push r8
        #STACK_MOD(8)
        push r9
        #STACK_MOD(8)
        push r10
        #STACK_MOD(8)
        push r11
        #STACK_MOD(8)
        #MAKE_SHADOW_SPACE(160)
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-16)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-32)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-48)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-64)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-80)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-96)], xmm5
        movsx r8, si
        lea r9, [rsp+#SHADOW_SPACE_BOTTOM(-144)]
        mov rax, qword ptr [r15+r8*8]
        mov qword ptr [r9], rax
        mov eax, dword ptr [r14+r8*4]
        mov dword ptr [r9+8], eax
        movzx eax, byte ptr [r13+r8]
        mov dword ptr [r9+12], eax
        mov rcx, qword ptr ss:[rsp+#LAST_FRAME_TOP(98h)]
        mov rdx, rdi
        movsx r8, si
        call worker_guard
        mov dword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-104)], eax
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-16)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-32)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-48)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-64)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-80)]
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-96)]
        cmp dword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-104)], 1
        je worker_restore_allow
        #DESTROY_SHADOW_SPACE(KEEP_ENTRY)
        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rax
        popfq
        #STACK_MOD(-64)
        jmp worker_keep
        worker_restore_allow:
        #STACK_MOD(64)
        #RESUME_SHADOW_ENTRY(KEEP_ENTRY)
        #DESTROY_SHADOW_SPACE
        pop r11
        pop r10
        pop r9
        pop r8
        pop rdx
        pop rcx
        pop rax
        popfq
        #STACK_MOD(-64)
    ]]
    -- Generate a second copied-field event only when the extra guard allows.
    local allowed=recorder(13,0x24DECB,"qword ptr ss:[rsp+98h]",nil,nil,nil,"mov eax, 1")
    local finish=[[
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_worker_remove)
        worker_keep:
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_worker_keep)

        worker_guard:
        push rbx
        push rsi
        push r12
        push r13
        push r14
        push r15
        sub rsp, 38h
        mov rbx, rcx
        mov r12, rdx
        mov rsi, r8
        mov qword ptr [rsp+28h], r9
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne worker_deny
        mov eax, dword ptr [rax+24]
        mov dword ptr [rsp+30h], eax
        test rbx, rbx
        jz worker_deny
        cmp byte ptr [rbx+8], 31h
        jne worker_deny
        cmp byte ptr [r12], 1
        jne worker_deny
        cmp dword ptr [r12+4], 0
        jne worker_deny
        ; +A is an auxiliary creature list: still unsupported. +B counts
        ; coordinate points in +58, not removed creatures. It shifts r12's
        ; search-point array only, not r13/r14/r15 selected removal captures.
        cmp byte ptr [r12+0Ah], 0
        jne worker_deny
        cmp byte ptr [r12+0xB], 1
        ja worker_deny
        cmp byte ptr [r12+0xB], 0
        je worker_points_valid
        cmp qword ptr [r12+58h], 0
        je worker_deny
        worker_points_valid:
        cmp byte ptr [r12+9], 6
        ja worker_deny
        test esi, esi
        js worker_deny
        movzx eax, byte ptr [r12+9]
        cmp esi, eax
        jae worker_deny
        mov r15, qword ptr [rbx+18h]
        test r15, r15
        jz worker_deny
        lea rax, [r15+0A60h]
        cmp qword ptr [r12+18h], rax
        jne worker_deny
        cmp dword ptr [rax+138h], 1
        jl worker_deny
        cmp dword ptr [rax+138h], 320
        jg worker_deny
        cmp dword ptr [rax+13Ch], 1
        jl worker_deny
        cmp dword ptr [rax+13Ch], 320
        jg worker_deny
        cmp qword ptr [rax+120h], 0
        je worker_deny
        mov rax, #L(g_pBaldurChitin)
        mov rax, qword ptr [rax]
        test rax, rax
        jz worker_deny
        mov r14, qword ptr [rax+1090h]
        test r14, r14
        jz worker_deny
        ; A selected list with duplicate IDs must not subtract twice.
        mov r10, qword ptr [r12+48h]
        test r10, r10
        jz worker_deny
        mov ecx, dword ptr [r10+rsi*4]
        cmp ecx, dword ptr [rbx+48h]
        jne worker_deny
        cmp ecx, dword ptr [r12+38h]
        je worker_deny
        movzx eax, byte ptr [r12+9]
        xor r8d, r8d
        xor r9d, r9d
        worker_list_loop:
        cmp ecx, dword ptr [r10+r8*4]
        jne worker_list_next
        inc r9d
        worker_list_next:
        inc r8d
        cmp r8d, eax
        jb worker_list_loop
        cmp r9d, 1
        jne worker_deny
        lea rdx, [rsp+20h]
        call #L(CGameObjectArray::GetShare)
        test al, al
        jnz worker_deny
        cmp qword ptr [rsp+20h], rbx
        jne worker_deny
        mov rcx, rbx
        call worker_actor
        test eax, eax
        jz worker_deny
        call worker_footprint
        test eax, eax
        jz worker_deny
        cmp dword ptr [rbx+5250h], 1
        jne worker_deny
        cmp dword ptr [rbx+5254h], 0
        jne worker_deny
        ; Require captured category/space/grid position to still match.
        mov r10, qword ptr [rsp+28h]
        cmp dword ptr [r10+12], 3
        jne worker_deny
        mov eax, dword ptr [rbx+492Ch]
        cmp eax, dword ptr [r10+8]
        jne worker_deny
        mov eax, dword ptr [rbx+0Ch]
        shr eax, 4
        cmp eax, dword ptr [r10]
        jne worker_deny
        mov eax, dword ptr [rbx+10h]
        xor edx, edx
        mov ecx, 12
        div ecx
        cmp eax, dword ptr [r10+4]
        jne worker_deny
        ; Actions do not change allied collision policy.
        mov ecx, dword ptr [r12+38h]
        lea rdx, [rsp+20h]
        call #L(CGameObjectArray::GetShare)
        test al, al
        jnz worker_deny
        mov r13, qword ptr [rsp+20h]
        test r13, r13
        jz worker_deny
        cmp byte ptr [r13+8], 31h
        jne worker_deny
        mov eax, dword ptr [r12+38h]
        cmp dword ptr [r13+48h], eax
        jne worker_deny
        cmp qword ptr [r13+47F0h], r12
        jne worker_deny
        mov eax, dword ptr [r13+5250h]
        cmp eax, 1
        ja worker_deny
        xor eax, 1
        cmp dword ptr [r13+5254h], eax
        jne worker_deny
        mov rcx, r13
        call worker_actor
        test eax, eax
        jz worker_deny
        ; Fresh identities/allegiance and capture epoch are checked on the worker.
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne worker_deny
        mov edx, dword ptr [rsp+30h]
        cmp dword ptr [rax+24], edx
        jne worker_deny
        mov eax, 1
        jmp worker_return
        worker_deny:
        xor eax, eax
        worker_return:
        add rsp, 38h
        pop r15
        pop r14
        pop r13
        pop r12
        pop rsi
        pop rbx
        ret

        worker_actor:
        ; RCX is a freshly resolved sprite. R14/R15 are current game/area.
        cmp byte ptr [rcx+8], 31h
        jne worker_actor_deny
        cmp byte ptr [rcx+38h], 2
        jb worker_actor_deny
        cmp byte ptr [rcx+38h], 30
        ja worker_actor_deny
        cmp qword ptr [rcx+18h], r15
        jne worker_actor_deny
        mov eax, dword ptr [rcx+0Ch]
        test eax, eax
        js worker_actor_deny
        mov edx, dword ptr [r15+0xB98]
        shl edx, 4
        cmp eax, edx
        jae worker_actor_deny
        mov eax, dword ptr [rcx+10h]
        test eax, eax
        js worker_actor_deny
        imul edx, dword ptr [r15+0xB9C], 12
        cmp eax, edx
        jae worker_actor_deny
        mov eax, dword ptr [rcx+48h]
        cmp eax, -1
        je worker_actor_deny
        ; Personal-space logic matches the original worker's two arms.
        test byte ptr [rcx+3C48h], 4
        jz worker_animation_space
        cmp byte ptr [rcx+3C50h], 3
        jne worker_actor_deny
        mov eax, 1
        ret
        worker_animation_space:
        mov rcx, qword ptr [rcx+3C40h]
        test rcx, rcx
        jz worker_actor_deny
        sub rsp, 28h
        mov rax, qword ptr [rcx]
        call qword ptr [rax+0C0h]
        add rsp, 28h
        cmp al, 3
        jne worker_actor_deny
        mov eax, 1
        ret
        worker_actor_deny:
        xor eax, eax
        ret

        worker_footprint:
        ; Require at least one captured-category count in every clipped cell.
        ; Avoid subtracting a disappeared footprint or a zero wrapped count.
        mov r10, qword ptr [rsp+30h] ; caller's capture pointer at rsp+28h
        mov ecx, dword ptr [r10]
        mov edx, dword ptr [r10+4]
        sub ecx, 1
        sub edx, 1
        xor r8d, r8d
        worker_footprint_y:
        xor r9d, r9d
        worker_footprint_x:
        lea eax, [rcx+r9]
        test eax, eax
        js worker_footprint_next
        cmp eax, dword ptr [r15+0xB98]
        jge worker_footprint_next
        lea r11d, [rdx+r8]
        test r11d, r11d
        js worker_footprint_next
        cmp r11d, dword ptr [r15+0xB9C]
        jge worker_footprint_next
        imul r11d, dword ptr [r15+0xB98]
        add r11d, eax
        mov rax, qword ptr [r15+0xB80]
        movzx eax, byte ptr [rax+r11]
        cmp dword ptr [r10+8], 0
        je worker_footprint_high
        test al, 0Eh
        jz worker_actor_deny
        jmp worker_footprint_next
        worker_footprint_high:
        test al, 70h
        jz worker_actor_deny
        worker_footprint_next:
        inc r9d
        cmp r9d, 3
        jb worker_footprint_x
        inc r8d
        cmp r8d, 3
        jb worker_footprint_y
        mov eax, 1
        ret
    ]]
    return EEex_FlattenTable({{guard},allowed,{finish}})
end

-- Skip allied candidates for allied movers before native push. No Lua/writes.
-- Original next-candidate branch owns list bookkeeping; no forged success.
local function bump_body()
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne bump_native
        cmp byte ptr [r13+8], 31h
        jne bump_native
        cmp byte ptr [r13+38h], 2
        jb bump_native
        cmp byte ptr [r13+38h], 30
        ja bump_native
        mov rax, qword ptr [rbp-50h]
        test rax, rax
        jz bump_native
        cmp byte ptr [rax+8], 31h
        jne bump_native
        cmp byte ptr [rax+38h], 2
        jb bump_native
        cmp byte ptr [rax+38h], 30
        ja bump_native
        mov rax, qword ptr [rax+18h]
        test rax, rax
        jz bump_native
        cmp rax, qword ptr [r13+18h]
        jne bump_native
        pop rax
        popfq
        #STACK_MOD(-16)
    ]]},recorder(14,0x34F5A3,"qword ptr ss:[rbp-50h]","r13"),{[[
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_bump_next)
        bump_native:
        #STACK_MOD(16)
        pop rax
        popfq
        #STACK_MOD(-16)
    ]]}})
end

local attack_policy=(function()
-- Soft destinations only. No cells, actors, orders or reservations are blocked.
local P={}
function P.ally(ea) return ea>=2 and ea<=30 end
function P.footprint(a,x,y)
    local r=math.max(0,math.floor((a.personal-1)/2))
    local dx,dy=math.abs(x-math.floor(a.x/16)),math.abs(y-math.floor(a.y/12))
    return dx<=r and dy<=r and dx+dy<=math.floor(a.personal/2)+1
end
function P.cell(q,x,y)
    if x<0 or y<0 or x>=q.width or y>=q.height then return false end
    local raw=q.read(x,y)
    if raw<0 or raw>255 or raw>=128 or raw%2~=0 then return false end
    local low,high,foreign=0,0,false
    for _,a in ipairs(q.actors) do
        -- Native movement temporarily removes an actor's painted footprint.
        -- Planned routes/endpoints still respect neutral and hostile bodies.
        -- This is private goal evaluation; no live occupancy is changed.
        if not P.ally(a.ea) and P.footprint(a,x,y) then foreign=true end
        if a.painted==1 and a.removed==0 then
            if P.footprint(a,x,y) then
                -- Pinned AddObject: category0 uses0x70, nonzero uses0x0E.
                if a.category==0 then high=high+1 else low=low+1 end
            end
        elseif a.painted~=0 or a.removed~=1 then
            -- Unknown phase is not permission to discard occupancy.
            return false
        end
    end
    return not foreign and low<8 and high<8 and low==math.floor(raw/2)%8 and high==math.floor(raw/16)%8
end
local function sight(q,x,y,tx,ty)
    local dx,dy=math.abs(tx-x),-math.abs(ty-y)
    local sx,sy=x<tx and 1 or -1,y<ty and 1 or -1
    local err=dx+dy
    while true do
        -- Only terrain here; the target's own hostile footprint must not
        -- invalidate visibility. Native Attack still checks actual LOS.
        local raw=q.read(x,y)
        if raw>=128 or raw%2~=0 then return false end
        if x==tx and y==ty then return true end
        local e=2*err
        if e>=dy then err=err+dy;x=x+sx end
        if e<=dx then err=err+dx;y=y+sy end
    end
end
function P.choose(q)
    if q.width<1 or q.width>320 or q.height<1 or q.height>320 then return nil,'bounds' end
    local m,t=q.mover,q.target
    if m.personal~=3 or t.personal<1 or t.personal>15 or q.range<1 or q.range>6 then return nil,'unsupported-reach' end
    local sx,sy=math.floor(m.x/16),math.floor(m.y/12)
    local tx,ty=math.floor(t.x/16),math.floor(t.y/12)
    if sx<0 or sy<0 or tx<0 or ty<0 or sx>=q.width or tx>=q.width or sy>=q.height or ty>=q.height then return nil,'bounds' end
    -- Matches Attack's size3 threshold arithmetic at +6A8..+6C9.
    local radius=q.range+math.floor((t.personal-1)/2)
    local cells,valid={},{}
    local function open(x,y)
        local key=y*q.width+x
        if x<0 or y<0 or x>=q.width or y>=q.height then return false end
        if valid[key]==nil then valid[key]=P.cell(q,x,y) end
        return valid[key]
    end
    if q.previous then
        local x,y=q.previous.x,q.previous.y
        local dx,dy=x-tx,y-ty
        if dx*dx+dy*dy<=radius*radius and not P.footprint(t,x,y) and open(x,y) and sight(q,x,y,tx,ty) then
            return {x=x,y=y},'retained'
        end
    end
    local left,right=math.max(0,math.min(sx,tx-radius)-2),math.min(q.width-1,math.max(sx,tx+radius)+2)
    local top,bottom=math.max(0,math.min(sy,ty-radius)-2),math.min(q.height-1,math.max(sy,ty+radius)+2)
    -- A bounded approach search; exhaustion falls back to native movement.
    local queue,head,visited={{sx,sy}},1,1
    cells[sy*q.width+sx]=0
    local dirs={{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}
    while head<=#queue and visited<=4096 do
        local p=queue[head];head=head+1
        local distance=cells[p[2]*q.width+p[1]]
        for _,d in ipairs(dirs) do
            local x,y=p[1]+d[1],p[2]+d[2]
            local key=y*q.width+x
            if x>=left and x<=right and y>=top and y<=bottom and cells[key]==nil and open(x,y)
                and (d[1]==0 or d[2]==0 or (open(p[1]+d[1],p[2]) and open(p[1],p[2]+d[2]))) then
                visited=visited+1
                if visited>4096 then break end
                cells[key]=distance+1;queue[#queue+1]={x,y}
            end
        end
    end
    local function candidate(x,y)
        local dx,dy=x-tx,y-ty
        -- The attacked body's allegiance does not affect final frontage.
        -- This restriction is only an endpoint preference: friendly bodies
        -- remain traversable in the approach search and the live engine.
        return dx*dx+dy*dy<=radius*radius and not P.footprint(t,x,y) and open(x,y) and cells[y*q.width+x]~=nil and sight(q,x,y,tx,ty)
    end
    local best,score
    for y=math.max(0,ty-radius),math.min(q.height-1,ty+radius) do
        for x=math.max(0,tx-radius),math.min(q.width-1,tx+radius) do
            if candidate(x,y) then
                local penalty=0
                for _,r in ipairs(q.reservations) do
                    local dx,dy=x-r.x,y-r.y
                    if dx*dx+dy*dy<9 then penalty=penalty+(9-dx*dx-dy*dy)*100 end
                end
                local value=cells[y*q.width+x]*10+penalty
                -- Prefer approach-side positions; do not chase a perfect ring.
                local ax,ay=sx-tx,sy-ty
                if ax*(x-tx)+ay*(y-ty)<0 then value=value+100 end
                if not score or value<score then best={x=x,y=y};score=value end
            end
        end
    end
    return best,best and 'selected' or (visited>4096 and 'search-budget' or 'no-valid-destination')
end
return P

end)()
local attack_reservations={}
local attack_failed_approaches={}
local attack_decision_seen,attack_decision_count,attack_decision_run={},0,nil
MRIP_AttackSpacingEnabled=true
local attack_actions={[3]=true,[94]=true,[98]=true,[105]=true,[134]=true}
local function attack_reset() attack_reservations={};attack_failed_approaches={} end
-- Capture-only, bounded decision evidence. Logging never changes admission.
local function attack_diagnose(mover,target,reach,stage,selected,reason)
    if not active then return end
    if attack_decision_run~=started_ms then
        attack_decision_seen,attack_decision_count,attack_decision_run={},0,started_ms
    end
    if attack_decision_count>=128 then return end
    local m=mover and actor_record(mover,{})
    local t=target and EEex_GameObject_IsSprite(target,true) and actor_record(EEex_CastUD(target,'CGameSprite'),{})
    local key=table.concat({stage,m and m.id or -1,t and t.id or -1,reason or 'unknown',
        m and m.action or -1,t and t.ea or -1,t and t.action or -1,t and t.state or 0,t and t.base_state or 0},':')
    if attack_decision_seen[key] then return end
    attack_decision_seen[key]=true;attack_decision_count=attack_decision_count+1
    log(string.format('ATTACK_DECISION stage=%s mover=%d mover_action=%d target=%d target_ea=%d target_action=%d target_state=0x%X target_base_state=0x%X target_pos=%d,%d reach=%d selected=%s reason=%s',
        stage,m and m.id or -1,m and m.action or -1,t and t.id or -1,t and t.ea or -1,t and t.action or -1,
        t and t.state or 0,t and t.base_state or 0,t and t.x or -1,t and t.y or -1,reach or -1,tostring(selected),reason or 'unknown'))
end
function MRIP_ToggleAttackSpacing()
    if not MRIP_TraceEnabled then feedback('movement unavailable; check EEex log');return end
    if active then MRIP_Stop('attack-mode-change') end
    MRIP_AttackSpacingEnabled=not MRIP_AttackSpacingEnabled
    attack_reset()
    log('ATTACK_MODE enabled='..tostring(MRIP_AttackSpacingEnabled))
    feedback(MRIP_AttackSpacingEnabled and 'attack spacing ON' or 'attack spacing OFF')
end
local function attack_select(mover,target,reach,point)
    if not MRIP_AttackSpacingEnabled then return false,'spacing-off' end
    local now=movement_ready()
    if not now then return false,'movement-off' end
    if not mover or not target or mover:getPortraitIndex()<0 or not attack_actions[mover.m_curAction.m_actionID]
        or not attack_policy.ally(mover.m_typeAI.m_EnemyAlly) or not EEex_GameObject_IsSprite(target,true) then return false,'mover-or-target-ineligible' end
    target=EEex_CastUD(target,'CGameSprite')
    if not mover.m_pArea or not target.m_pArea then return false,'no-area' end
    local area=mover.m_pArea
    local area_ptr=EEex_UDToPtr(area)
    if EEex_UDToPtr(target.m_pArea)~=area_ptr then return false,'different-area' end
    local mp,tp=EEex_UDToPtr(mover),EEex_UDToPtr(target)
    -- A failed custom approach must not repeatedly replace native fallback
    -- requests. Yield this actor/target pair until an engagement reset.
    -- Store only identity values; no retained game userdata or engine writes.
    local failed=attack_failed_approaches[mover.m_id]
    if failed then
        if failed.owner==mp and failed.target==target.m_id and failed.target_ptr==tp and failed.area==area_ptr then
            return false,'native-handoff'
        end
        attack_failed_approaches[mover.m_id]=nil
    end
    local previous=attack_reservations[mover.m_id]
    if previous and (previous.owner~=mp or previous.target~=target.m_id or previous.target_ptr~=tp or previous.area~=area_ptr) then previous=nil end
    -- Keep a just-submitted point while the native worker is in flight.
    -- MoveToPoint recognizes the same destination and leaves its request alone.
    local request=EEex_ReadPtr(mp+0x47F0)
    local path=EEex_ReadPtr(mp+0x4758)
    if previous and path==0 and request==0 and (math.floor(mover.m_pos.x/16)~=previous.x or math.floor(mover.m_pos.y/12)~=previous.y) then
        attack_reservations[mover.m_id]=nil
        attack_failed_approaches[mover.m_id]={owner=mp,target=target.m_id,target_ptr=tp,area=area_ptr}
        if active then log(string.format('ATTACK_SLOT_FALLBACK mover=%d target=%d reason=path-ended-before-slot',mover.m_id,target.m_id)) end
        log(string.format('ATTACK_NATIVE_HANDOFF mover=%d target=%d reason=path-ended-before-slot scope=engagement',mover.m_id,target.m_id))
        return false,'path-ended-before-slot'
    end
    if previous and request~=0 and now>=previous.assigned and now-previous.assigned<300
        and EEex_ReadU8(request)<=1 then point.x=previous.x*16+8;point.y=previous.y*12+6;return true,'pending-slot' end
    local bitmap=area_ptr+0xA60
    local width,height=EEex_Read32(bitmap+0x138),EEex_Read32(bitmap+0x13C)
    local map=EEex_ReadPtr(bitmap+0x120)
    if map==0 then return false,'no-map' end
    local actors,identities={},{}
    area:forAllOfTypeInRange(mover.m_pos.x,mover.m_pos.y,CAIObjectType.ANYONE,32767,function(object)
        if not object then error('unresolved attack area object') end
        if EEex_GameObject_IsSprite(object,true) then
            if #actors>=4096 then error('attack actor limit') end
            local s=EEex_CastUD(object,'CGameSprite')
            local a=actor_record(s,{})
            actors[#actors+1]=a;identities[a.id]={ptr=EEex_UDToPtr(s),action=a.action,actor=a}
        end
    end,0,0)
    -- NumCreature-style enumeration is not an identity registry: it scans the
    -- front list and filters activity/animation. Native Attack already passed
    -- these same-area arguments to this hook. Include them directly if omitted,
    -- while rejecting a conflicting identity and avoiding duplicate counters.
    local function include(s,ptr)
        local old=identities[s.m_id]
        if old then return old.ptr==ptr end
        if #actors>=4096 then error('attack actor limit') end
        local a=actor_record(s,{})
        actors[#actors+1]=a;identities[a.id]={ptr=ptr,action=a.action,actor=a}
        return true
    end
    local missing_target=not identities[target.m_id]
    if not include(mover,mp) or not include(target,tp) then return false,'identity-conflict' end
    local occupied={}
    for id,r in pairs(attack_reservations) do
        local a=identities[id]
        if r.area~=area_ptr or not a or a.ptr~=r.owner or not attack_actions[a.action]
            or now<r.updated or now-r.updated>1500 then
            attack_reservations[id]=nil
        elseif id~=mover.m_id and r.target==target.m_id and r.target_ptr==tp then occupied[#occupied+1]=r end
    end
    -- Existing friendly positions are only a soft preference for endpoints.
    for _,a in ipairs(actors) do
        if a.id~=mover.m_id and attack_policy.ally(a.ea) then occupied[#occupied+1]={x=math.floor(a.x/16),y=math.floor(a.y/12)} end
    end
    local selected,reason=attack_policy.choose({mover=identities[mover.m_id].actor,target=identities[target.m_id].actor,
        width=width,height=height,range=reach,actors=actors,reservations=occupied,previous=previous,
        read=function(x,y) return EEex_ReadU8(map+y*width+x) end})
    if not selected then
        attack_reservations[mover.m_id]=nil
        if active then log(string.format('ATTACK_SLOT_FALLBACK mover=%d target=%d reason=%s',mover.m_id,target.m_id,reason)) end
        return false,reason
    end
    if path==0 and request==0 and EEex_Read32(mp+0x4AA8)==selected.x*16+8 and EEex_Read32(mp+0x4AAC)==selected.y*12+6
        and (math.floor(mover.m_pos.x/16)~=selected.x or math.floor(mover.m_pos.y/12)~=selected.y) then
        attack_reservations[mover.m_id]=nil
        return false,'native-goal-ended-before-slot'
    end
    local changed=not previous or previous.x~=selected.x or previous.y~=selected.y
    attack_reservations[mover.m_id]={owner=mp,target=target.m_id,target_ptr=tp,area=area_ptr,x=selected.x,y=selected.y,
        updated=now,assigned=changed and now or previous.assigned}
    point.x=selected.x*16+8;point.y=selected.y*12+6
    if changed and active then log(string.format('ATTACK_SLOT mover=%d target=%d point=%d,%d reach=%d reason=%s',mover.m_id,target.m_id,point.x,point.y,reach,reason)) end
    return true,missing_target and 'selected-target-not-enumerated' or reason
end
function MRIP_AttackPosition(mover,target,reach,point)
    local ok,selected,reason=pcall(attack_select,mover,target,reach,point)
    if not ok then
        if mover then attack_reservations[mover.m_id]=nil end
        log('ATTACK_SLOT_ERROR fallback='..tostring(selected))
        return false
    end
    pcall(attack_diagnose,mover,target,reach,'position',selected,reason)
    return selected
end
function MRIP_AttackContinue(mover,target,reach)
    local ok,continue,reason=pcall(function()
        if not MRIP_AttackSpacingEnabled then return false end
        local now=movement_ready()
        if not now then return false end
        if not target or not EEex_GameObject_IsSprite(target,true) then return false end
        target=EEex_CastUD(target,'CGameSprite')
        local r=mover and attack_reservations[mover.m_id]
        if not r then return false,'no-assignment' end
        if not r or not target or not mover.m_pArea or not target.m_pArea or not attack_actions[mover.m_curAction.m_actionID]
            or r.owner~=EEex_UDToPtr(mover) or r.target~=target.m_id or r.target_ptr~=EEex_UDToPtr(target)
            or r.area~=EEex_UDToPtr(mover.m_pArea) or r.area~=EEex_UDToPtr(target.m_pArea)
            or not attack_policy.ally(mover.m_typeAI.m_EnemyAlly)
            or now<r.updated or now-r.updated>1500 or reach<1 or reach>6 then return false end
        local mp=EEex_UDToPtr(mover)
        if EEex_ReadPtr(mp+0x4758)==0 or EEex_Read32(mp+0x4AA8)~=r.x*16+8 or EEex_Read32(mp+0x4AAC)~=r.y*12+6 then return false end
        local dx,dy=r.x-math.floor(target.m_pos.x/16),r.y-math.floor(target.m_pos.y/12)
        local radius=reach+math.floor((target:getPersonalSpace()-1)/2)
        if dx*dx+dy*dy>radius*radius then attack_reservations[mover.m_id]=nil;return false end
        return math.floor(mover.m_pos.x/16)~=r.x or math.floor(mover.m_pos.y/12)~=r.y
    end)
    if not ok then log('ATTACK_CONTINUE_ERROR fallback='..tostring(continue));return false end
    pcall(attack_diagnose,mover,target,reach,'continue',continue,reason or (continue and 'assigned-path' or 'native-stop'))
    return continue
end
-- Attack overwrites its reach register with the target-position pointer
-- during the visibility check. Capture it at the range arithmetic first.
-- This private UI context is consumed by the immediately following call;
-- AttackReevaluate keeps its reach in DI and does not use this context.
local function attack_capture_body()
    return {[[
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_attack_context)
        mov [rax], rbx
        mov [rax+8], rsi
        movsx rax, r14w
        push rcx
        #STACK_MOD(8)
        mov rcx, #L(MRIP_attack_context)
        mov [rcx+16], rax
        pop rcx
        #STACK_MOD(-8)
        pop rax
        #STACK_MOD(-8)
    ]]}
end
local function attack_body(reevaluate)
    local reach=reevaluate and 'movsx rax, di' or 'mov rax, #L(MRIP_attack_context) #ENDL mov rax, [rax+16]'
    local context=reevaluate and '' or [[
        mov rax, #L(MRIP_attack_context)
        cmp [rax], rcx
        jne attack_restore
        cmp [rax+8], rdx
        jne attack_restore
    ]]
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        #MAKE_SHADOW_SPACE(248)
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-176)], 0
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne attack_restore
    ]]},{context},EEex_GenLuaCall('MRIP_AttackPosition',{
        args={
            function(o) return {'mov rax, [rsp+#SHADOW_SPACE_BOTTOM(-16)] #ENDL mov [rsp+#$(1)], rax #ENDL',{o}},'CGameSprite' end,
            function(o) return {'mov rax, [rsp+#SHADOW_SPACE_BOTTOM(-24)] #ENDL mov [rsp+#$(1)], rax #ENDL',{o}},'CGameObject' end,
            function(o) return {reach..' #ENDL mov [rsp+#$(1)], rax #ENDL',{o}} end,
            function(o) return {'lea rax, [rsp+#SHADOW_SPACE_BOTTOM(-168)] #ENDL mov [rsp+#$(1)], rax #ENDL',{o}},'CPoint' end,
        },returnType=EEex_LuaCallReturnType.Boolean,
    }),{[[
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-176)], eax
        jmp attack_restore
        call_error:
        attack_restore:
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11, [rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10, [rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9, [rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8, [rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx, [rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx, [rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax, [rsp+#SHADOW_SPACE_BOTTOM(-8)]
        cmp dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-176)], 1
        jne attack_native
        lea rdx, [rsp+#SHADOW_SPACE_BOTTOM(-168)]
        call #L(MRIP_move_point)
        jmp attack_done
        attack_native:
        call #L(MRIP_move_object)
        attack_done:
        #DESTROY_SHADOW_SPACE
        popfq
        #STACK_MOD(-8)
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_attack_return)
    ]]}})
end
local function attack_continue_body(reevaluate)
    local mover,target,reach=reevaluate and 'rsi' or 'rbx',reevaluate and 'rbx' or 'rsi',reevaluate and 'di' or 'r14w'
    local reach_code=reevaluate and 'movsx rax, di' or 'mov rax, #L(MRIP_attack_context) #ENDL mov rax, [rax+16]'
    local context=reevaluate and '' or [[
        mov rax, #L(MRIP_attack_context)
        cmp [rax], rbx
        jne attack_continue_restore
        cmp [rax+8], rsi
        jne attack_continue_restore
    ]]
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        #MAKE_SHADOW_SPACE(224)
        mov [rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov [rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov [rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov [rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov [rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-160)], 0
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne attack_continue_restore
    ]]},{context},EEex_GenLuaCall('MRIP_AttackContinue',{
        args={
            function(o) return {'mov [rsp+#$(1)], '..mover..' #ENDL',{o}},'CGameSprite' end,
            function(o) return {'mov [rsp+#$(1)], '..target..' #ENDL',{o}},'CGameObject' end,
            function(o) return {reach_code..' #ENDL mov [rsp+#$(1)], rax #ENDL',{o}} end,
        },returnType=EEex_LuaCallReturnType.Boolean,
    }),{[[
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-160)], eax
        jmp attack_continue_restore
        call_error:
        attack_continue_restore:
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11, [rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10, [rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9, [rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8, [rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx, [rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx, [rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax, [rsp+#SHADOW_SPACE_BOTTOM(-8)]
        cmp dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-160)], 1
        je attack_continue_yes
        #DESTROY_SHADOW_SPACE(KEEP_ENTRY)
        popfq
        #STACK_MOD(-8)
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_attack_stop)
        attack_continue_yes:
        #STACK_MOD(8)
        #RESUME_SHADOW_ENTRY(KEEP_ENTRY)
        #DESTROY_SHADOW_SPACE
        popfq
        #STACK_MOD(-8)
        #MANUAL_HOOK_EXIT(0)
        jmp #L(MRIP_attack_approach)
    ]]}})
end

local settle_policy=(function()
-- Local endpoint selection only: no actor, bitmap or command writes.
local P={}
function P.distance2(a,b)
    local dx,dy=a.x-b.x,(a.y-b.y)*4/3
    return dx*dx+dy*dy
end
function P.stacked(a,b) return P.distance2(a,b)<=100 end
function P.choose(q,cell)
    local m=q.mover
    if m.personal~=3 or q.width<1 or q.width>320 or q.height<1 or q.height>320 then return nil end
    local sx,sy=math.floor(m.x/16),math.floor(m.y/12)
    -- Native GetCost for space3 scans only the visited center. AddObject's
    -- larger painted footprint belongs to the obstacle, not mover clearance.
    -- cell() still accounts for that whole footprint and logical hostiles.
    local function open(x,y)
        if q.terrain and not q.terrain(x,y) then return false end
        return cell(q,x,y)
    end
    if not open(sx,sy) then return nil end
    local best,score,preference
    for dy=-1,1 do for dx=-1,1 do
        if dx~=0 or dy~=0 then
            local x,y=sx+dx,sy+dy
            local p={x=x*16+8,y=y*12+6}
            local d=P.distance2(m,p)
            local legal=d<=1024 and open(x,y)
                and (dx==0 or dy==0 or (open(sx+dx,sy) and open(sx,sy+dy)))
            local preferred=0
            if legal then
                for _,other in ipairs(q.positions) do
                    local separation=P.distance2(p,other)
                    if separation<256 then legal=false;break end
                    if separation<324 then preferred=1 end
                end
            end
            -- Prefer18 over16 normalized pixels without losing a legal16px
            -- endpoint when local terrain/crowding cannot offer the preference.
            if legal and (not score or preferred<preference or (preferred==preference and d<score)) then
                best=p;score=d;preference=preferred
            end
        end
    end end
    return best
end
return P

end)()
local settle_native_factory=(function()
-- Embedded game Lua5.2 has no require/FFI. Register an EEex Lua C bridge.
-- LuaBindings exposes CMessageStopActions without a constructor method.
local signature='48895c2410574883ec2089510c488d05ec592e00488901498bf944894108488bd94d85c97455498bc9e882c10a00488bcfe8aac10a00488b0733d2488bcfff90d0000000488b07488d15f2ff3b00488bcfff90180100000fb615305a3000488bcfe81ade0c0048c7442430ffffffff488b442430488987244c0000488bc3488b5c24384883c4205fc3'
return function(base,read,runWithStack,pointer)
    local address=base+0x2A7440
    for i=1,#signature,2 do
        assert(read(address+(i-1)/2)==tonumber(signature:sub(i,i+1),16),
            'native settle Stop signature mismatch')
    end
    assert(type(EEex_JITNearAsLuaFunction)=='function' and type(EEex_DefineAssemblyLabel)=='function',
        'native settle bridge API unavailable')
    EEex_DefineAssemblyLabel('MRIP_SettleStopConstructor',address)
    local body=[[
        push rbx
        push rsi
        push rdi
        sub rsp, 30h
        mov rbx, rcx
        mov edx, 1
        lea r8, [rsp+20h]
        call #L(Hardcoded_lua_tointegerx)
        cmp dword ptr [rsp+20h], 0
        je mrip_settle_stop_return
        test rax, rax
        jz mrip_settle_stop_return
        mov rsi, rax
        mov rcx, rbx
        mov edx, 2
        lea r8, [rsp+20h]
        call #L(Hardcoded_lua_tointegerx)
        cmp dword ptr [rsp+20h], 0
        je mrip_settle_stop_return
        mov edi, eax
        mov rcx, rbx
        mov edx, 3
        lea r8, [rsp+20h]
        call #L(Hardcoded_lua_tointegerx)
        cmp dword ptr [rsp+20h], 0
        je mrip_settle_stop_return
        test rax, rax
        jz mrip_settle_stop_return
        mov r9, rax
        mov r8d, edi
        mov edx, edi
        mov rcx, rsi
        call #L(MRIP_SettleStopConstructor)
        mrip_settle_stop_return:
        xor eax, eax
        add rsp, 30h
        pop rdi
        pop rsi
        pop rbx
        ret
    ]]
    EEex_JITNearAsLuaFunction('MRIP_SettleStopNative',{body})
    assert(type(MRIP_SettleStopNative)=='function','native settle bridge registration failed')
    local stop=function(sprite)
        runWithStack(16,function(storage)
            MRIP_SettleStopNative(storage,sprite.m_id,pointer(sprite))
        end)
    end
    return stop
end

end)()
-- UI-only post-Move settlement. Native movement hooks remain unchanged.
MRIP_SettleEnabled=true
local settle_records,settle_last={},nil
local settle_serial=0
local settle_game_time=nil
local settle_native_stop=nil
local settle_mask=0x80102FEF
local settle_quiet_ms=150
local function settle_tagged(action)
    local token=action and action.m_specificID3
    return token and token>=0x4D000000 and token<0x4E000000
end
local function settle_arrived(sprite,r)
    return r.goal and math.floor(sprite.m_pos.x/16)==math.floor(r.goal.x/16)
        and math.floor(sprite.m_pos.y/12)==math.floor(r.goal.y/12)
end
local function settle_queue(sprite)
    local count,only=0,nil
    EEex_Utility_IterateCPtrList(sprite.m_queuedActions,function(a)
        count=count+1;only=EEex_CastUD(a,'CAIAction')
        return count>1
    end)
    return count,only
end
local function settle_matches(action,r)
    return action and action.m_actionID==23 and action.m_specificID3==r.token
        and action.m_dest.x==r.x and action.m_dest.y==r.y
end
local function settle_identity(sprite,r)
    return sprite and sprite.m_pArea and sprite.m_id==r.id
        and EEex_UDToPtr(sprite)==r.owner and EEex_UDToPtr(sprite.m_pArea)==r.area
end
local function settle_end(sprite,r,reason)
    log('SETTLE_END mover='..r.id..' reason='..reason..' pos='..sprite.m_pos.x..','..sprite.m_pos.y
        ..' goal='..r.x..','..r.y..' reached='..tostring(math.floor(sprite.m_pos.x/16)==math.floor(r.x/16)
            and math.floor(sprite.m_pos.y/12)==math.floor(r.y/12))
        ..' moved2='..tostring(settle_policy.distance2(sprite.m_pos,r.origin)))
end
local function settle_stop(sprite,r)
    if not settle_identity(sprite,r) then return false end
    local count,queued=settle_queue(sprite)
    local action=sprite.m_curAction
    if not ((count==0 and settle_matches(action,r))
        or (action.m_actionID==0 and count==1 and settle_matches(queued,r))) then return false end
    -- The pinned constructor's third sprite argument performs native Stop
    -- synchronously (queue/action/path cleanup). No message is posted, and
    -- no userdata survives this callback. Its only object fields are vtable
    -- and source/target IDs; it allocates no resources requiring destruction.
    assert(settle_native_stop,'native settle Stop not initialized')
    settle_native_stop(sprite)
    return true
end
local function settle_reset(cancel)
    if cancel then
        for slot=0,5 do
            local sprite=EEex_Sprite_GetInPortrait(slot)
            local r=sprite and settle_records[sprite.m_id]
            if r and r.token then settle_stop(sprite,r) end
        end
    end
    settle_records={};settle_last=nil;settle_game_time=nil
end
local function settle_world()
    if not worldScreen or not e or e:GetActiveEngine()~=worldScreen then return false end
    local paused=worldScreen:CheckIfPaused()
    if paused==true or paused==1 then return false end
    local game=EEex_EngineGlobal_CBaldurChitin and EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
    if not game then return false end
    local mode=game.m_gameSave.m_inputMode
    if EEex_BAnd(mode-0x1016E,0xFFFDFFFF)==0 or EEex_BAnd(mode,0x801)==0 then return false end
    if Infinity_IsMenuOnStack('WORLD_DIALOG') then return false end
    -- The existing project network adapter uses CChitin +2C9 (session open).
    -- Until ownership/synchronization is designed, no automatic MP orders.
    local chitin=EEex_ReadPtr(base+0x667560)
    return chitin~=0 and EEex_ReadU8(chitin+0x2C9)==0
end
local function settle_safe(sprite,a)
    return attack_policy.ally(a.ea) and a.personal==3 and a.painted==1 and a.removed==0
        and a.busy==0 and a.bump==0 and sprite.m_inCutScene==0
        and EEex_BAnd(a.state,settle_mask)==0 and EEex_BAnd(a.base_state,settle_mask)==0
end
local function settle_observe(sprite,action)
    if not MRIP_SettleEnabled or not pass_mode or not sprite or sprite:getPortraitIndex()<0 then return end
    local r=settle_records[sprite.m_id]
    if r and r.token then
        if settle_identity(sprite,r) and not r.ack and settle_matches(action,r) then r.ack=true;return end
        -- Never retain ownership across a second action, even a same-point
        -- Move. Completion to idle consumes the attempt without reenrollment.
        if settle_identity(sprite,r) then settle_end(sprite,r,action.m_actionID==0 and 'native-idle' or 'new-order') end
        settle_records[sprite.m_id]=nil
        if action.m_actionID==0 then return end
        r=nil
    end
    if (action.m_actionID==0 or action.m_actionID==84) and r and not r.token
        and settle_identity(sprite,r) and settle_arrived(sprite,r) then
        if action.m_actionID==84 then r.since=nil end
        return -- Group Move23 -> Face84 -> idle retains completed arrival.
    end
    if action.m_actionID==23 and not settle_tagged(action) and sprite.m_pArea then
        settle_records[sprite.m_id]={id=sprite.m_id,owner=EEex_UDToPtr(sprite),area=EEex_UDToPtr(sprite.m_pArea),
            goal=action.m_dest and {x=action.m_dest.x,y=action.m_dest.y} or nil}
    else settle_records[sprite.m_id]=nil end
end
local function settle_local_point(sprite,q)
    -- GetCost's personal-space0 query skips dynamic occupancy, but retains
    -- the native terrain resource decoding and this actor's terrain cost table.
    -- Keep independent center-cell checks for doors, enemy footprints and unknown paint.
    local bitmap=EEex_PtrToUD(EEex_UDToPtr(sprite.m_pArea)+0xA60,'CSearchBitmap')
    assert(bitmap and bitmap.GetCost and sprite.virtual_GetTerrainTable,'native settle terrain binding unavailable')
    local terrain_ptr=EEex_UDToPtr(sprite:virtual_GetTerrainTable())
    assert(terrain_ptr and terrain_ptr~=0,'native settle terrain table unavailable')
    local terrain=EEex_PtrToUD(terrain_ptr,'Primitive<byte>')
    local cache={}
    local selected,ok,err
    -- Shipped RunWithStack returns no callback values and catches errors.
    -- Copy the plain result out and propagate failures through our own boundary.
    EEex_RunWithStack(16,function(storage)
        ok,err=pcall(function()
            local point=EEex_PtrToUD(storage,'CPoint')
            local tile=EEex_PtrToUD(storage+8,'Primitive<ushort>')
            q.terrain=function(x,y)
                if x<0 or y<0 or x>=q.width or y>=q.height then return false end
                local key=y*q.width+x
                if cache[key]==nil then
                    point.x=x;point.y=y
                    local cost=bitmap:GetCost(point,terrain,0,tile,1)
                    assert(type(cost)=='number' and cost>=0 and cost<=255,'invalid native terrain cost')
                    cache[key]=cost~=255
                    if active then log(string.format('SETTLE_TERRAIN mover=%d cell=%d,%d cost=%d',q.mover.id,x,y,cost)) end
                end
                return cache[key]
            end
            selected=settle_policy.choose(q,attack_policy.cell)
        end)
        q.terrain=nil -- Do not retain the temporary point/output userdata.
    end)
    if not ok then error(err or 'native settle terrain callback unavailable') end
    return selected
end
local function settle_submit(sprite,r,p,now)
    if not settle_native_stop then
        settle_native_stop=settle_native_factory(base,EEex_ReadU8,EEex_RunWithStack,EEex_UDToPtr)
        log('SETTLE_READY stop=verified-native-ctor')
    end
    settle_serial=(settle_serial+1)%0x1000000
    r.token=0x4D000000+settle_serial;r.x=p.x;r.y=p.y;r.started=now;r.ack=false
    r.origin={x=sprite.m_pos.x,y=sprite.m_pos.y}
    -- MoveToPoint in installed ACTION.IDS has only a point parameter. Mark
    -- the otherwise unused third integer on this newly parsed action; never
    -- mark or rewrite an existing player/AI action.
    EEex_RunWithStackManager({{name='script',struct='CAIScriptFile'},
        {name='text',struct='CString',constructor={args={'MoveToPoint(['..p.x..'.'..p.y..'])'}},noDestruct=true}},function(manager)
        local script=manager:getUD('script')
        script:ParseResponseString(manager:getUD('text'))
        local count=0
        EEex_Utility_IterateCPtrList(script.m_curResponse.m_actionList,function(a)
            a=EEex_CastUD(a,'CAIAction');count=count+1
            assert(count==1 and a.m_actionID==23,'unexpected settle action')
            a.m_specificID3=r.token
            sprite:virtual_InsertAction(a)
        end)
        assert(count==1,'missing settle action')
    end)
    log(string.format('SETTLE_MOVE mover=%d point=%d,%d token=%d',r.id,p.x,p.y,r.token))
end
local function settle_tick_inner(now)
    if not MRIP_SettleEnabled or not settle_world() then
        -- Pause/dialogue preserves an owned move, but resets arrival timing.
        for _,r in pairs(settle_records) do r.since=nil;if r.token then r.started=now end end
        return
    end
    if settle_last and now-settle_last<100 then return end
    settle_last=now
    local time=EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_worldTime.m_gameTime
    if settle_game_time and time<settle_game_time then settle_reset(false) end
    settle_game_time=time
    local party,seen={},{ }
    for slot=0,5 do
        local sprite=EEex_Sprite_GetInPortrait(slot)
        if sprite and sprite.m_pArea then
            local a=actor_record(sprite,{})
            local ptr,area=EEex_UDToPtr(sprite),EEex_UDToPtr(sprite.m_pArea)
            local r=settle_records[a.id]
            seen[a.id]=true
            if r and not settle_identity(sprite,r) then settle_records[a.id]=nil;r=nil end
            if r and r.token then
                local count,queued=settle_queue(sprite)
                local owned=settle_matches(sprite.m_curAction,r) and count==0
                local pending=a.action==0 and count==1 and settle_matches(queued,r)
                local path=EEex_ReadPtr(ptr+0x4758)
                local points=EEex_Read16(ptr+0x4760)
                -- DropPath leaves the previous length behind. Only a live path
                -- makes that count evidence of a long route for this step.
                local cause=not settle_safe(sprite,a) and 'eligibility'
                    or now-r.started>=1250 and 'timeout'
                    or settle_policy.distance2(a,r.origin)>1024 and 'envelope'
                    or path~=0 and points>2 and 'active-long-path'
                if not owned and not pending then
                    settle_end(sprite,r,a.action==0 and 'native-idle' or 'new-order')
                    settle_records[a.id]=nil;r=nil
                elseif cause then
                    local request=EEex_ReadPtr(ptr+0x47F0)
                    local stopped=settle_stop(sprite,r)
                    log('SETTLE_END mover='..a.id..' reason=bounded-abort stopped='..tostring(stopped)
                        ..' cause='..cause..' age_ms='..(now-r.started)..' path_ptr='..tostring(path)
                        ..' path_length='..points..' request_ptr='..tostring(request))
                    settle_records[a.id]=nil;r=nil
                end
            elseif a.action==23 and settle_safe(sprite,a) and not settle_tagged(sprite.m_curAction) then
                -- Also enroll a Move already running when F6 was enabled.
                r=r or {id=a.id,owner=ptr,area=area};r.since=nil
                local goal=sprite.m_curAction.m_dest
                r.goal=goal and {x=goal.x,y=goal.y} or nil
                settle_records[a.id]=r
            elseif r then
                local count=settle_queue(sprite)
                if a.action~=0 or not settle_safe(sprite,a) or count~=0
                    or EEex_ReadPtr(ptr+0x4758)~=0 or EEex_ReadPtr(ptr+0x47F0)~=0
                    or not settle_arrived(sprite,r) then
                    r.since=nil
                    if a.action~=0 and a.action~=23 and not (a.action==84 and settle_arrived(sprite,r)) then
                        settle_records[a.id]=nil;r=nil
                    end
                elseif not r.since or r.px~=a.x or r.py~=a.y then r.since=now;r.px=a.x;r.py=a.y end
            end
            party[#party+1]={sprite=sprite,actor=a,r=r,area=area,slot=slot}
        end
    end
    for id in pairs(settle_records) do if not seen[id] then settle_records[id]=nil end end
    for _,p in ipairs(party) do
        local r=p.r
        if r and not r.token and not r.attempted and r.since and now-r.since>=settle_quiet_ms then
            local stacked,lower,fixed=false,false,false
            for _,other in ipairs(party) do
                local other_ptr=EEex_UDToPtr(other.sprite)
                local resting=other.actor.action==0 and settle_queue(other.sprite)==0
                    and EEex_ReadPtr(other_ptr+0x4758)==0 and EEex_ReadPtr(other_ptr+0x47F0)==0
                if other~=p and other.area==p.area and resting and settle_policy.stacked(p.actor,other.actor) then
                    stacked=true
                    if other.r and not other.r.token and not other.r.attempted and other.r.since
                        and now-other.r.since>=settle_quiet_ms then
                        if other.slot<p.slot then lower=true end
                    elseif not other.r or not other.r.token then fixed=true end
                end
            end
            if stacked and not lower and not fixed then
                r.attempted=true;r.anchor=true
            elseif stacked then
                r.attempted=true
                local actors,positions={},{}
                p.sprite.m_pArea:forAllOfTypeInRange(p.actor.x,p.actor.y,CAIObjectType.ANYONE,32767,function(object)
                    if not object then error('unresolved settle object') end
                    if EEex_GameObject_IsSprite(object,true) then
                        if #actors>=4096 then error('settle actor limit') end
                        actors[#actors+1]=actor_record(EEex_CastUD(object,'CGameSprite'),{})
                    end
                end,0,0)
                for _,a in ipairs(actors) do if a.id~=p.actor.id then positions[#positions+1]={x=a.x,y=a.y} end end
                for _,other in ipairs(party) do
                    if other.area==p.area and other.r and other.r.token then positions[#positions+1]={x=other.r.x,y=other.r.y} end
                end
                local bitmap=p.area+0xA60
                local width,height=EEex_Read32(bitmap+0x138),EEex_Read32(bitmap+0x13C)
                local map=EEex_ReadPtr(bitmap+0x120)
                local selected=map~=0 and settle_local_point(p.sprite,{mover=p.actor,width=width,height=height,actors=actors,positions=positions,
                    read=function(x,y) return EEex_ReadU8(map+y*width+x) end}) or nil
                if selected then settle_submit(p.sprite,r,selected,now)
                else log('SETTLE_KEEP mover='..p.actor.id..' reason=no-local-point') end
                return -- At most one attempt per heartbeat; never solve crowds.
            end
        end
    end
end
local function settle_fail(err)
    MRIP_SettleEnabled=false
    pcall(settle_reset,true)
    log('SETTLE_ERROR disabled='..tostring(err))
    feedback('gentle settle disabled; check EEex log')
end
local function settle_tick(now)
    local ok,err=pcall(settle_tick_inner,now)
    if not ok then settle_fail(err) end
end
local function settle_action(sprite,action)
    local ok,err=pcall(settle_observe,sprite,action)
    if not ok then settle_fail(err) end
end
function MRIP_ToggleSettle()
    if not MRIP_TraceEnabled then feedback('movement unavailable; check EEex log');return end
    local ok,err=pcall(settle_reset,true)
    if not ok then settle_fail(err);return end
    MRIP_SettleEnabled=not MRIP_SettleEnabled
    log('SETTLE_MODE enabled='..tostring(MRIP_SettleEnabled))
    feedback(MRIP_SettleEnabled and 'gentle settle ON' or 'gentle settle OFF')
end

-- Continuous movement activation; diagnostic captures remain bounded.
local movement_last_clock,maintenance_clock=nil,nil
local movement_idle={}
local activation_generation=0
local function movement_generation()
    activation_generation=(activation_generation+1)%0x80000000
    if buffer then EEex_Write32(buffer+24,activation_generation) end
end
local function movement_disable(reason)
    local settled,settle_err=pcall(settle_reset,true)
    if not settled then settle_fail(settle_err) end
    pass_mode=false;movement_last_clock=nil;maintenance_clock=nil;movement_idle={}
    if buffer then EEex_Write32(buffer+56,0) end
    movement_generation()
    attack_reset()
    log('MOVEMENT_DISABLED reason='..tostring(reason))
end
movement_ready=function()
    if not pass_mode or not MRIP_TraceEnabled then return nil end
    local now=clock()
    if not now or (movement_last_clock and now<movement_last_clock) then
        movement_disable('clock-reset');return nil
    end
    movement_last_clock=now
    return now
end
local function movement_status()
    log('MOVEMENT_STATE enabled='..tostring(pass_mode)..' preference='..tostring(MRIP_PreferenceEnabled)..' spacing='..tostring(MRIP_AttackSpacingEnabled)..' settle='..tostring(MRIP_SettleEnabled)..' capture='..tostring(active)..' generation='..activation_generation)
end
local function movement_party(now)
    if maintenance_clock and now>=maintenance_clock and now-maintenance_clock<100 then return end
    maintenance_clock=now
    local seen={}
    for slot=0,5 do
        local sprite=EEex_Sprite_GetInPortrait(slot)
        EEex_Write32(buffer+32+slot*4,sprite and sprite.m_id or -1)
        if sprite then
            local id,ptr=sprite.m_id,EEex_UDToPtr(sprite)
            local area=sprite.m_pArea and EEex_UDToPtr(sprite.m_pArea) or nil
            seen[id]=true
            for _,cache in ipairs({attack_reservations,attack_failed_approaches}) do
                local r=cache[id]
                if r and (r.owner~=ptr or r.area~=area or not attack_policy.ally(sprite.m_typeAI.m_EnemyAlly)) then
                    cache[id]=nil;movement_idle[id]=nil
                end
            end
            local action=sprite.m_curAction.m_actionID
            if action==23 then
                attack_reservations[id]=nil;attack_failed_approaches[id]=nil;movement_idle[id]=nil
            elseif action==0 and EEex_ReadPtr(ptr+0x4758)==0 and EEex_ReadPtr(ptr+0x47F0)==0 then
                local idle=movement_idle[id]
                if not idle or idle.owner~=ptr or idle.area~=area then
                    movement_idle[id]={owner=ptr,area=area,since=now}
                elseif now-idle.since>=1000 then
                    attack_reservations[id]=nil;attack_failed_approaches[id]=nil
                end
            else
                movement_idle[id]=nil
            end
        end
    end
    for _,cache in ipairs({attack_reservations,attack_failed_approaches,movement_idle}) do
        for id in pairs(cache) do if not seen[id] then cache[id]=nil end end
    end
end
function MRIP_MovementAction(sprite,action)
    if not pass_mode or not sprite or not action then return end
    settle_action(sprite,action)
    if sprite:getPortraitIndex()>=0 and action.m_actionID==23 then
        attack_reservations[sprite.m_id]=nil;attack_failed_approaches[sprite.m_id]=nil
        movement_idle[sprite.m_id]=nil
    end
end
function MRIP_TogglePass()
    if not MRIP_TraceEnabled then feedback('movement unavailable; check EEex log');return end
    if active then MRIP_Stop('movement-mode-change') end
    if pass_mode then
        movement_disable('hotkey')
    else
        local now=clock()
        if not now then feedback('game clock unavailable');return end
        settle_reset(false);attack_reset();movement_idle={};maintenance_clock=nil;movement_last_clock=now
        pass_mode=true
        movement_generation()
        movement_party(now)
        EEex_Write32(buffer+28,now)
        EEex_Write32(buffer+56,1)
        log('MOVEMENT_ENABLED scope=continuous')
    end
    movement_status()
    feedback(pass_mode and 'allied movement ON' or 'movement OFF')
end
function MRIP_Start(label)
    if not MRIP_TraceEnabled then feedback('movement unavailable; check EEex log');return false end
    if active then MRIP_Stop('restarted') end
    if EEex_Read32(buffer+4)~=0 then feedback('diagnostic capture finishing; try again');return false end
    local now=clock()
    if not now then feedback('game clock unavailable');return false end
    drain();run=run+1;started_ms=now
    movement_generation();EEex_Write32(buffer+28,now)
    for slot=0,5 do
        local sprite=EEex_Sprite_GetInPortrait(slot)
        EEex_Write32(buffer+32+slot*4,sprite and sprite.m_id or -1)
    end
    previous_party={};last_sample,last_summary=-1,now
    pass_checks,pass_allowed,pass_denied=0,0,0;pass_reasons={}
    route_reset();yield_reset()
    active=true
    log('START label='..tostring(label or 'hotkey'):gsub('[%c]',' ')..'; automatic capture limit=20000ms')
    log('PASS_RUN enabled='..tostring(pass_mode))
    log('ATTACK_RUN enabled='..tostring(MRIP_AttackSpacingEnabled))
    log('PREFERENCE_RUN enabled='..tostring(MRIP_PreferenceEnabled))
    movement_status()
    for id,r in pairs(attack_failed_approaches) do
        log(string.format('ATTACK_HANDOFF_STATE mover=%d target=%d scope=engagement',id,r.target))
    end
    snapshot('before-order');summary();EEex_Write32(buffer,1)
    feedback('run '..run..' recording for 20 seconds; movement '..(pass_mode and 'ON' or 'OFF'))
    return true
end
function MRIP_Snapshot()
    with_diagnostics(function()
        drain();movement_status();snapshot(active and 'during-run' or 'readiness-check')
    end)
    feedback('snapshot recorded for run '..run..'; movement '..(pass_mode and 'ON' or 'OFF'))
end
function MRIP_Stop(reason)
    if not active then return end
    EEex_Write32(buffer,0);active=false
    with_diagnostics(function()
        drain();snapshot('after-run');summary();pass_summary();route_summary();yield_summary()
        log('END reason='..tostring(reason or 'hotkey'))
        movement_status()
    end)
    feedback('recording ended; movement '..(pass_mode and 'ON' or 'OFF'))
end
function MRIP_Tick()
    local ok,err=pcall(function()
        drain()
        local now=pass_mode and movement_ready() or clock()
        if pass_mode and now then
            EEex_Write32(buffer+28,now);movement_party(now);settle_tick(now)
        end
        if not active then return end
        if not now or now<started_ms then MRIP_Stop('clock-reset');return end
        EEex_Write32(buffer+28,now)
        if now-started_ms>=20000 then MRIP_Stop('timeout');return end
        if last_sample<0 or now-last_sample>=50 then
            last_sample=now
            for slot=0,5 do
                local sprite=EEex_Sprite_GetInPortrait(slot)
                local value=sprite and describe(sprite) or 'slot='..slot..' empty'
                if previous_party[slot]~=value then previous_party[slot]=value;log('AUTO '..value) end
            end
        end
        if now-last_summary>=1000 then last_summary=now;summary() end
    end)
    if not ok then
        movement_disable('tick-error')
        if buffer then EEex_Write32(buffer,0) end
        active=false
        log('ERROR tick '..tostring(err));feedback('allied movement disabled after an error; check EEex log')
    end
end

local snapshot_policy=(function()
-- Reuse the accepted occupancy predicate on a search's private copy.
-- There is no preferred route, action condition, or persistent actor cache.
local P={}
function P.plan(q,occupancy)
    if q.width<1 or q.width>320 or q.height<1 or q.height>320 then return nil,'bounds' end
    if #q.actors>256 then return nil,'actor-budget' end
    local ids,keys,seen={},{},{}
    for _,a in ipairs(q.actors) do
        if ids[a.id] then return nil,'duplicate-actor' end
        ids[a.id]=true
        if a.personal<0 or a.personal>255 or a.ea<0 or a.ea>255
            or a.x<0 or a.y<0 or a.x>=q.width*16 or a.y>=q.height*12
            or not ((a.painted==1 and a.removed==0) or (a.painted==0 and a.removed==1)) then
            return nil,'unknown-actor'
        end
        if occupancy.ally(a.ea) and a.painted==1 then
            local radius=math.max(0,math.floor((a.personal-1)/2))
            local cx,cy=math.floor(a.x/16),math.floor(a.y/12)
            local left,right=math.max(0,cx-radius),math.min(q.width-1,cx+radius)
            local top,bottom=math.max(0,cy-radius),math.min(q.height-1,cy+radius)
            if (right-left+1)*(bottom-top+1)>4096 then return nil,'cell-budget' end
            for y=top,bottom do for x=left,right do
                local key=y*q.width+x
                if not seen[key] and occupancy.footprint(a,x,y) then
                    seen[key]=true;keys[#keys+1]=key
                    if #keys>4096 then return nil,'cell-budget' end
                end
            end end
        end
    end
    table.sort(keys)
    local patches,kept={},0
    local cells={width=q.width,height=q.height,actors=q.actors,read=q.read_live}
    for _,key in ipairs(keys) do
        local x,y=key%q.width,math.floor(key/q.width)
        -- This already verifies BOTH paint counters against every enumerated
        -- footprint, counter overflow, static/door bits and non-allied bodies,
        -- including neutrals/enemies whose paint is temporarily absent.
        if occupancy.cell(cells,x,y) then
            local live,private=q.read_live(x,y),q.read_snapshot(x,y)
            if private<0 or private>255 then return nil,'snapshot-byte' end
            local bits=private%2+math.floor(private/128)*128
            if bits==live%2+math.floor(live/128)*128
                and math.floor(private/2)%8<=math.floor(live/2)%8
                and math.floor(private/16)%8<=math.floor(live/16)%8 then
                if private~=bits then patches[#patches+1]={key=key,before=private,after=bits,live=live} end
            else kept=kept+1 end
        else kept=kept+1 end
    end
    return patches,'verified-allied',kept,#keys
end
return P

end)()
-- SearchThreadMain is invoked from CChitin::Update in this pinned executable.
-- The native wrapper requires the recorded world-update thread before Lua.
-- All storage below lasts only for this synchronous callback.
local function snapshot_select(request,private)
    if not movement_ready() then return false,'movement-off' end
    if not request or request==0 or not private or private==0 then return false,'pointer' end
    if EEex_ReadU8(request)~=1 or EEex_Read32(request+4)~=0 then return false,'request-kind' end
    local chitin=EEex_ReadPtr(base+0x667560)
    if chitin==0 or EEex_ReadU8(chitin+0x2C9)~=0 then return false,'network-session' end
    local mover=EEex_GameObject_Get(EEex_Read32(request+0x38))
    if not mover or not EEex_GameObject_IsSprite(mover,true) or not mover.m_pArea then return false,'mover' end
    mover=EEex_CastUD(mover,'CGameSprite')
    local mp,area=EEex_UDToPtr(mover),mover.m_pArea
    local ap=EEex_UDToPtr(area)
    local bitmap=ap+0xA60
    if EEex_ReadPtr(mp+0x47F0)~=request or EEex_ReadPtr(request+0x18)~=bitmap
        or EEex_ReadPtr(bitmap+0x128)~=private then return false,'ownership' end
    local m=actor_record(mover,{})
    if not attack_policy.ally(m.ea) or m.personal~=3 then return false,'mover-size-or-allegiance' end
    local live=EEex_ReadPtr(bitmap+0x120)
    local width,height=EEex_Read32(bitmap+0x138),EEex_Read32(bitmap+0x13C)
    if live==0 or private==live or width<1 or width>320 or height<1 or height>320 then return false,'bitmap' end
    local actors,identities={},{}
    area:forAllOfTypeInRange(m.x,m.y,CAIObjectType.ANYONE,32767,function(object)
        if not object then error('unresolved snapshot area object') end
        if EEex_GameObject_IsSprite(object,true) then
            if #actors>=256 then error('snapshot actor budget') end
            local sprite=EEex_CastUD(object,'CGameSprite')
            if not sprite.m_pArea or EEex_UDToPtr(sprite.m_pArea)~=ap then error('snapshot foreign area') end
            local a=actor_record(sprite,{})
            if identities[a.id] then error('snapshot duplicate identity') end
            identities[a.id]=EEex_UDToPtr(sprite);actors[#actors+1]=a
        end
    end,0,0)
    if identities[m.id]~=mp then return false,'incomplete-enumeration' end
    for slot=0,5 do
        local s=EEex_Sprite_GetInPortrait(slot)
        if s and s.m_pArea and EEex_UDToPtr(s.m_pArea)==ap and identities[s.m_id]~=EEex_UDToPtr(s) then
            return false,'missing-party-actor'
        end
    end
    local patches,reason,kept,checked=snapshot_policy.plan({width=width,height=height,actors=actors,
        read_live=function(x,y) return EEex_ReadU8(live+y*width+x) end,
        read_snapshot=function(x,y) return EEex_ReadU8(private+y*width+x) end},attack_policy)
    if not patches then return false,reason end
    -- Verify the entire plan before the first write. Native removals have
    -- already finished: clearing verified friendly-only cells is idempotent,
    -- so selected actors and overlapping bodies cannot be subtracted twice.
    if EEex_ReadU8(request)~=1 or EEex_ReadPtr(mp+0x47F0)~=request
        or EEex_ReadPtr(bitmap+0x120)~=live or EEex_ReadPtr(bitmap+0x128)~=private
        or EEex_Read32(bitmap+0x138)~=width or EEex_Read32(bitmap+0x13C)~=height then return false,'changed-context' end
    for _,p in ipairs(patches) do
        if EEex_ReadU8(live+p.key)~=p.live or EEex_ReadU8(private+p.key)~=p.before then return false,'changed-cell' end
    end
    for _,p in ipairs(patches) do EEex_Write8(private+p.key,p.after) end
    -- The installed game Lua formatter cannot format a pointer with %X.
    if active then log(string.format('SEARCH_SNAPSHOT mover=%d request=%s actors=%d checked=%d cleared=%d kept=%d',
        m.id,tostring(request),#actors,checked,#patches,kept)) end
    return #patches>0,reason
end
function MRIP_SearchSnapshot(request,private)
    local ok,changed,reason=pcall(snapshot_select,request,private)
    if not ok then log('SEARCH_SNAPSHOT_ERROR fallback='..tostring(changed));return false end
    if active and not changed then log('SEARCH_SNAPSHOT_KEEP reason='..tostring(reason)) end
    return changed
end

local function snapshot_body()
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne snapshot_fast_exit
        push rcx
        #STACK_MOD(8)
        mov rcx, qword ptr gs:[48h]
        test ecx, ecx
        jz snapshot_wrong_thread
        cmp ecx, dword ptr [rax+60]
        jne snapshot_wrong_thread
        pop rcx
        #STACK_MOD(-8)
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(152)
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
    ]]},EEex_GenLuaCall('MRIP_SearchSnapshot',{
        args={
            function(offset) return {'mov qword ptr [rsp+#$(1)], rdi #ENDL',{offset}} end,
            function(offset) return {'lea rax, [rbp-30h] #ENDL mov qword ptr [rsp+#$(1)], rax #ENDL',{offset}} end,
        },returnType=EEex_LuaCallReturnType.Boolean,
    }),{[[
        call_error:
        movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax, qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-8)]
        #DESTROY_SHADOW_SPACE
        jmp snapshot_flags
        snapshot_wrong_thread:
        #STACK_MOD(8)
        pop rcx
        #STACK_MOD(-8)
        snapshot_fast_exit:
        pop rax
        snapshot_flags:
        popfq
        #STACK_MOD(-8)
    ]]}})
end

local preference_policy=(function()
-- Offline prototype: evaluate actual native route alternatives, never actor collision.
-- All coordinates are grid cells; world distances account for16x12 cell dimensions.
local P={corridor_limit=50}
local function distance(a,b)
    local dx,dy=(a.x-b.x)*16,(a.y-b.y)*12
    return math.sqrt(dx*dx+dy*dy)
end
local function segment(p,a,b)
    local ax,ay=a.x*16,a.y*12
    local dx,dy=(b.x-a.x)*16,(b.y-a.y)*12
    local d=dx*dx+dy*dy
    local t=d>0 and math.max(0,math.min(1,((p.x*16-ax)*dx+(p.y*12-ay)*dy)/d)) or 0
    return math.sqrt((p.x*16-ax-t*dx)^2+(p.y*12-ay-t*dy)^2),t
end
function P.length(path)
    local n=0
    for i=2,#path do n=n+distance(path[i-1],path[i]) end
    return n
end
local function valid(path,q)
    if type(path)~='table' or #path<2 or #path>256 then return false end
    for _,p in ipairs(path) do
        if type(p.x)~='number' or type(p.y)~='number' or p.x%1~=0 or p.y%1~=0
            or p.x<0 or p.y<0 or p.x>=q.width or p.y>=q.height then return false end
    end
    return true
end
local function same(a,b) return a.x==b.x and a.y==b.y end
local function samples(path,fn)
    -- Include every integer-grid crossing and diagonal corner side cells.
    for i=2,#path do
        local a,b=path[i-1],path[i]
        local dx,dy=b.x-a.x,b.y-a.y
        local nx,ny=math.abs(dx),math.abs(dy)
        local sx,sy=dx<0 and -1 or 1,dy<0 and -1 or 1
        local x,y,ix,iy=a.x,a.y,0,0
        if not fn(x,y) then return false end
        while ix<nx or iy<ny do
            local decision=(1+2*ix)*ny-(1+2*iy)*nx
            if decision==0 then
                if not fn(x+sx,y) or not fn(x,y+sy) then return false end
                x,y,ix,iy=x+sx,y+sy,ix+1,iy+1
            elseif decision<0 then x,ix=x+sx,ix+1 else y,iy=y+sy,iy+1 end
            if not fn(x,y) then return false end
        end
    end
    return true
end
function P.choose(q)
    local base,alt=q.baseline,q.preferred
    if not valid(base,q) then return nil,'invalid-baseline' end
    if not q.reached_baseline then return base,'baseline-unreached' end
    if not q.reached_preferred or not valid(alt,q) then return base,'preferred-unreached' end
    if not same(base[1],alt[1]) or not same(base[#base],alt[#alt]) then return base,'endpoints' end
    local length,other=P.length(base),P.length(alt)
    if other>length*1.08+0.000001 or other-length>32.000001 then return base,'travel-budget' end
    if not samples(alt,function(x,y) return q.open(x,y) end) then return base,'unsafe-segment' end
    local progress=-1
    local prefix={0}
    for i=2,#base do prefix[i]=prefix[i-1]+distance(base[i-1],base[i]) end
    local function project(p)
        local nearest,at=math.huge,nil
        for i=2,#base do
            local d,t=segment(p,base[i-1],base[i])
            if d<nearest then nearest,at=d,prefix[i-1]+t*(prefix[i]-prefix[i-1]) end
        end
        return nearest,at
    end
    if not samples(alt,function(x,y) return project({x=x,y=y})<=P.corridor_limit+0.000001 end) then
        return base,'different-corridor'
    end
    for _,p in ipairs(alt) do
        local nearest,at=project(p)
        if at+0.000001<progress then return base,'backtracking' end
        progress=at
    end
    local function overlap(path)
        local visited,total={},0
        samples(path,function(x,y)
            local k=y*q.width+x
            if not visited[k] then visited[k]=true;total=total+(q.ally(x,y) and 1 or 0) end
            return true
        end)
        return total
    end
    local before,after=overlap(base),overlap(alt)
    if after>=before then return base,'no-spacing-benefit' end
    return alt,'preferred', {baseline_length=length,preferred_length=other,
        baseline_overlap=before,preferred_overlap=after}
end
P.samples=samples
return P

end)()
local shared_policy=(function()
-- Numeric delivery snapshots and bounded spatial preference; no borrowed buffers.
local S={band=18,min_length=160,max_age=10000}
local function copy(points)
    local result={}
    for _,p in ipairs(points) do result[#result+1]={x=p.x,y=p.y} end
    return result
end
local function distance(p,a,b)
    local dx,dy=(b.x-a.x)*16,(b.y-a.y)*12
    local t=dx*dx+dy*dy
    t=t>0 and math.max(0,math.min(1,((p.x-a.x)*16*dx+(p.y-a.y)*12*dy)/t)) or 0
    return math.sqrt(((p.x-a.x)*16-t*dx)^2+((p.y-a.y)*12-t*dy)^2)
end
local function identity(a,b)
    return a and b and a.slot==b.slot and a.id==b.id and a.owner==b.owner and a.area==b.area
        and a.gx==b.gx and a.gy==b.gy and a.state==b.state and a.base_state==b.base_state and a.epoch==b.epoch
end
function S.cache()
    local slots={}
    local C={}
    function C.has(slot) return slots[slot]~=nil end
    function C.reset(id)
        for slot,r in pairs(slots) do if not id or r.context.id==id then slots[slot]=nil end end
    end
    function C.stage(c,points,now)
        if not c or c.slot<0 or c.slot>5 or #points<2 or #points>256 then return false end
        local saved={};for k,v in pairs(c) do saved[k]=v end
        slots[c.slot]={context=saved,points=copy(points),since=now,pending=true}
        return true
    end
    function C.replace(c,points)
        local r=c and slots[c.slot]
        if not r or not r.pending or not identity(r.context,c) or #points<2 or #points>256 then return false end
        r.points=copy(points);return true
    end
    function C.bind(c,now)
        local r=c and slots[c.slot]
        if not r then return false end
        if not r.pending or not identity(r.context,c) or c.action~=23 or c.path==0
            or c.count~=#r.points or c.cursor~=1 or now<r.since or now-r.since>100 then
            slots[c.slot]=nil;return false
        end
        r.pending=false;r.path=c.path;r.cursor=1
        return true
    end
    function C.remaining(c,now)
        local r=c and slots[c.slot]
        if not r then return nil end
        if r.pending or not identity(r.context,c) or c.action~=23 or c.path==0 or c.path~=r.path
            or c.count~=#r.points or c.cursor<r.cursor or c.cursor<1 or c.cursor>=#r.points
            or now<r.since or now-r.since>S.max_age
            or distance({x=c.x/16,y=c.y/12},r.points[c.cursor],r.points[c.cursor+1])>50 then
            slots[c.slot]=nil;return nil
        end
        r.cursor=c.cursor
        local points={{x=c.x/16,y=c.y/12}}
        for i=c.cursor+1,#r.points do points[#points+1]={x=r.points[i].x,y=r.points[i].y} end
        return points
    end
    return C
end
function S.map(q)
    local first,last=q.baseline[1],q.baseline[#q.baseline]
    local dx,dy=(last.x-first.x)*16,(last.y-first.y)*12
    local length=math.sqrt(dx*dx+dy*dy)
    if length<S.min_length then return nil,'short-route' end
    local map,cells,steps,peers,work,projected={},0,0,0,0,{}
    for _,route in ipairs(q.peers) do
        local used=false
        for i=2,#route do
            local a,b=route[i-1],route[i]
            local ux,uy=(b.x-a.x)*16,(b.y-a.y)*12
            local segment_length=math.sqrt(ux*ux+uy*uy)
            if segment_length>0 and (ux*dx+uy*dy)/(segment_length*length)>=0.85 then
                local n=math.max(1,math.ceil(math.max(math.abs(b.x-a.x),math.abs(b.y-a.y))))
                for j=0,n do
                    steps=steps+1;if steps>4096 then return nil,'shared-route-step-budget' end
                    if q.clock and steps%32==0 then
                        local now=q.clock()
                        if now-q.started>2 or q.overall_started and now-q.overall_started>8 then return nil,'shared-route-time-budget' end
                    end
                    local p={x=a.x+(b.x-a.x)*j/n,y=a.y+(b.y-a.y)*j/n}
                    for y=math.floor(p.y)-2,math.floor(p.y)+2 do
                        for x=math.floor(p.x)-2,math.floor(p.x)+2 do
                            if x>=0 and y>=0 and x<q.width and y<q.height
                                and distance({x=x,y=y},a,b)<=S.band then
                                local key=y*q.width+x
                                local nearest=projected[key]
                                if not nearest then
                                    nearest=math.huge
                                    for k=2,#q.baseline do
                                        work=work+1;if work>32768 then return nil,'shared-route-projection-budget' end
                                        nearest=math.min(nearest,distance({x=x,y=y},q.baseline[k-1],q.baseline[k]))
                                    end
                                    projected[key]=nearest
                                end
                                if nearest<=50 then
                                    if not map[key] then
                                        cells=cells+1;if cells>2048 then return nil,'shared-route-cell-budget' end
                                        map[key]=1;used=true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if used then peers=peers+1 end
    end
    if q.clock then
        local now=q.clock()
        if now-q.started>2 or q.overall_started and now-q.overall_started>8 then return nil,'shared-route-time-budget' end
    end
    if peers==0 then return nil,'no-parallel-peer' end
    return map,nil,{peers=peers,cells=cells,steps=steps}
end
-- Remove verified friendly counters in a private snapshot; keep static/unknown
-- cells hard, and keep neutral/hostile bodies hard during unpainted phases.
function S.private(q,footprint,allied)
    assert(type(allied)=='function','shared query allegiance predicate')
    local changes,cells,work={}, {},0
    local function expired()
        if not q.clock then return false end
        local now=q.clock()
        return now-q.started>2 or q.overall_started and now-q.overall_started>8
    end
    -- Aggregate verified actor contributions once. No per-cell actor rescan.
    for _,a in ipairs(q.actors) do
        if not ((a.painted==1 and a.removed==0) or (a.painted==0 and a.removed==1))
            or a.personal<1 or a.personal>15 then return nil,'shared-paint-phase' end
        local radius=math.max(0,math.floor((a.personal-1)/2))
        local ax,ay=math.floor(a.x/16),math.floor(a.y/12)
        for y=math.max(0,ay-radius),math.min(q.height-1,ay+radius) do
            for x=math.max(0,ax-radius),math.min(q.width-1,ax+radius) do
                work=work+1;if work>4096 then return nil,'shared-paint-budget' end
                if work%32==0 and expired() then return nil,'shared-paint-time-budget' end
                local key=y*q.width+x
                if footprint(a,x,y) then
                    local c=cells[key]
                    if not c then c={low=0,high=0,remove=0,hostile=false};cells[key]=c end
                    if not allied(a.ea) then c.hostile=true end
                    if a.painted==1 and a.removed==0 then
                        if a.category==0 then c.high=c.high+1 else c.low=c.low+1 end
                        if allied(a.ea) then c.remove=c.remove+(a.category==0 and 16 or 2) end
                    end
                end
            end
        end
    end
    local checked=0
    for key,c in pairs(cells) do
        checked=checked+1
        if checked%32==0 and expired() then return nil,'shared-paint-time-budget' end
        local raw=q.read(key%q.width,math.floor(key/q.width))
        if raw>=0 and raw<=255 and raw<128 and raw%2==0 then
            if c.low>=8 or c.high>=8 or c.low~=math.floor(raw/2)%8 or c.high~=math.floor(raw/16)%8 then
                return nil,'shared-paint-unverified'
            end
            changes[key]=c.hostile and 1 or raw-c.remove
        end
    end
    if expired() then return nil,'shared-paint-time-budget' end
    return changes,nil,{visits=work,cells=checked}
end
return S

end)()
local shared_native=(function()
-- One native cost wrapper at five audited calls. Ordinary searches tail-call
-- the original function; no Lua runs during expansion or smoothing.
local N={}
function N.call_patch(site,target)
    -- AsmTK may prefix CALL with REX (40 E8), occupying six bytes. These
    -- audited native call sites have exactly five bytes; encode rel32 directly.
    local delta=target-site-5
    assert(delta==math.floor(delta) and delta>=-2147483648 and delta<=2147483647,
        'shared cost target outside rel32 range')
    if delta<0 then delta=delta+4294967296 end
    local bytes={232}
    for i=1,4 do bytes[#bytes+1]=delta%256;delta=math.floor(delta/256) end
    return {'.DB '..table.concat(bytes,',')..' #ENDL'}
end
function N.cost()
    return [[
        push r10
        push r11
        mov r10, #L(MRIP_PlannerState)
        cmp dword ptr [r10], 1
        jne shared_cost_original
        cmp dword ptr [r10+16], 1
        jne shared_cost_original
        cmp dword ptr [r10+12], 1
        jne shared_cost_original
        cmp dword ptr [r10+4], 1
        jne shared_cost_original
        mov r11, qword ptr gs:[48h]
        cmp r11d, [r10+8]
        jne shared_cost_original
        cmp rcx, [r10+32]
        jne shared_cost_original
        mov r11, #L(MRIP_ring)
        cmp dword ptr [r11+56], 1
        jne shared_cost_original
        sub rsp, 88h
        mov [rsp+20h], rdx
        mov r10, [rsp+90h]
        mov r11, [rsp+88h]
        call #L(MRIP_SnapshotCost)
        mov [rsp+28h], rcx
        mov [rsp+30h], rdx
        mov [rsp+38h], r8
        mov [rsp+40h], r9
        mov [rsp+48h], rax
        mov [rsp+50h], r10
        mov [rsp+58h], r11
        pushfq
        pop qword ptr [rsp+60h]
        mov r10, #L(MRIP_PlannerState)
        inc dword ptr [r10+52]
        cmp al, 128
        ja shared_cost_done
        mov rdx, [rsp+20h]
        mov ecx, edx
        test ecx, ecx
        js shared_cost_done
        cmp ecx, [r10+20]
        jge shared_cost_done
        shr rdx, 20h
        test edx, edx
        js shared_cost_done
        cmp edx, [r10+24]
        jge shared_cost_done
        imul edx, [r10+20]
        add edx, ecx
        mov r11, [r10+40]
        test r11, r11
        jz shared_cost_done
        cmp byte ptr [r11+rdx], 1
        jne shared_cost_done
        inc al
        mov [rsp+48h], al
        inc dword ptr [r10+48]
        shared_cost_done:
        mov rcx, [rsp+28h]
        mov rdx, [rsp+30h]
        mov r8, [rsp+38h]
        mov r9, [rsp+40h]
        mov rax, [rsp+48h]
        mov r10, [rsp+50h]
        mov r11, [rsp+58h]
        push qword ptr [rsp+60h]
        popfq
        lea rsp, [rsp+88h]
        lea rsp, [rsp+16]
        ret
        shared_cost_original:
        pop r11
        pop r10
        jmp #L(MRIP_SnapshotCost)
    ]]
end
function N.delivered()
    return EEex_FlattenTable({{[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_PlannerState)
        cmp dword ptr [rax], 1
        jne shared_delivery_exit
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne shared_delivery_exit
        push rcx
        #STACK_MOD(8)
        mov rcx, qword ptr gs:[48h]
        cmp ecx, dword ptr [rax+60]
        jne shared_delivery_wrong_thread
        pop rcx
        #STACK_MOD(-8)
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(192)
        mov [rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov [rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov [rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov [rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov [rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
    ]]},EEex_GenLuaCall('MRIP_PreferenceDelivered',{
        args={function(o) return {'mov [rsp+#$(1)],rbx #ENDL',{o}},'CGameSprite' end},
    }),{[[
        call_error:
        movdqu xmm5,[rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4,[rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3,[rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2,[rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1,[rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0,[rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11,[rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10,[rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9,[rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8,[rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx,[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx,[rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-8)]
        #DESTROY_SHADOW_SPACE
        jmp shared_delivery_flags
        shared_delivery_wrong_thread:
        #STACK_MOD(16)
        pop rcx
        #STACK_MOD(-8)
        shared_delivery_exit:
        pop rax
        #STACK_MOD(-8)
        shared_delivery_flags:
        popfq
        #STACK_MOD(-8)
    ]]}})
end
return N

end)()
local preference_diagnostics=(function()
-- Read-only rejection reports. This module cannot select or modify a route.
local D={}
local function project(p,path)
    local nearest,at,index,tbest=math.huge,0,0,0
    local prefix=0
    for i=2,#path do
        local a,b=path[i-1],path[i]
        local dx,dy=(b.x-a.x)*16,(b.y-a.y)*12
        local squared=dx*dx+dy*dy
        local t=squared>0 and math.max(0,math.min(1,((p.x-a.x)*16*dx+(p.y-a.y)*12*dy)/squared)) or 0
        local x,y=a.x*16+t*dx,a.y*12+t*dy
        local distance=math.sqrt((p.x*16-x)^2+(p.y*12-y)^2)
        if distance<nearest then nearest,at,index,tbest=distance,prefix+t*math.sqrt(squared),i-1,t end
        prefix=prefix+math.sqrt(squared)
    end
    return nearest,at,index,tbest
end
function D.occupancy(raw,actors,x,y,footprint)
    local low,high,hostiles,unknown,phases=0,0,{},{},{}
    local hostile_count,unknown_count=0,0
    for _,a in ipairs(actors) do
        if a.ea>=200 and footprint(a,x,y) then
            hostile_count=hostile_count+1;if #hostiles<8 then hostiles[#hostiles+1]=a.id end
        end
        if a.painted==1 and a.removed==0 then
            if footprint(a,x,y) then
                if a.category==0 then high=high+1 else low=low+1 end
            end
        elseif a.painted~=0 or a.removed~=1 then
            unknown_count=unknown_count+1
            if #unknown<8 then
                unknown[#unknown+1]=a.id
                phases[#phases+1]=a.id..':'..tostring(a.painted)..','..tostring(a.removed)..','..tostring(a.category)
            end
        end
    end
    return {raw=raw,static=raw>=128 or raw%2~=0,expected_low=low,expected_high=high,
        actual_low=math.floor(raw/2)%8,actual_high=math.floor(raw/16)%8,
        hostile_count=hostile_count,hostile_ids=table.concat(hostiles,','),
        unknown_phase_count=unknown_count,unknown_phase_ids=table.concat(unknown,','),unknown_phase_values=table.concat(phases,';')}
end
local function cell_text(c)
    if not c then return 'cell=none' end
    local text='cell='..c.x..','..c.y..' terrain_cost='..tostring(c.cost)..' occupancy_open='..tostring(c.occupancy_open)
        ..' observed='..tostring(c.observed)
    if c.occupancy then
        for _,key in ipairs({'raw','static','expected_low','expected_high','actual_low','actual_high',
            'hostile_count','hostile_ids','unknown_phase_count','unknown_phase_ids','unknown_phase_values'}) do
            local v=c.occupancy[key];text=text..' '..key..'='..tostring(v=='' and 'none' or v)
        end
    end
    return text
end
function D.report(q)
    local began=q.clock()
    local samples=0
    local first_corridor,baseline_failure
    local corridor_status='not-tested'
    local baseline_status='clear'
    local function budget()
        samples=samples+1
        return samples<=1024 and q.clock()-began<=2
    end
    if q.reason=='different-corridor' then
        corridor_status='not-found'
        q.policy.samples(q.preferred,function(x,y)
            if not budget() then corridor_status='unknown-budget';return false end
            local distance,at,index,t=project({x=x,y=y},q.baseline)
            if distance>q.policy.corridor_limit+0.000001 then
                first_corridor={x=x,y=y,distance=distance,at=at,index=index,t=t}
                corridor_status='found'
                return false
            end
            return true
        end)
    end
    local completed=q.policy.samples(q.baseline,function(x,y)
        if not budget() then baseline_status='unknown-budget';return false end
        local c=q.check(x,y)
        if not c then baseline_status='unknown-cell-budget';return false end
        if not c.open then baseline_status='blocked';baseline_failure=c;return false end
        return true
    end)
    if not completed and baseline_status=='clear' then baseline_status='unknown' end
    -- Build reports before logging, so an observer exception cannot affect policy.
    local lines={}
    local prefix='mover='..q.mover..' diagnostic='..q.id
    lines[#lines+1]='PREFERENCE_REJECTION '..prefix..' reason='..q.reason..' width='..q.width..' height='..q.height
        ..' baseline_length='..q.policy.length(q.baseline)..' preferred_length='..q.policy.length(q.preferred)
        ..' baseline_validation='..baseline_status..' diagnostic_samples='..samples
        ..' corridor_validation='..corridor_status
        ..' diagnostic_new_cells='..q.new_cells()..' diagnostic_ms='..(q.clock()-began)
    for _,route in ipairs({{'baseline',q.baseline},{'candidate',q.preferred}}) do
        local chunks=math.ceil(#route[2]/64)
        for start=1,#route[2],64 do
            local points={}
            for i=start,math.min(start+63,#route[2]) do points[#points+1]=route[2][i].x..','..route[2][i].y end
            lines[#lines+1]='PREFERENCE_PATH '..prefix..' role='..route[1]..' chunk='..math.floor((start-1)/64+1)
                ..' chunks='..chunks..' count='..#route[2]..' points='..table.concat(points,';')
        end
    end
    lines[#lines+1]='PREFERENCE_CELL '..prefix..' role=candidate '..cell_text(q.first_failure)
    lines[#lines+1]='PREFERENCE_CELL '..prefix..' role=baseline '..cell_text(baseline_failure)
    if first_corridor then
        local c=first_corridor
        lines[#lines+1]='PREFERENCE_CORRIDOR '..prefix..' cell='..c.x..','..c.y..' distance_px='..c.distance
            ..' limit_px='..q.policy.corridor_limit..' projection_px='..c.at..' baseline_segment='..c.index..' segment_t='..c.t
    end
    return lines
end
return D

end)()
local planner_native=(function()
-- One synchronous, bounded query. Finished candidate is COPIED then freed;
-- the caller's normal route and native pool ownership are never transferred.
local function planner_query_body()
    return [[
        push rbx
        push rsi
        push rdi
        push r12
        push r13
        push r14
        push r15
        sub rsp, 0D0h
        mov rbx, rcx
        mov edx, 1
        lea r8, [rsp+78h]
        call #L(Hardcoded_lua_tointegerx)
        cmp dword ptr [rsp+78h], 0
        je preference_return
        test rax, rax
        jz preference_return
        mov r15, rax
        mov dword ptr [r15+48], 0
        mov dword ptr [r15+52], 0
        mov dword ptr [r15+56], -1
        mov r14, #L(MRIP_PlannerState)
        cmp dword ptr [r14], 1
        jne preference_return
        mov rax, qword ptr gs:[48h]
        cmp eax, dword ptr [r14+8]
        jne preference_return
        cmp dword ptr [r14+4], 0
        jne preference_return
        xor eax, eax
        mov ecx, 1
        lock cmpxchg dword ptr [r14+12], ecx
        jne preference_return
        mov rax, #L(MRIP_PoolReferences)
        movzx r12d, word ptr [rax]
        test r12d, r12d
        jz preference_unlock
        cmp r12d, 0FFFEh
        ja preference_unlock
        mov rax, #L(MRIP_PoolPointer)
        mov rdi, [rax]
        test rdi, rdi
        jz preference_unlock
        mov rax, #L(MRIP_PoolCapacity)
        mov esi, [rax]
        cmp dword ptr [r15+60], 2048
        jne preference_unlock
        cmp esi, 2048
        jl preference_unlock
        mov rcx, [r15]
        test rcx, rcx
        jz preference_unlock
        mov rdx, [r15+8]
        test rdx, rdx
        jz preference_unlock
        mov r8, [r15+16]
        test r8, r8
        jz preference_unlock
        mov rdx, [r15+24]
        test rdx, rdx
        jz preference_unlock
        mov r8, [r15+32]
        test r8, r8
        jz preference_unlock
        cmp qword ptr [r15+40], 0
        je preference_unlock
        lea rcx, [rsp+80h]
        call #L(MRIP_PlannerConstruct)
        mov dword ptr [r14+16], 0
        mov dword ptr [r14+48], 0
        mov dword ptr [r14+52], 0
        cmp qword ptr [r15+64], 0
        je preference_cost_ready
        mov eax, [r15+72]
        cmp eax, 1
        jl preference_destruct
        cmp eax, 320
        jg preference_destruct
        mov [r14+20], eax
        mov eax, [r15+76]
        cmp eax, 1
        jl preference_destruct
        cmp eax, 320
        jg preference_destruct
        mov [r14+24], eax
        mov rax, [r15]
        mov [r14+32], rax
        mov rax, [r15+64]
        mov [r14+40], rax
        mov dword ptr [r14+16], 1
        preference_cost_ready:
        mov byte ptr [rsp+70h], 0
        mov dword ptr [rsp+20h], 2048
        mov dword ptr [rsp+28h], 2048
        mov rax, [r15]
        mov [rsp+30h], rax
        lea rax, [rsp+70h]
        mov [rsp+38h], rax
        mov dword ptr [rsp+40h], 0
        mov qword ptr [rsp+48h], 0
        mov rdx, [r15+8]
        mov r8, [r15+16]
        mov r9d, 1
        lea rcx, [rsp+80h]
        call #L(MRIP_PlannerFind)
        mov dword ptr [r14+16], 0
        cmp ax, 1
        sete al
        movzx eax, al
        mov [r15+52], eax
        lea rcx, [rsp+80h]
        lea rdx, [rsp+78h]
        call #L(MRIP_PlannerGet)
        mov r13, rax
        test r13, r13
        jz preference_destruct
        movzx r8d, word ptr [rsp+78h]
        cmp r8d, 2
        jl preference_free
        cmp r8d, 256
        ja preference_free
        mov [r15+48], r8d
        shl r8d, 2
        mov rcx, [r15+40]
        mov rdx, r13
        call #L(MRIP_PlannerCopy)
        mov dword ptr [r15+56], 1
        preference_free:
        mov rcx, r13
        call #L(MRIP_PlannerFree)
        preference_destruct:
        lea rcx, [rsp+80h]
        call #L(MRIP_PlannerDestruct)
        mov rax, #L(MRIP_PoolReferences)
        cmp word ptr [rax], r12w
        jne preference_changed
        mov rax, #L(MRIP_PoolPointer)
        cmp [rax], rdi
        jne preference_changed
        mov rax, #L(MRIP_PoolCapacity)
        cmp [rax], esi
        je preference_unlock
        preference_changed:
        mov dword ptr [r15+56], -8
        mov dword ptr [r15+48], 0
        preference_unlock:
        mov dword ptr [r14+16], 0
        mov qword ptr [r14+32], 0
        mov qword ptr [r14+40], 0
        mov dword ptr [r14+20], 0
        mov dword ptr [r14+24], 0
        mov dword ptr [r14+12], 0
        preference_return:
        xor eax, eax
        add rsp, 0D0h
        pop r15
        pop r14
        pop r13
        pop r12
        pop rdi
        pop rsi
        pop rbx
        ret
    ]]
end

local function planner_depth_body(delta)
    -- EEex concatenates fragments without separators. Keep the atomic update
    -- on its own instruction line even when Lua strips the next leading newline.
    return {[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_PlannerState)
    ]],delta==1 and 'lock inc dword ptr [rax+4] #ENDL' or 'lock dec dword ptr [rax+4] #ENDL',[[
        pop rax
        #STACK_MOD(-8)
        popfq
        #STACK_MOD(-8)
    ]]}
end

return {query=planner_query_body,depth=planner_depth_body}

end)()
local preference_signatures={
{name="planner-constructor",rva=0x225300,bytes={64,83,86,87,65,86,65,87,72,131,236,32,15,183,5,13,38,68,0,69,51,246,102,255,192,73,139,248,102,137,5,253,37,68,0,72,139,242,72,139,217,73,199,199,255,255,255,255,102,131,248,1,15,133,193,0,0,0,72,137,108,36,96,72,141,21,170,148,54,0,189,0,125,0,0,72,141,13,30,144,54,0,68,139,197,232,54,59,30,0,68,139,200,199,68,36,80,0,144,1,0,141,136,48,248,255,255,129,249,176,18,6,0,68,15,71,205,65,139,193,68,137,13,69,97,67,0,153,43,194,209,248,68,139,192,137,5,51,97,67,0,137,5,57,97,67,0,184,103,102,102,102,65,247,233,68,137,68,36,88,193,250,2,139,202,193,233,31,3,209,72,141,76,36,88,137,21,19,97,67,0,72,141,84,36,80,232,1,40,30,0,72,99,200,137,5,104,37,68,0,184,24,0,0,0,72,247,225,73,15,64,199,72,139,200,232,232,35,45,0,139,13,78,37,68,0,72,133,192,72,139,108,36,96,65,15,68,206,72,137,5,51,37,68,0,137,13,53,37,68,0,72,137,115,8,72,139,195,72,137,123,16,76,137,115,32,199,67,40,0,0,255,255,199,3,1,0,0,0,72,131,196,32,65,95,65,94,95,94,91,195,204,204,204,204,204,204,204,204,204,204,204,204,204}},
{name="planner-destructor",rva=0x225430,bytes={72,137,92,36,8,87,72,131,236,32,72,139,217,51,255,72,139,73,32,72,133,201,116,16,232,67,146,35,0,72,137,123,32,199,67,40,0,0,255,255,102,131,45,192,36,68,0,1,117,19,72,139,13,191,36,68,0,232,34,146,35,0,72,137,61,179,36,68,0,72,139,92,36,48,72,131,196,32,95,195}},
{name="planner-search",rva=0x2258B0,bytes={76,139,220,73,137,91,24,85,86,87,65,84,65,85,65,86,65,87,72,129,236,160,0,0,0,72,139,5,8,241,67,0,72,51,196,72,137,132,36,144,0,0,0,72,139,132,36,40,1,0,0,76,139,249,102,15,111,5,34,87,55,0,73,141,75,168,76,139,180,36,16,1,0,0,72,133,192,191,0,144,1,0,77,15,191,233,72,15,69,200,102,68,137,108,36,40,57,188,36,0,1,0,0,139,239,72,137,76,36,120,184,63,1,0,0,15,78,172,36,0,1,0,0,72,199,193,255,255,255,255,57,188,36,8,1,0,0,73,139,216,76,137,116,36,48,15,78,188,36,8,1,0,0,43,66,4,243,65,15,127,67,168,141,52,128,184,4,0,0,0,193,230,6,3,50,73,247,229,72,15,64,193,72,139,200,232,86,30,45,0,72,137,68,36,56,76,139,224,72,133,192,117,10,73,141,68,36,255,233,228,5,0,0,51,192,102,65,59,197,125,74,139,208,69,15,183,205,73,199,194,255,255,255,255,102,15,31,68,0,0,68,139,3,69,59,194,116,26,139,75,4,65,59,202,116,18,184,63,1,0,0,43,193,141,12,128,193,225,6,65,3,200,235,3,65,139,202,66,137,12,34,72,131,195,8,72,131,194,4,73,131,233,1,117,201,73,139,79,32,72,133,201,116,19,232,171,140,35,0,51,192,65,199,71,40,0,0,255,255,73,137,71,32,72,139,13,46,31,68,0,72,199,195,255,255,255,255,72,133,201,116,22,59,61,36,31,68,0,126,71,232,125,140,35,0,51,192,72,137,5,12,31,68,0,72,99,207,184,24,0,0,0,72,247,225,137,61,3,31,68,0,72,15,64,195,72,139,200,232,139,29,45,0,72,137,5,232,30,68,0,72,133,192,117,16,73,139,204,232,67,140,35,0,15,183,195,233,20,5,0,0,73,139,79,8,51,210,65,184,0,128,12,0,65,199,71,24,0,0,0,0,232,2,81,45,0,73,139,79,16,51,210,65,184,0,128,12,0,232,241,80,45,0,72,139,29,162,30,68,0,51,192,69,15,183,205,72,137,92,36,96,77,139,196,139,214,73,139,207,137,115,8,137,67,12,232,44,253,255,255,137,67,16,69,51,237,76,137,43,72,139,211,73,139,71,8,72,99,206,72,137,28,200,73,139,207,232,93,5,0,0,186,137,0,0,0,72,141,13,113,30,68,0,65,184,0,113,2,0,232,150,80,45,0,72,139,148,36,24,1,0,0,15,182,5,75,140,55,0,76,99,199,139,188,36,32,1,0,0,72,99,205,72,137,76,36,104,76,137,68,36,112,56,2,15,132,62,4,0,0,69,51,246,65,141,117,1,144,73,139,87,16,76,139,82,8,76,137,84,36,72,77,133,210,15,132,19,4,0,0,76,59,233,124,36,72,139,5,22,26,68,0,72,139,136,144,16,0,0,131,185,104,148,0,0,0,15,132,243,3,0,0,77,59,232,15,141,234,3,0,0,73,15,191,79,26,72,139,4,202,72,137,66,8,139,214,73,139,71,16,76,137,52,200,69,15,191,71,26,65,15,183,111,24,65,139,192,102,65,255,200,102,69,137,71,26,141,77,255,211,226,59,194,117,8,102,255,205,102,65,137,111,24,102,131,237,2,69,15,183,206,15,183,222,15,136,216,0,0,0,102,144,69,15,183,87,26,15,183,211,102,3,210,68,141,66,1,102,65,59,210,127,91,77,139,95,16,72,15,191,250,73,139,4,251,139,112,16,72,15,191,195,73,139,12,195,59,113,16,125,26,68,15,183,202,102,69,59,194,127,53,73,139,68,251,8,57,112,16,125,43,69,15,183,200,235,37,102,65,59,210,125,31,73,139,79,16,73,15,191,192,72,139,20,193,72,15,191,195,72,139,12,193,139,65,16,57,66,16,102,69,15,76,200,102,69,133,201,116,79,102,131,237,1,73,139,79,16,72,15,191,195,65,15,183,217,76,141,4,197,0,0,0,0,72,139,4,193,72,137,1,73,139,79,16,73,15,191,193,72,141,20,197,0,0,0,0,72,139,4,193,74,137,4,1,73,139,79,16,72,139,1,72,137,4,17,73,139,71,16,76,137,48,15,137,59,255,255,255,76,139,84,36,72,190,1,0,0,0,139,188,36,32,1,0,0,65,139,66,12,65,57,66,16,15,132,16,3,0,0,69,139,90,8,184,103,102,102,102,76,139,76,36,120,185,63,1,0,0,65,247,235,193,250,7,139,194,193,232,31,3,208,43,202,137,76,36,32,141,4,146,186,2,0,0,0,193,224,6,68,43,216,137,84,36,64,72,199,192,255,255,255,255,68,137,92,36,44,68,15,183,192,68,15,183,224,15,183,194,68,137,68,36,68,137,68,36,36,65,59,73,12,117,6,137,116,36,64,235,9,65,59,73,4,117,3,69,139,230,69,59,25,117,10,69,139,198,68,137,116,36,68,235,16,69,59,89,8,117,10,139,198,137,68,36,36,15,31,64,0,78,141,12,109,0,0,0,0,65,15,183,240,77,3,205,73,193,225,3,76,137,76,36,80,102,69,133,228,117,9,102,133,246,15,132,125,1,0,0,68,15,191,246,69,3,243,65,15,191,236,3,233,73,99,198,72,105,216,144,1,0,0,72,99,197,72,3,216,68,137,116,36,88,72,141,5,224,27,68,0,137,108,36,92,72,3,216,15,182,3,60,137,117,35,72,139,84,36,88,68,139,199,72,139,76,36,48,232,32,136,2,0,76,139,76,36,80,76,139,84,36,72,68,139,92,36,44,136,3,60,255,15,132,19,1,0,0,102,69,133,228,116,74,102,133,246,116,69,15,182,200,72,139,68,36,48,107,249,7,76,139,128,32,1,0,0,139,144,56,1,0,0,139,68,36,32,65,3,122,12,15,175,194,65,3,198,72,152,66,246,4,0,112,117,17,139,197,15,175,194,65,3,195,72,152,66,246,4,0,112,116,15,141,60,143,235,10,15,182,192,141,60,128,65,3,122,12,73,139,95,8,184,63,1,0,0,43,197,141,20,128,193,226,6,65,3,214,72,99,194,76,141,4,197,0,0,0,0,73,139,28,24,72,133,219,116,9,59,123,12,15,141,136,0,0,0,73,131,193,24,73,255,197,76,137,76,36,80,76,59,108,36,104,124,30,72,139,5,10,23,68,0,72,139,136,144,16,0,0,131,185,104,148,0,0,0,116,94,76,59,108,36,112,125,87,72,133,219,117,25,72,139,29,199,26,68,0,73,3,217,137,83,8,198,67,20,0,73,139,71,8,73,137,28,0,68,15,183,76,36,40,73,139,207,76,139,68,36,56,137,123,12,232,71,249,255,255,76,139,84,36,72,3,199,128,123,20,0,137,67,16,76,137,19,117,16,72,139,211,73,139,207,232,121,1,0,0,76,139,84,36,72,139,68,36,36,139,76,36,32,76,139,76,36,80,102,255,198,68,139,92,36,44,139,188,36,32,1,0,0,102,59,240,15,140,87,254,255,255,68,139,68,36,68,102,65,255,196,102,68,59,100,36,64,15,140,42,254,255,255,72,139,92,36,96,73,139,194,65,139,82,16,190,1,0,0,0,65,43,82,12,76,139,68,36,112,139,75,16,43,75,12,68,141,118,255,59,209,65,198,66,20,0,72,139,140,36,24,1,0,0,72,15,77,195,72,139,216,72,137,68,36,96,15,182,5,8,136,55,0,56,1,72,139,76,36,104,15,133,215,251,255,255,76,139,100,36,56,69,51,237,76,139,116,36,48,73,139,204,232,66,135,35,0,68,139,207,77,139,198,72,139,211,73,139,207,232,33,245,255,255,102,131,248,1,117,4,65,15,183,197,72,139,140,36,144,0,0,0,72,51,204,232,39,24,45,0,72,139,156,36,240,0,0,0,72,129,196,160,0,0,0,65,95,65,94,65,93,65,92,95,94,93,195,72,139,76,36,56,232,242,134,35,0,76,139,68,36,48,68,139,207,72,139,84,36,72,73,139,207,232,205,244,255,255,235,180,204,204,204,204,204,204,204,204,204,204,204}},
{name="planner-result-transfer",rva=0x225FC0,bytes={69,51,219,76,139,210,102,68,137,26,76,139,193,65,15,183,195,102,68,59,89,40,125,48,15,31,132,0,0,0,0,0,73,139,80,32,72,15,191,200,68,139,12,138,65,131,249,255,116,12,73,15,191,10,68,137,12,138,102,65,255,2,102,255,192,102,65,59,64,40,124,216,73,139,64,32,77,137,88,32,65,199,64,40,0,0,255,255,195,204,204,204,204,204,204,204}},
{name="planner-build-result",rva=0x225480,bytes={68,137,76,36,32,76,137,68,36,24,85,83,86,87,65,84,65,85,65,86,65,87,72,139,236,72,131,236,88,72,139,217,69,51,237,65,139,241,77,139,240,72,139,250,69,139,229,72,139,202,15,183,67,40,72,133,210,116,20,15,31,68,0,0,72,139,9,102,255,192,102,137,67,40,72,133,201,117,241,72,15,191,200,73,199,199,255,255,255,255,184,4,0,0,0,72,247,225,73,15,64,199,72,139,200,232,214,34,45,0,72,137,67,32,72,139,200,72,133,192,116,66,15,183,67,40,102,131,248,1,15,142,173,2,0,0,68,57,35,116,61,152,255,200,72,99,200,184,4,0,0,0,72,247,225,73,15,64,199,72,139,200,232,157,34,45,0,76,139,224,72,133,192,117,27,72,139,75,32,232,88,145,35,0,76,137,107,32,102,68,137,107,40,65,15,183,199,233,117,2,0,0,139,71,8,72,15,191,83,40,72,139,75,32,137,68,145,252,76,139,63,15,183,67,40,68,57,43,116,107,72,15,191,200,72,139,67,32,68,139,68,136,252,184,103,102,102,102,65,247,232,73,139,206,193,250,7,139,194,193,232,31,3,208,184,63,1,0,0,43,194,137,69,228,141,4,146,193,224,6,68,43,192,68,137,69,224,68,139,198,72,139,85,224,232,245,143,2,0,72,139,75,32,68,15,182,232,72,15,191,67,40,65,186,255,255,255,255,69,139,95,8,68,137,85,232,68,43,92,129,252,68,141,112,255,235,17,68,15,182,109,72,68,139,117,240,68,139,85,236,68,139,93,72,191,2,0,0,0,68,137,93,216,68,137,85,80,102,59,248,15,143,127,1,0,0,15,31,132,0,0,0,0,0,72,139,75,32,152,15,191,247,43,198,72,99,208,65,139,71,8,137,4,145,131,59,0,77,139,63,15,132,64,1,0,0,76,139,67,32,68,15,191,75,40,65,139,201,43,206,72,99,193,65,139,20,128,65,43,84,128,4,65,59,211,116,73,141,65,2,137,85,216,137,69,240,72,141,85,232,139,69,96,69,15,182,205,137,68,36,40,77,139,196,72,139,69,88,72,139,203,72,137,68,36,32,68,137,85,232,68,137,117,236,232,237,10,0,0,68,15,191,75,40,139,69,236,69,139,241,76,139,67,32,68,43,246,137,69,80,65,15,191,193,43,198,72,152,65,139,12,128,184,103,102,102,102,68,139,69,96,247,233,193,250,7,139,194,193,232,31,3,208,184,63,1,0,0,43,194,137,69,228,141,4,146,193,224,6,43,200,137,77,224,72,139,85,224,72,139,77,88,232,213,142,2,0,136,69,72,65,58,197,15,132,133,0,0,0,139,77,80,72,141,85,232,139,69,96,69,15,182,205,137,77,232,77,139,196,15,191,75,40,43,206,137,68,36,40,72,139,69,88,255,193,137,77,240,72,139,203,68,137,117,236,72,137,68,36,32,232,81,10,0,0,72,139,67,32,65,186,255,255,255,255,68,15,191,115,40,68,15,182,109,72,68,43,246,73,99,206,68,137,85,80,68,139,4,136,184,103,102,102,102,65,247,232,193,250,7,139,194,193,232,31,3,208,184,63,1,0,0,43,194,137,69,228,141,4,146,193,224,6,68,43,192,68,137,69,224,235,4,68,139,85,80,15,183,67,40,102,255,199,68,139,93,216,102,59,248,15,142,140,254,255,255,139,117,96,131,59,0,116,62,72,139,69,88,72,141,85,232,137,116,36,40,69,15,182,205,77,139,196,72,137,68,36,32,72,139,203,68,137,85,232,68,137,117,236,199,69,240,0,0,0,0,232,181,9,0,0,73,139,204,232,221,142,35,0,235,5,139,71,8,137,1,184,1,0,0,0,72,131,196,88,65,95,65,94,65,93,65,92,95,94,91,93,195}},
{name="planner-smoothing",rva=0x226160,bytes={68,136,76,36,32,76,137,68,36,24,72,137,76,36,8,87,65,86,72,131,236,104,76,99,18,77,139,240,72,139,250,65,131,250,255,15,132,226,2,0,0,139,82,4,139,194,76,99,95,8,65,43,195,131,248,3,127,14,65,139,194,43,194,131,248,3,15,142,195,2,0,0,76,139,65,32,184,103,102,102,102,72,137,108,36,88,65,185,63,1,0,0,72,137,116,36,80,190,63,1,0,0,76,137,100,36,72,67,139,44,144,247,237,76,137,108,36,64,193,250,7,139,194,76,137,124,36,56,193,232,31,3,208,184,103,102,102,102,43,242,141,12,146,193,225,6,43,233,67,139,12,152,247,233,193,250,7,139,194,193,232,31,3,208,68,43,202,68,137,76,36,36,141,4,146,193,224,6,43,200,137,140,36,136,0,0,0,59,205,15,132,80,2,0,0,68,59,206,15,132,71,2,0,0,59,205,184,255,255,255,255,68,139,193,65,191,1,0,0,0,69,139,231,69,139,233,68,15,78,224,68,43,238,69,133,237,68,15,78,248,68,43,197,65,139,200,68,137,68,36,32,65,139,197,65,15,175,204,65,15,175,199,59,200,15,132,5,2,0,0,65,139,202,72,137,92,36,96,65,43,203,68,59,193,15,132,208,0,0,0,139,197,65,15,183,218,43,132,36,136,0,0,0,59,193,15,132,187,0,0,0,68,59,233,116,13,139,198,65,43,193,59,193,15,133,164,1,0,0,102,255,203,141,4,109,1,0,0,0,65,15,175,197,15,191,203,65,15,175,199,153,43,194,209,248,68,139,224,65,59,203,15,142,67,1,0,0,144,139,132,36,136,0,0,0,65,3,247,68,139,132,36,168,0,0,0,43,197,68,3,224,72,15,191,203,77,141,52,142,137,116,36,44,65,139,196,185,63,1,0,0,153,43,206,65,247,253,141,20,137,72,139,140,36,160,0,0,0,65,15,175,199,193,226,6,3,208,137,68,36,40,65,137,22,72,139,84,36,40,232,122,130,2,0,58,132,36,152,0,0,0,15,133,215,0,0,0,102,255,203,65,199,6,255,255,255,255,76,139,180,36,144,0,0,0,15,191,195,59,71,8,127,131,233,184,0,0,0,141,4,117,1,0,0,0,65,15,175,196,65,141,90,255,15,191,203,65,15,175,192,153,43,194,209,248,68,139,248,65,59,203,15,142,153,0,0,0,68,139,172,36,168,0,0,0,15,31,64,0,102,102,102,15,31,132,0,0,0,0,0,65,139,193,72,15,191,203,43,198,77,141,52,142,68,3,248,185,63,1,0,0,65,139,199,65,3,236,153,137,108,36,40,65,247,248,69,139,197,65,15,175,196,43,200,137,68,36,44,72,139,84,36,40,141,4,137,72,139,140,36,160,0,0,0,193,224,6,3,197,65,137,6,232,195,129,2,0,58,132,36,152,0,0,0,117,36,68,139,68,36,32,102,255,203,68,139,76,36,36,65,199,6,255,255,255,255,76,139,180,36,144,0,0,0,15,191,195,59,71,8,127,134,76,139,180,36,144,0,0,0,139,87,8,15,191,195,59,194,117,49,141,66,1,72,99,200,139,7,43,194,255,200,76,99,192,73,141,20,142,72,139,132,36,128,0,0,0,73,193,224,2,72,139,64,32,72,141,12,136,232,200,66,45,0,139,7,137,71,4,72,139,92,36,96,76,139,100,36,72,72,139,116,36,80,72,139,108,36,88,76,139,108,36,64,76,139,124,36,56,72,131,196,104,65,94,95,195,68,137,87,4,235,217,204,204,204,204,204,204,204}},
{name="preference-snapshot-cost",rva=0x24E5A0,bytes={68,137,68,36,24,72,137,84,36,16,83,85,86,87,65,84,65,85,65,86,65,87,72,131,236,56,15,182,5,52,233,51,0,72,139,218,76,139,241,56,129,72,1,0,0,15,135,133,0,0,0,68,15,182,5,16,6,53,0,72,139,194,15,182,21,28,202,52,0,76,139,137,64,1,0,0,72,193,232,32,15,175,194,65,15,191,137,188,11,0,0,153,65,247,248,68,15,191,192,15,182,5,246,201,52,0,15,175,195,68,15,175,193,15,182,13,210,5,53,0,153,247,249,102,65,3,192,72,15,191,192,133,192,120,32,65,59,129,184,11,0,0,125,23,72,139,200,73,139,129,176,11,0,0,15,183,12,72,102,133,13,159,5,53,0,117,17,68,15,182,13,179,201,52,0,65,15,182,193,233,128,2,0,0,73,139,206,232,192,47,28,0,139,188,36,140,0,0,0,139,211,73,139,206,68,139,199,102,131,248,8,15,133,134,0,0,0,232,66,53,28,0,68,15,182,13,124,201,52,0,15,182,208,73,139,134,48,1,0,0,139,202,72,193,233,4,68,15,182,4,1,69,58,193,117,6,65,15,182,201,235,116,72,139,5,155,142,65,0,72,139,136,144,16,0,0,131,185,116,125,0,0,0,116,60,131,226,15,65,15,182,193,131,194,2,72,141,140,36,152,0,0,0,255,200,137,132,36,128,0,0,0,65,15,182,192,15,175,208,209,234,137,148,36,152,0,0,0,72,141,148,36,128,0,0,0,232,203,148,27,0,139,200,235,25,65,15,182,200,235,27,232,188,52,28,0,15,182,200,73,139,134,48,1,0,0,15,182,12,1,68,15,182,13,232,200,52,0,68,15,182,193,65,15,182,193,68,137,68,36,36,102,68,59,192,117,8,15,182,193,233,163,1,0,0,65,15,182,134,73,1,0,0,69,15,183,232,131,232,2,153,43,194,209,248,15,183,208,68,139,248,102,247,218,102,137,148,36,152,0,0,0,15,183,194,102,137,148,36,128,0,0,0,102,65,59,215,15,143,79,1,0,0,144,15,191,200,137,76,36,32,68,141,36,25,69,133,228,15,136,37,1,0,0,69,59,166,56,1,0,0,15,141,24,1,0,0,15,183,234,102,65,59,215,15,143,11,1,0,0,102,144,15,191,197,141,52,56,133,246,15,136,222,0,0,0,65,59,182,60,1,0,0,15,141,209,0,0,0,153,68,139,192,139,193,68,51,194,65,15,191,207,68,43,194,255,193,153,51,194,43,194,68,3,192,68,59,193,15,143,170,0,0,0,73,139,206,232,58,46,28,0,68,139,198,65,139,212,73,139,206,15,183,248,232,201,51,28,0,73,139,150,48,1,0,0,68,15,182,13,252,199,52,0,15,182,192,102,131,255,8,117,10,72,193,232,4,68,56,12,16,235,4,68,56,12,2,15,132,44,254,255,255,65,139,134,56,1,0,0,15,175,198,65,3,196,72,99,200,73,139,134,40,1,0,0,15,182,4,1,132,192,15,136,169,0,0,0,168,1,15,133,155,0,0,0,168,112,15,133,147,0,0,0,131,188,36,144,0,0,0,0,116,29,36,14,15,182,208,139,68,36,36,152,15,175,208,15,183,194,102,193,224,2,102,3,208,102,68,3,234,235,4,168,14,117,104,139,188,36,140,0,0,0,139,76,36,32,102,255,197,102,65,59,239,15,142,7,255,255,255,15,183,132,36,128,0,0,0,15,183,148,36,152,0,0,0,102,255,192,102,137,132,36,128,0,0,0,102,65,59,199,15,142,178,254,255,255,65,15,182,201,65,15,183,197,102,68,59,233,124,8,69,15,182,233,102,65,255,205,65,15,182,197,72,131,196,56,65,95,65,94,65,93,65,92,95,94,93,91,195,15,182,66,8,235,233,15,182,2,235,228}},
{name="preference-setpath",rva=0x374CD0,bytes={72,137,92,36,16,72,137,116,36,32,87,72,131,236,32,72,139,217,65,15,183,248,72,139,137,88,71,0,0,72,139,242,72,133,201,116,5,232,150,153,14,0,72,137,179,88,71,0,0,65,187,1,0,0,0,102,68,137,155,216,71,0,0,102,137,187,96,71,0,0,139,67,12,131,192,4,72,15,191,207,137,68,36,48,139,67,16,131,192,3,199,131,220,71,0,0,0,0,0,0,137,68,36,52,72,139,68,36,48,72,137,131,36,71,0,0,68,15,191,5,184,98,34,0,139,6,153,65,247,248,68,139,200,68,139,210,139,68,142,252,153,65,247,248,68,43,200,139,202,65,139,193,153,51,194,43,194,131,248,4,127,35,65,43,202,139,193,153,51,194,43,194,131,248,4,127,20,139,131,220,71,0,0,102,131,255,4,65,15,78,195,137,131,220,71,0,0,186,10,0,0,0,72,139,203,72,139,92,36,56,72,139,116,36,72,72,131,196,32,95,233,15,5,0,0}},
{name="preference-direct-a",rva=0x375ED4,bytes={185,8,0,0,0,232,230,24,24,0}},
{name="preference-direct-b",rva=0x37632E,bytes={185,8,0,0,0,232,140,20,24,0}},
{name="preference-message-run",rva=0x215220,bytes={64,85,87,72,139,236,72,131,236,56,72,139,249,72,141,85,24,139,73,8,232,199,20,6,0,132,192,15,133,130,2,0,0,72,139,77,24,72,139,1,255,80,8,60,49,15,133,112,2,0,0,72,139,69,24,72,137,116,36,48,72,139,112,24,72,133,246,15,132,85,2,0,0,72,139,5,216,34,69,0,72,141,87,48,72,137,92,36,104,72,141,77,32,72,139,152,144,16,0,0,232,183,131,30,0,72,139,208,72,139,203,232,76,5,6,0,72,59,198,15,133,28,2,0,0,76,139,5,188,34,69,0,76,139,85,24,65,128,184,201,2,0,0,1,15,133,33,1,0,0,65,139,66,80,65,57,128,116,3,0,0,15,132,16,1,0,0,15,182,5,8,124,57,0,102,65,57,130,16,71,0,0,15,133,251,0,0,0,65,15,183,130,96,71,0,0,73,139,146,88,71,0,0,68,15,182,13,14,93,56,0,68,15,182,29,5,93,56,0,15,183,29,6,93,56,0,15,183,53,251,92,56,0,102,133,192,126,34,72,133,210,116,29,72,15,191,192,15,191,206,139,68,130,252,153,247,249,15,191,203,43,200,137,85,40,255,201,137,77,44,235,45,77,139,130,168,74,0,0,65,139,192,65,15,182,203,153,73,193,232,32,247,249,65,15,182,201,137,69,32,65,139,192,153,247,249,137,69,36,72,139,69,32,72,137,69,40,15,183,71,16,102,133,192,126,38,72,139,87,24,72,133,210,116,29,72,15,191,192,15,191,206,139,68,130,252,153,247,249,15,191,203,43,200,137,85,32,255,201,137,77,36,235,42,76,139,71,36,65,139,192,65,15,182,203,153,73,193,232,32,247,249,65,15,182,201,137,69,32,65,139,192,153,247,249,137,69,36,72,139,69,32,72,137,69,32,72,141,85,32,72,141,77,40,232,61,181,241,255,131,248,1,15,142,237,0,0,0,76,139,85,24,76,139,5,137,33,69,0,15,191,13,38,92,56,0,139,71,44,15,191,29,32,92,56,0,153,77,139,90,12,68,15,182,13,11,92,56,0,247,249,15,182,13,3,92,56,0,43,216,139,242,65,139,195,255,203,153,65,247,249,59,198,117,14,73,193,235,32,65,139,195,153,247,249,59,195,116,66,65,128,184,201,2,0,0,0,15,132,142,0,0,0,68,15,175,206,69,51,192,15,175,203,199,68,36,40,0,0,0,0,199,68,36,32,0,0,0,0,68,137,77,32,69,51,201,137,77,36,73,139,202,72,139,85,32,232,181,180,24,0,76,139,85,24,68,15,183,71,16,73,139,202,72,139,87,24,232,96,248,21,0,15,183,79,32,72,139,69,24,102,137,136,216,71,0,0,72,139,77,24,232,56,162,20,0,72,139,77,24,72,199,71,24,0,0,0,0,72,139,21,197,32,69,0,128,186,201,2,0,0,1,117,11,139,65,80,57,130,116,3,0,0,117,10,199,129,224,82,0,0,1,0,0,0,72,139,92,36,104,72,139,116,36,48,72,131,196,56,95,93,195,204,204,204,204,204,204}},
{name="preference-message-constructor",rva=0x204370,bytes={72,137,92,36,16,85,86,87,65,86,65,87,72,131,236,80,72,139,5,81,6,70,0,72,51,196,72,137,68,36,64,139,132,36,176,0,0,0,72,139,249,139,156,36,184,0,0,0,65,15,183,241,137,65,12,77,139,248,137,89,8,72,141,5,124,100,57,0,72,137,1,139,234,72,139,5,80,135,69,0,72,137,65,48,72,141,76,36,48,232,162,180,31,0,72,139,5,59,135,69,0,72,141,84,36,40,139,203,72,137,68,36,32,232,26,35,7,0,132,192,117,53,72,139,68,36,40,76,139,64,24,77,133,192,116,39,73,129,192,4,2,0,0,72,141,84,36,56,72,141,76,36,48,232,114,180,31,0,72,141,84,36,32,72,141,76,36,48,232,35,186,31,0,235,17,72,141,21,162,105,57,0,72,141,76,36,32,232,224,147,31,0,72,139,132,36,168,0,0,0,72,141,84,36,32,72,141,79,48,72,137,71,36,232,38,147,31,0,137,111,44,102,133,246,126,68,15,183,132,36,160,0,0,0,72,199,193,255,255,255,255,102,137,71,32,184,4,0,0,0,72,15,191,222,72,247,227,72,15,64,193,72,139,200,232,71,51,47,0,76,141,4,157,0,0,0,0,72,137,71,24,73,139,215,72,139,200,232,124,98,47,0,235,10,51,192,102,137,71,32,72,137,71,24,72,141,76,36,32,102,137,119,16,232,146,146,31,0,72,139,199,72,139,76,36,64,72,51,204,232,226,50,47,0,72,139,156,36,136,0,0,0,72,131,196,80,65,95,65,94,95,94,93,195,204,204,204,204,204,204,204,204,204,204,204,204,204,204}},
{name="preference-message-destructor",rva=0x204C10,bytes={72,137,92,36,8,87,72,131,236,32,72,141,5,15,92,57,0,72,139,217,72,137,1,139,250,72,139,73,24,72,133,201,116,10,186,4,0,0,0,232,84,154,37,0,72,141,75,48,232,251,138,31,0,72,141,5,20,129,56,0,72,137,3,64,246,199,1,116,13,186,56,0,0,0,72,139,203,232,46,154,37,0,72,139,195,72,139,92,36,48,72,131,196,32,95,195}},
{name="preference-array-new",rva=0x4F77C4,bytes={233,191,2,0,0}},
{name="preference-operator-new",rva=0x4F7A88,bytes={64,83,72,131,236,32,72,139,217,235,15,72,139,203,232,81,45,2,0,133,192,116,19,72,139,203,232,209,171,0,0,72,133,192,116,231,72,131,196,32,91,195,72,131,251,255,116,6,232,83,13,0,0,204,232,109,13,0,0,204}},
{name="preference-malloc",rva=0x502678,bytes={233,215,189,1,0}},
{name="preference-malloc-base",rva=0x51E454,bytes={64,83,72,131,236,32,72,139,217,72,131,249,224,119,60,72,133,201,184,1,0,0,0,72,15,68,216,235,21,232,6,218,255,255,133,192,116,37,72,139,203,232,106,195,255,255,133,192,116,25,72,139,13,3,161,249,2,76,139,195,51,210,255,21,24,189,6,0,72,133,192,116,212,235,13,232,140,72,255,255,199,0,12,0,0,0,51,192,72,131,196,32,91,195,204,204,72,137,92,36,8,72,137,108,36,16,72,137,116,36,24,87,72,131,236,80,51,237,73,139,240,72,139,250,72,139,217,72,133,210,15,132,54,1,0,0,77,133,192,15,132,45,1,0,0,64,56,42,117,15,72,133,201,116,3,102,137,41,51,192,233,34,1,0,0,73,139,209,72,141,76,36,48,232,154,3,254,255,72,139,68,36,56,129,120,12,233,253,0,0,117,34,76,141,13,93,153,249,2,76,139,198,72,139,215,72,139,203,232,179,238,0,0,72,139,200,131,200,255,133,201,15,72,200,235,25,72,57,168,56,1,0,0,117,42,72,133,219,116,6,15,182,7,102,137,3,185,1,0,0,0,64,56,108,36,72}},
{name="preference-path-free",rva=0x45E690,bytes={233,139,121,247,255}},
{name="preference-p-free",rva=0x3D6020,bytes={233,147,122,18,0,204,204,204,204,204,204,204,204,204,204,204}},
}
local repair_policy=(function()
-- Optional candidate geometry only. Never changes a live route or obstacle.
local R={}
function R.plan(q)
    local path=q.path
    if #path<2 or #path>q.capacity then return nil,'repair-capacity',0 end
    local out={{x=path[1].x,y=path[1].y}}
    local repairs=0
    for i=2,#path do
        if q.clock and (q.clock()-q.started>2 or q.clock()-q.overall_started>8) then
            return nil,'repair-time-budget',repairs
        end
        local a,b=path[i-1],path[i]
        if math.abs(b.x-a.x)==1 and math.abs(b.y-a.y)==1 then
            local first,second=q.open(b.x,a.y),q.open(a.x,b.y)
            if not first or not second then
                if not first and not second or not q.open(a.x,a.y) or not q.open(b.x,b.y) then
                    return nil,'repair-blocked',repairs
                end
                if repairs>=4 or #path+repairs+1>q.capacity then return nil,'repair-capacity',repairs end
                repairs=repairs+1
                out[#out+1]=first and {x=b.x,y=a.y} or {x=a.x,y=b.y}
            end
        end
        out[#out+1]={x=b.x,y=b.y}
    end
    return repairs>0 and out or nil,repairs>0 and 'local-corners' or 'no-local-corner',repairs
end
return R

end)()
local route_observer=(function()
-- Capture-only route geometry. Pure table formatting; no engine reads/writes.
local O={limit=12,points=256,chunk=64,slow_limit=4,slow_window=60000}
function O.geometry(q)
    assert(q.baseline and #q.baseline>=2 and #q.baseline<=O.points,'observer baseline bound')
    assert(not q.candidate or #q.candidate<=O.points,'observer candidate bound')
    local prefix='mover='..q.mover..' evaluation='..q.evaluation
    local lines={'PREFERENCE_GEOMETRY '..prefix..' decision='..q.decision..' backend='..q.backend
        ..' source='..q.source..' width='..q.width..' height='..q.height
        ..' goal_px='..q.gx..','..q.gy..' units=search-cells cell_width=16 cell_height=12'
        ..' baseline_count='..#q.baseline..' candidate_count='..(q.candidate and #q.candidate or 0)}
    local routes={{'baseline',q.baseline}}
    if q.candidate then routes[#routes+1]={'candidate',q.candidate} end
    for _,route in ipairs(routes) do
        local path=route[2]
        for start=1,#path,O.chunk do
            local points={}
            for i=start,math.min(start+O.chunk-1,#path) do points[#points+1]=path[i].x..','..path[i].y end
            lines[#lines+1]='PREFERENCE_GEOMETRY_PATH '..prefix..' role='..route[1]
                ..' chunk='..math.floor((start-1)/O.chunk+1)..' chunks='..math.ceil(#path/O.chunk)
                ..' count='..#path..' points='..table.concat(points,';')
        end
    end
    return lines
end
function O.timing(q)
    local text='mover='..q.mover..' evaluation='..q.evaluation..' backend='..(q.backend or 'none')
        ..' actors='..(q.actors or 0)..' route_cells='..(q.route_cells or 0)
        ..' paint_visits='..(q.paint_visits or 0)..' paint_cells='..(q.paint_cells or 0)
        ..' compute_ms='..q.compute_ms..' decision='..q.decision
        ..' captured='..tostring(q.captured)..' tail_ms='..q.tail_ms
    for _,stage in ipairs({'context','enumerate','peers','route_map','copy','paint','prepare','query','validate'}) do
        text=text..' '..stage..'_ms='..tostring(q.timings[stage] or -1)
    end
    return text
end
return O

end)()
local straighten_policy=(function()
-- Optional local simplification of an already accepted route. Pure Lua tables;
-- clearance and final selection come from the unchanged production validator.
local S={max_attempts=8,max_cells=64,max_span=4,max_distance=96,max_ms=1}
local function length(a,b)
    return math.sqrt(((b.x-a.x)*16)^2+((b.y-a.y)*12)^2)
end
function S.turns(path)
    local total,previous=0,nil
    for i=2,#path do
        local a,b=path[i-1],path[i]
        local v={x=(b.x-a.x)*16,y=(b.y-a.y)*12}
        if v.x~=0 or v.y~=0 then
            if previous then
                total=total+math.abs(math.atan2(previous.x*v.y-previous.y*v.x,previous.x*v.x+previous.y*v.y))
            end
            previous=v
        end
    end
    return total
end
function S.plan(q)
    if #q.path<3 or #q.path>64 then return nil,'shape',0,0 end
    local began=q.clock()
    local path={};for i,p in ipairs(q.path)do path[i]=p end
    local attempts,cells,changed=0,0,0
    local visited={}
    local function within_budget()
        return q.clock()-began<=S.max_ms and q.clock()-q.overall_started<=6
    end
    local function open(x,y)
        if not within_budget() then return false end
        local key=x..','..y
        if visited[key]==nil then
            cells=cells+1;if cells>S.max_cells then return false end
            visited[key]=q.open(x,y)
        end
        return visited[key]
    end
    local initial_turns=S.turns(path)
    local i=1
    while i<#path-1 and attempts<S.max_attempts and within_budget() do
        local accepted=false
        for last=math.min(#path,i+S.max_span),i+2,-1 do
            if attempts>=S.max_attempts or not within_budget() then break end
            if length(path[i],path[last])<=S.max_distance then
                local candidate={}
                for index,p in ipairs(path)do if index<=i or index>=last then candidate[#candidate+1]=p end end
                -- Collinear waypoint removal alone offers no visual improvement.
                if S.turns(candidate)+0.000001<S.turns(path) then
                    attempts=attempts+1
                    if q.samples({path[i],path[last]},open) then
                        changed=changed+last-i-1;path=candidate;accepted=true;break
                    end
                end
            end
        end
        if not accepted then i=i+1 end
    end
    if cells>S.max_cells or not within_budget() then return nil,'budget',attempts,cells end
    if changed==0 then return nil,'no-clear-improvement',attempts,cells end
    return path,'local-straightening',attempts,cells,changed,initial_turns,S.turns(path)
end
return S

end)()
-- Optional native routing preference. Ordinary Move23 only; no action edits.
MRIP_PreferenceEnabled=false
local preference_state,preference_storage=nil,nil
local preference_available=false
local preference_busy=false
local preference_routes=shared_policy.cache()
local preference_attempts={}
local preference_proposal=nil
local preference_diagnostic_run,preference_diagnostic_count=nil,0
local preference_geometry_run,preference_geometry_count=nil,0
local preference_evaluation=0
local preference_slow_start,preference_slow_count=nil,0
local preference_budget_start,preference_budget_used=nil,0
local function preference_keep(sprite,reason,emit)
    if active then (emit or log)('PREFERENCE_KEEP mover='..tostring(sprite and sprite.m_id)..' reason='..tostring(reason)) end
    return 0
end
local function preference_order(sprite,caller,count,quiet,emit)
    if not sprite then return false,'no-sprite' end
    local portrait=sprite:getPortraitIndex()
    local action=sprite.m_curAction
    local queued,ids,more=0,{},false
    -- Bound diagnostics even for a deliberately long scripted queue. The
    -- supported exception is exactly one ordinary terminal Face84 action.
    EEex_Utility_IterateCPtrList(sprite.m_queuedActions,function(value)
        queued=queued+1
        local a=EEex_CastUD(value,'CAIAction')
        ids[#ids+1]=a.m_actionID
        if queued==8 then more=true;return true end
    end)
    local tagged=settle_tagged(action)
    local accepted,reason=true,'ordinary-move'
    if not sprite.m_pArea then accepted,reason=false,'no-area'
    elseif portrait<0 or portrait>5 then accepted,reason=false,'not-party'
    elseif not action or action.m_actionID~=23 then accepted,reason=false,'current-action'
    elseif tagged then accepted,reason=false,'settle-order'
    elseif sprite.m_inCutScene~=0 then accepted,reason=false,'cutscene'
    elseif queued>0 and not (queued==1 and ids[1]==84) then accepted,reason=false,'queued-orders'
    elseif queued==1 then reason='move-with-final-face' end
    if active and not quiet then
        (emit or log)('PREFERENCE_CONTEXT mover='..sprite.m_id..' accepted='..tostring(accepted)..' reason='..reason
            ..' portrait='..tostring(portrait)..' action='..tostring(action and action.m_actionID)
            ..' token='..tostring(action and action.m_specificID3)..' settle_tag='..tostring(tagged)
            ..' cutscene='..tostring(sprite.m_inCutScene)..' queued='..queued..' queue_limited='..tostring(more)
            ..' queue_ids='..(#ids>0 and table.concat(ids,',') or 'none')
            ..' caller='..tostring(caller)..' points='..tostring(count))
    end
    return accepted,reason
end
local function preference_context(sprite)
    if not sprite or not sprite.m_pArea or not sprite.getPortraitIndex then return nil end
    if not preference_order(sprite,0,0,true) then return nil end
    local a=actor_record(sprite,{})
    if not attack_policy.ally(a.ea) or a.personal~=3 or a.busy~=0 or a.bump~=0
        or EEex_BAnd(a.state,settle_mask)~=0 or EEex_BAnd(a.base_state,settle_mask)~=0 then return nil end
    local owner=EEex_UDToPtr(sprite)
    local goal=sprite.m_curAction.m_dest
    return {slot=sprite:getPortraitIndex(),id=a.id,owner=owner,area=EEex_UDToPtr(sprite.m_pArea),
        gx=goal.x,gy=goal.y,action=a.action,state=a.state,base_state=a.base_state,epoch=EEex_Read32(buffer+24),
        x=a.x,y=a.y,path=EEex_ReadPtr(owner+0x4758),count=EEex_Read16(owner+0x4760),cursor=EEex_Read16(owner+0x47D8)}
end
local function preference_reset(sprite)
    if sprite then preference_attempts[sprite.m_id]=nil else preference_attempts={} end
    preference_routes.reset(sprite and sprite.m_id)
end
local function preference_fail(reason)
    MRIP_PreferenceEnabled=false
    preference_routes.reset()
    if preference_state then EEex_Write32(preference_state,0) end
    log('PREFERENCE_ERROR disabled='..tostring(reason))
    feedback('visual route preference disabled; check EEex log')
end
function MRIP_TogglePreference()
    if not MRIP_TraceEnabled or not preference_available then feedback('visual route preference unavailable; check EEex log');return end
    if active then MRIP_Stop('preference-mode-change') end
    MRIP_PreferenceEnabled=not MRIP_PreferenceEnabled
    preference_reset();preference_budget_start=nil;preference_budget_used=0
    EEex_Write32(preference_state,MRIP_PreferenceEnabled and 1 or 0)
    log('PREFERENCE_MODE enabled='..tostring(MRIP_PreferenceEnabled))
    feedback(MRIP_PreferenceEnabled and 'visual route preference ON' or 'visual route preference OFF')
end
local function preference_select(sprite,path,count,output,caller,message,trace)
    local log=trace.emit
    local keep=preference_keep
    local function preference_keep(s,reason) trace.reason=reason;return keep(s,reason,log) end
    preference_proposal=nil
    if sprite then preference_routes.reset(sprite.m_id) end
    if not MRIP_PreferenceEnabled then return 0 end
    local now=movement_ready()
    local evaluation_started=clock()
    if not now or not settle_world() then return preference_keep(sprite,'movement-or-world') end
    local supported,order_reason=preference_order(sprite,caller,count,false,log)
    if not supported then return preference_keep(sprite,order_reason) end
    local mover=actor_record(sprite,{})
    if not attack_policy.ally(mover.ea) or mover.personal~=3 or mover.busy~=0 or mover.bump~=0
        or EEex_BAnd(mover.state,settle_mask)~=0 or EEex_BAnd(mover.base_state,settle_mask)~=0 then
        return preference_keep(sprite,'eligibility')
    end
    local chitin=EEex_ReadPtr(base+0x667560)
    if chitin==0 or EEex_ReadU8(chitin+0x2C9)~=0 then return preference_keep(sprite,'network-session') end
    if not path or path==0 or not output or output==0 or count<2 or count>256 then return 0 end
    trace.enabled=true
    local direct=caller==base+0x375F9E+5 or caller==base+0x3763C7+5
    if direct and (count~=2 or EEex_Read32(EEex_UDToPtr(sprite)+0x4944)~=0) then
        return preference_keep(sprite,'direct-secondary-consumer')
    end
    local message_route=caller==base+0x215470
    if message_route and (not message or message==0 or EEex_ReadPtr(message+0x18)~=path
        or EEex_Read16(message+0x10)~=count or EEex_Read16(message+0x20)~=1
        or EEex_ReadPtr(EEex_UDToPtr(sprite)+0x4758)==path) then
        return preference_keep(sprite,'message-resumed-or-changed')
    end
    local capacity=(direct or message_route) and 256 or count
    local ap=EEex_UDToPtr(sprite.m_pArea)
    local bitmap=ap+0xA60
    local live=EEex_ReadPtr(bitmap+0x120)
    local width,height=EEex_Read32(bitmap+0x138),EEex_Read32(bitmap+0x13C)
    if live==0 or width<1 or width>320 or height<1 or height>320
        or EEex_Read16(base+0x59B004)~=320 or EEex_Read16(base+0x59B008)~=320 then return preference_keep(sprite,'dimensions') end
    local goal=sprite.m_curAction.m_dest
    local points={}
    for i=0,count-1 do
        local v=EEex_Read32(path+i*4)
        if v<0 or v>=102400 then return preference_keep(sprite,'encoding') end
        points[#points+1]={x=v%320,y=319-math.floor(v/320)}
    end
    local first,last=points[1],points[#points]
    if first.x~=math.floor(mover.x/16) or first.y~=math.floor(mover.y/12)
        or not goal or last.x~=math.floor(goal.x/16) or last.y~=math.floor(goal.y/12) then
        return preference_keep(sprite,'endpoints-not-order')
    end
    -- Retain only already decoded Lua values for the post-compute observer.
    trace.baseline=points;trace.width=width;trace.height=height;trace.gx=goal.x;trace.gy=goal.y
    trace.source=message_route and 'message' or direct and 'direct' or 'searched'
    local mp=EEex_UDToPtr(sprite)
    local context=preference_context(sprite)
    if context then preference_routes.stage(context,points,now) end
    local attempt=preference_attempts[mover.id]
    if attempt and attempt.owner==mp and attempt.area==ap and attempt.x==goal.x and attempt.y==goal.y then
        return preference_keep(sprite,'already-attempted-order')
    end
    if not preference_budget_start or now<preference_budget_start or now-preference_budget_start>=100 then
        preference_budget_start=now;preference_budget_used=0
    end
    if preference_budget_used>=6 then return preference_keep(sprite,'query-rate-budget') end
    trace.mark('context')
    local actors,identities={},{}
    sprite.m_pArea:forAllOfTypeInRange(mover.x,mover.y,CAIObjectType.ANYONE,32767,function(object)
        if not object then error('unresolved preference object') end
        if EEex_GameObject_IsSprite(object,true) then
            if #actors>=256 then error('preference actor budget') end
            local s=EEex_CastUD(object,'CGameSprite')
            if not s.m_pArea or EEex_UDToPtr(s.m_pArea)~=ap or identities[s.m_id] then error('preference identity') end
            identities[s.m_id]=EEex_UDToPtr(s);actors[#actors+1]=actor_record(s,{})
        end
    end,0,0)
    if identities[mover.id]~=mp then return preference_keep(sprite,'incomplete-enumeration') end
    for slot=0,5 do
        local s=EEex_Sprite_GetInPortrait(slot)
        if s and s.m_pArea and EEex_UDToPtr(s.m_pArea)==ap and identities[s.m_id]~=EEex_UDToPtr(s) then
            return preference_keep(sprite,'missing-party')
        end
    end
    trace.mark('enumerate');trace.actors=#actors
    local observed_raw=nil
    local occupancy={width=width,height=height,actors=actors,read=function(x,y)
        local key=y*width+x
        local raw=EEex_ReadU8(live+key)
        if active then observed_raw=raw end
        return raw
    end}
    local peers={}
    for slot=0,5 do
        if preference_routes.has(slot) then
            local s=EEex_Sprite_GetInPortrait(slot)
            local c=preference_context(s)
            if c and c.id~=mover.id and c.area==ap then
                local remaining=preference_routes.remaining(c,now)
                if remaining then peers[#peers+1]=remaining end
            elseif not c and s then preference_routes.reset(s.m_id) end
        end
    end
    trace.mark('peers')
    local map_started=clock()
    local weights,shared_reason,shared_info=shared_policy.map({baseline=points,peers=peers,width=width,height=height,
        clock=clock,started=map_started,overall_started=evaluation_started})
    if weights then
        local exposure=0
        preference_policy.samples(points,function(x,y) if weights[y*width+x] then exposure=exposure+1 end;return true end)
        if exposure<8 then weights=nil;shared_reason='insufficient-shared-travel' end
    end
    trace.mark('route_map');trace.backend=weights and 'soft-route' or 'native-footprints'
    trace.route_cells=weights and shared_info.cells or 0
    if active then log('PREFERENCE_SHARED mover='..mover.id..' backend='..(weights and 'soft-route' or 'native-footprints')
        ..' peers='..#peers..' cells='..tostring(weights and shared_info.cells or 0)..' reason='..tostring(shared_reason or 'parallel-route')) end
    local ally_cache={}
    local function ally(x,y)
        if weights then return weights[y*width+x]==1 end
        local key=y*width+x
        if ally_cache[key]==nil then
            local found=false
            for _,a in ipairs(actors) do
                if a.id~=mover.id and attack_policy.ally(a.ea) and a.painted==1 and a.removed==0 and attack_policy.footprint(a,x,y) then found=true;break end
            end
            ally_cache[key]=found
        end
        return ally_cache[key]
    end
    local overlap=false
    local sampled=0
    preference_policy.samples(points,function(x,y)
        sampled=sampled+1
        if sampled>1024 then return false end
        if ally(x,y) then overlap=true end
        return true
    end)
    if sampled>1024 or not overlap then return preference_keep(sprite,sampled>1024 and 'cell-budget' or 'no-allies-on-route') end
    -- One attempt per Move action, even if native returns partial/no route.
    -- A subsequent native retry keeps its permissive result.
    preference_attempts[mover.id]={owner=mp,area=ap,x=goal.x,y=goal.y}
    preference_budget_used=preference_budget_used+1
    if EEex_Read32(preference_state+4)~=0 or EEex_Read32(preference_state+12)~=0 then return preference_keep(sprite,'planner-busy') end
    local owner=EEex_Read32(buffer+60)
    if owner==0 then return preference_keep(sprite,'world-thread-unavailable') end
    EEex_Write32(preference_state+8,owner)
    -- One persistent private workspace; no engine request, live map or planner
    -- object is retained. Native constructor/destructor execute per query.
    if not preference_storage then preference_storage=EEex_Malloc(0x1C4000);assert(preference_storage and preference_storage~=0,'preference scratch allocation') end
    local storage=preference_storage
    local clone,map,start,finish,candidate=storage+0x80,storage+0x200,storage+0x19200,storage+0x19208,storage+0x19210
    local nodes,opened=storage+0x19610,storage+0xE1610
    EEex_Memcpy(clone,bitmap,0x150)
    EEex_Memcpy(map,live,width*height)
    EEex_WritePtr(clone+0x120,map);EEex_WritePtr(clone+0x128,map)
    local terrain_ptr=EEex_UDToPtr(sprite:virtual_GetTerrainTable())
    assert(terrain_ptr and terrain_ptr~=0,'preference terrain binding')
    EEex_WritePtr(clone+0x130,terrain_ptr)
    EEex_Write8(clone+0x149,3)
    local weight_map=storage+0x1AA000
    EEex_WritePtr(storage+64,0);EEex_Write32(storage+72,0);EEex_Write32(storage+76,0)
    trace.mark('copy')
    if weights then
        occupancy.clock=clock;occupancy.started=clock();occupancy.overall_started=evaluation_started
        local changes,reason,info=shared_policy.private(occupancy,attack_policy.footprint,attack_policy.ally)
        trace.mark('paint')
        if info then trace.paint_visits=info.visits;trace.paint_cells=info.cells end
        if not changes then return preference_keep(sprite,reason) end
        for key,raw in pairs(changes) do EEex_Write8(map+key,raw) end
        -- One bulk zero then bounded sparse writes, not a Lua loop over the map.
        EEex_Memset(weight_map,0,width*height)
        for key,weight in pairs(weights) do EEex_Write8(weight_map+key,weight) end
        EEex_WritePtr(storage+64,weight_map);EEex_Write32(storage+72,width);EEex_Write32(storage+76,height)
    else
    -- Subtract only this mover's verified painted counter in the PRIVATE map.
    -- Other friendlies remain present for the native preference search.
    if mover.painted==1 and mover.removed==0 then
        for y=math.max(0,first.y-1),math.min(height-1,first.y+1) do
            for x=math.max(0,first.x-1),math.min(width-1,first.x+1) do
                if attack_policy.footprint(mover,x,y) then
                    if not attack_policy.cell(occupancy,x,y) then return preference_keep(sprite,'mover-paint-unverified') end
                    local key=y*width+x
                    EEex_Write8(map+key,EEex_ReadU8(map+key)-(mover.category==0 and 16 or 2))
                end
            end
        end
    elseif mover.painted~=0 or mover.removed~=1 then return preference_keep(sprite,'mover-paint-phase') end
    end
    if clock()-evaluation_started>8 then return preference_keep(sprite,'preparation-budget') end
    EEex_Write32(start,first.x);EEex_Write32(start+4,first.y)
    EEex_Write32(finish,last.x);EEex_Write32(finish+4,last.y)
    for i,p in ipairs({clone,start,finish,nodes,opened,candidate}) do EEex_WritePtr(storage+(i-1)*8,p) end
    EEex_Write32(storage+60,2048)
    local began=clock()
    local guard_refs,guard_capacity=EEex_Read16(base+0x667920),EEex_Read32(base+0x667930)
    local guard_pool=EEex_ReadPtr(base+0x667928)~=0
    trace.mark('prepare')
    MRIP_PreferenceQueryNative(storage)
    local elapsed=clock()-began
    trace.mark('query')
    local status=EEex_Read32(storage+56)
    if active then log('PREFERENCE_QUERY mover='..mover.id..' status='..status
        ..' reached='..EEex_Read32(storage+52)..' points='..EEex_Read32(storage+48)..' query_ms='..elapsed
        ..' guard_refs='..guard_refs..' guard_capacity='..guard_capacity..' guard_pool='..tostring(guard_pool)) end
    if active and weights then log('PREFERENCE_COST mover='..mover.id..' weighted='..EEex_Read32(preference_state+48)
        ..' lookups='..EEex_Read32(preference_state+52)) end
    if status==-8 then error('native planner ownership changed') end
    if elapsed>4 then
        log('PREFERENCE_BUDGET_DISABLED elapsed_ms='..elapsed)
        MRIP_PreferenceEnabled=false;EEex_Write32(preference_state,0)
        feedback('visual route preference OFF after slow query; movement stays ON')
        return preference_keep(sprite,'elapsed-budget')
    end
    if status~=1 or EEex_Read32(storage+52)~=1 then return preference_keep(sprite,'native-unreached-or-unavailable') end
    local n=EEex_Read32(storage+48)
    if n<2 or n>capacity then return preference_keep(sprite,'result-capacity') end
    local proposed={}
    for i=0,n-1 do
        local v=EEex_Read32(candidate+i*4)
        if v<0 or v>=102400 then return preference_keep(sprite,'candidate-encoding') end
        proposed[#proposed+1]={x=v%320,y=319-math.floor(v/320)}
    end
    local selected,reason,details
    local bitmap_ud=EEex_PtrToUD(bitmap,'CSearchBitmap')
    local terrain=EEex_PtrToUD(terrain_ptr,'Primitive<byte>')
    EEex_RunWithStack(16,function(temp)
        local point,tile=EEex_PtrToUD(temp,'CPoint'),EEex_PtrToUD(temp+8,'Primitive<ushort>')
        local cache,cells,observations,first_failure={},0,{},nil
        local function open(x,y)
            if x<0 or y<0 or x>=width or y>=height then return false end
            local key=y*width+x
            if cache[key]==nil then
                cells=cells+1;if cells>1024 then error('preference validation cell budget') end
                point.x=x;point.y=y
                local cost=bitmap_ud:GetCost(point,terrain,0,tile,1)
                assert(type(cost)=='number' and cost>=0 and cost<=255,'preference terrain cost')
                cache[key]=cost~=255 and attack_policy.cell(occupancy,x,y) or false
                if active and not cache[key] then
                    observations[key]={x=x,y=y,cost=cost,open=cache[key],observed='decision',
                        occupancy_open=cost~=255 and cache[key] or nil,
                        raw=cost~=255 and observed_raw or EEex_ReadU8(live+key)}
                end
            end
            if active and not cache[key] and not first_failure then first_failure=observations[key] end
            return cache[key]
        end
        selected,reason,details=preference_policy.choose({width=width,height=height,baseline=points,preferred=proposed,
            reached_baseline=true,reached_preferred=true,open=open,ally=ally})
        if reason=='unsafe-segment' then
            local repaired,repair_reason,repairs=repair_policy.plan({path=proposed,open=open,capacity=capacity,
                clock=clock,started=clock(),overall_started=evaluation_started})
            if repaired then
                proposed=repaired
                first_failure=nil -- Report the revalidated candidate's failure.
                selected,reason,details=preference_policy.choose({width=width,height=height,baseline=points,preferred=proposed,
                    reached_baseline=true,reached_preferred=true,open=open,ally=ally})
            end
            if active then log('PREFERENCE_REPAIR mover='..mover.id..' corners='..(repairs or 0)
                ..' result='..tostring(repair_reason)..' validation='..reason) end
        end
        -- One bounded local simplification, only after the original candidate
        -- is accepted and there is time for unchanged final validation.
        if reason=='preferred' and #points<=64 and clock()-evaluation_started<=4 then
            local before_points,before_overlap=#selected,details.preferred_overlap
            local simplified,simplify_reason,attempts,visits,removed,before_turns,after_turns=straighten_policy.plan({
                path=selected,samples=preference_policy.samples,clock=clock,overall_started=evaluation_started,
                open=function(x,y)
                    if x<0 or y<0 or x>=width or y>=height or (cells>=1024 and cache[y*width+x]==nil) then return false end
                    return open(x,y)
                end})
            local retained=false
            if simplified then
                local refined,refined_reason,refined_details=preference_policy.choose({width=width,height=height,
                    baseline=points,preferred=simplified,reached_baseline=true,reached_preferred=true,
                    open=function(x,y)
                        if clock()-evaluation_started>7 or x<0 or y<0 or x>=width or y>=height
                            or (cells>=1024 and cache[y*width+x]==nil) then return false end
                        return open(x,y)
                    end,ally=ally})
                retained=refined_reason=='preferred' and refined_details.preferred_overlap<=details.preferred_overlap
                    and clock()-evaluation_started<=7
                if retained then selected=refined;proposed=refined;details=refined_details
                else simplify_reason='final-validation-or-spacing' end
            end
            if active then log('PREFERENCE_STRAIGHTEN mover='..mover.id..' applied='..tostring(retained)
                ..' reason='..tostring(simplify_reason)..' attempts='..(attempts or 0)..' cells='..(visits or 0)
                ..' before_points='..before_points..' after_points='..#selected
                ..' before_overlap='..before_overlap..' after_overlap='..details.preferred_overlap
                ..' removed='..(retained and removed or 0)..' turn_radians_before='..tostring(before_turns or -1)
                ..' turn_radians_after='..tostring(after_turns or -1)) end
        end
        if active and reason~='preferred' then
            if preference_diagnostic_run~=run then preference_diagnostic_run=run;preference_diagnostic_count=0 end
            if preference_diagnostic_count<12 then
                preference_diagnostic_count=preference_diagnostic_count+1
                -- Extra reads are rejection-only, independent of selection budgets.
                -- Observer errors never disable preference or change the result.
                local diagnostic_ok,diagnostic_lines=pcall(function()
                    local extra=0
                    local function explain(c)
                        if c and not c.occupancy then
                            c.occupancy=preference_diagnostics.occupancy(c.raw,actors,c.x,c.y,attack_policy.footprint)
                            if c.occupancy_open==nil then
                                local o=c.occupancy
                                c.occupancy_open=not o.static and o.hostile_count==0 and o.unknown_phase_count==0
                                    and o.expected_low<8 and o.expected_high<8
                                    and o.expected_low==o.actual_low and o.expected_high==o.actual_high
                            end
                        end
                        return c
                    end
                    return preference_diagnostics.report({mover=mover.id,id=preference_diagnostic_count,
                        width=width,height=height,reason=reason,baseline=points,preferred=proposed,
                        policy=preference_policy,clock=clock,first_failure=explain(first_failure),
                        new_cells=function() return extra end,
                        check=function(x,y)
                            if x<0 or y<0 or x>=width or y>=height then
                                return {x=x,y=y,cost='out-of-bounds',occupancy_open=false,open=false,observed='diagnostic'}
                            end
                            local key=y*width+x
                            if observations[key] then return explain(observations[key]) end
                            if cache[key]==true then
                                return {x=x,y=y,cost='cached-clear',open=true,occupancy_open=true,observed='decision'}
                            end
                            if extra>=128 then return nil end
                            extra=extra+1;point.x=x;point.y=y
                            local cost=bitmap_ud:GetCost(point,terrain,0,tile,1)
                            assert(type(cost)=='number' and cost>=0 and cost<=255,'diagnostic terrain cost')
                            local raw=EEex_ReadU8(live+key)
                            local c=explain({x=x,y=y,cost=cost,raw=raw,observed='diagnostic'})
                            c.open=cost~=255 and c.occupancy_open
                            observations[key]=c
                            return c
                        end})
                end)
                if diagnostic_ok then
                    for _,line in ipairs(diagnostic_lines) do pcall(log,line) end
                else pcall(log,'PREFERENCE_DIAGNOSTIC_SKIPPED mover='..mover.id..' error='..tostring(diagnostic_lines)) end
            end
        end
    end)
    trace.candidate=proposed
    trace.mark('validate')
    if reason~='preferred' then return preference_keep(sprite,reason) end
    if clock()-evaluation_started>8 then
        log('PREFERENCE_BUDGET_DISABLED evaluation_ms='..(clock()-evaluation_started))
        MRIP_PreferenceEnabled=false;EEex_Write32(preference_state,0)
        feedback('visual route preference OFF after slow evaluation; movement stays ON')
        return preference_keep(sprite,'evaluation-budget')
    end
    if not MRIP_PreferenceEnabled or not movement_ready() or EEex_UDToPtr(sprite.m_pArea)~=ap
        or sprite.m_curAction.m_actionID~=23 or sprite.m_curAction.m_dest.x~=goal.x or sprite.m_curAction.m_dest.y~=goal.y
        or EEex_ReadPtr(bitmap+0x120)~=live then return preference_keep(sprite,'changed-context') end
    for i,p in ipairs(points) do if EEex_Read32(path+(i-1)*4)~=p.x+(319-p.y)*320 then return preference_keep(sprite,'changed-baseline') end end
    -- Temporary output only. Native commits after return; a fresh message can
    -- receive a larger allocation from the same game CRT, never a claimed capacity.
    n=#selected -- A repaired corner may have inserted a verified local point.
    for i,p in ipairs(selected) do EEex_Write32(output+(i-1)*4,p.x+(319-p.y)*320) end
    preference_proposal={id=mover.id,count=n,record=active,context=context,points=selected,text='mover='..mover.id
        ..' backend='..(weights and 'soft-route' or 'native-footprints')
        ..' source='..(message_route and 'message' or direct and 'direct' or 'searched')
        ..' baseline='..details.baseline_length..' preferred='..details.preferred_length..' points='..n..' query_ms='..elapsed
        ..' baseline_overlap='..details.baseline_overlap..' preferred_overlap='..details.preferred_overlap}
    if active then log('PREFERENCE_PROPOSED '..preference_proposal.text) end
    return n
end
function MRIP_PreferenceCommit(sprite,count,status)
    local proposal=preference_proposal
    preference_proposal=nil
    if not proposal or not sprite or proposal.id~=sprite.m_id or proposal.count~=count then return end
    if status==1 then preference_routes.replace(proposal.context,proposal.points) end
    if not proposal.record or not active then return end
    if status==1 then log('PREFERENCE_USED '..proposal.text)
    else
        local reason=({[-1]='native-capacity',[-2]='message-changed',[-3]='native-endpoints',[-4]='path-allocation'})[status]
        preference_keep(sprite,reason or 'native-commit-refused')
    end
end
function MRIP_PreferenceDelivered(sprite)
    local ok,err=pcall(function()
        local now=MRIP_PreferenceEnabled and movement_ready()
        if not now then preference_routes.reset();return end
        local c=preference_context(sprite)
        local bound=preference_routes.bind(c,now)
        if active and bound then log('PREFERENCE_ROUTE_BOUND mover='..c.id..' points='..c.count..' cursor='..c.cursor) end
    end)
    if not ok then preference_fail('route-delivery: '..tostring(err)) end
end
function MRIP_PreferencePath(sprite,path,count,output,caller,message)
    if preference_busy then return 0 end
    preference_busy=true
    -- Record stage durations and defer file/console writes until computation
    -- ends. Log formatting stays inside the existing overall evaluation cap.
    local messages,timings={},{}
    local started,stage_started=clock(),clock()
    local trace={}
    trace.emit=function(text) if #messages<64 then messages[#messages+1]=text end end
    trace.mark=function(stage)
        local now=clock();timings[stage]=now-stage_started;stage_started=now
    end
    local ok,result=pcall(preference_select,sprite,path,count,output,caller,message,trace)
    local compute_ms=clock()-started
    -- New observer formatting and I/O happen after the policy's time gates.
    -- Never reread the map, call the planner, or change a computed result here.
    if trace.enabled then
        preference_evaluation=preference_evaluation+1
        local evaluation=preference_evaluation
        if preference_proposal then preference_proposal.text=preference_proposal.text..' evaluation='..evaluation end
        for i,text in ipairs(messages) do messages[i]=text..' evaluation='..evaluation end
        local decision=not ok and 'error' or result>0 and 'proposed' or trace.reason or 'baseline'
        local observer_ok,observer_error=pcall(function()
            if active and trace.baseline then
                if preference_geometry_run~=run then preference_geometry_run=run;preference_geometry_count=0 end
                if preference_geometry_count<route_observer.limit then
                    preference_geometry_count=preference_geometry_count+1
                    local lines=route_observer.geometry({mover=sprite.m_id,evaluation=evaluation,decision=decision,
                        backend=trace.backend or 'none',source=trace.source,width=trace.width,height=trace.height,
                        gx=trace.gx,gy=trace.gy,baseline=trace.baseline,candidate=trace.candidate})
                    for _,text in ipairs(lines) do pcall(log,text) end
                end
            end
            local slow=compute_ms>8 or (timings.query or 0)>4
            local emit_slow=false
            if slow then
                local now=clock()
                if not preference_slow_start or now<preference_slow_start or now-preference_slow_start>=route_observer.slow_window then
                    preference_slow_start=now;preference_slow_count=0
                end
                if preference_slow_count<route_observer.slow_limit then
                    preference_slow_count=preference_slow_count+1;emit_slow=true
                end
            end
            if active or emit_slow then
                local text=route_observer.timing({mover=tostring(sprite and sprite.m_id),evaluation=evaluation,
                    backend=trace.backend,actors=trace.actors,route_cells=trace.route_cells,
                    paint_visits=trace.paint_visits,paint_cells=trace.paint_cells,compute_ms=compute_ms,
                    decision=decision,captured=active,tail_ms=math.max(0,started+compute_ms-stage_started),timings=timings})
                if active then pcall(log,'PREFERENCE_TIMING '..text) end
                if emit_slow then pcall(log,'PREFERENCE_SLOW '..text) end
            end
        end)
        if not observer_ok then pcall(log,'PREFERENCE_OBSERVER_SKIPPED evaluation='..evaluation..' error='..tostring(observer_error)) end
    end
    for _,text in ipairs(messages) do log(text) end
    preference_busy=false
    if not ok then preference_fail(result);return 0 end
    return result
end

local function preference_allocation_body()
    return {[[
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_PlannerState)
        cmp dword ptr [rax], 1
        jne preference_allocation_exit
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne preference_allocation_exit
        cmp ecx, 8
        jne preference_allocation_exit
        mov ecx, 1024
        preference_allocation_exit:
        pop rax
        #STACK_MOD(-8)
        popfq
        #STACK_MOD(-8)
    ]]}
end

local function preference_path_body()
    return EEex_FlattenTable({{[[
        #STACK_MOD(8)
        pushfq
        #STACK_MOD(8)
        push rax
        #STACK_MOD(8)
        mov rax, #L(MRIP_PlannerState)
        cmp dword ptr [rax], 1
        jne preference_path_fast_exit
        mov rax, #L(MRIP_ring)
        cmp dword ptr [rax+56], 1
        jne preference_path_fast_exit
        test rdx, rdx
        jz preference_path_fast_exit
        cmp r8d, 2
        jl preference_path_fast_exit
        cmp r8d, 256
        ja preference_path_fast_exit
        push rcx
        #STACK_MOD(8)
        mov rcx, qword ptr gs:[48h]
        cmp ecx, dword ptr [rax+60]
        jne preference_path_wrong_thread
        pop rcx
        #STACK_MOD(-8)
        pop rax
        #STACK_MOD(-8)
        #MAKE_SHADOW_SPACE(1328)
        mov [rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
        mov [rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
        mov [rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
        mov [rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
        mov [rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
        mov [rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
        movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1192)], 0
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1200)], 0
        mov rax,[rsp+#LAST_FRAME_TOP(8)]
        mov rdx,#L(MRIP_MessageReturn)
        cmp rax,rdx
        jne preference_path_not_message
        mov [rsp+#SHADOW_SPACE_BOTTOM(-1200)],rdi
        preference_path_not_message:
    ]]},EEex_GenLuaCall('MRIP_PreferencePath',{
        args={
            function(o) return {'mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-16)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}},'CGameSprite' end,
            function(o) return {'mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-24)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
            function(o) return {'mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-32)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
            function(o) return {'lea rax,[rsp+#SHADOW_SPACE_BOTTOM(-1184)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
            function(o) return {'mov rax,[rsp+#LAST_FRAME_TOP(8)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
            function(o) return {'mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-1200)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
        },returnType=EEex_LuaCallReturnType.Number,
    }),{[[
        mov [rsp+#SHADOW_SPACE_BOTTOM(-1192)], eax
        jmp preference_path_commit
        call_error:
        jmp preference_path_restore
        preference_path_commit:
        mov r10d,[rsp+#SHADOW_SPACE_BOTTOM(-1192)]
        cmp r10d, 2
        jl preference_path_restore
        cmp r10d, 256
        ja preference_path_restore
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)], -1
        mov r8,[rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx,[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov r11,[rsp+#SHADOW_SPACE_BOTTOM(-1200)]
        test r11,r11
        jz preference_path_existing_capacity
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)], -2
        cmp [r11+18h],rdx
        jne preference_path_notify
        cmp [r11+10h],r8w
        jne preference_path_notify
        cmp word ptr [r11+20h],1
        jne preference_path_notify
        mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-16)]
        cmp [rax+4758h],rdx
        je preference_path_notify
        jmp preference_path_capacity_ok
        preference_path_existing_capacity:
        cmp r10d,r8d
        jle preference_path_capacity_ok
        cmp r8d, 2
        jne preference_path_notify
        mov rax,[rsp+#LAST_FRAME_TOP(8)]
        mov rcx,#L(MRIP_DirectReturnA)
        cmp rax,rcx
        je preference_path_capacity_ok
        mov rcx,#L(MRIP_DirectReturnB)
        cmp rax,rcx
        jne preference_path_notify
        preference_path_capacity_ok:
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)], -3
        lea r11,[rsp+#SHADOW_SPACE_BOTTOM(-1184)]
        mov eax,[r11]
        cmp eax,[rdx]
        jne preference_path_notify
        mov eax,[r11+r10*4-4]
        cmp eax,[rdx+r8*4-4]
        jne preference_path_notify
        mov qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1216)],0
        cmp qword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1200)],0
        je preference_path_copy_ready
        cmp r10d,r8d
        jle preference_path_copy_ready
        ; Nonthrowing malloc from the same game CRT used by operator new[].
        ; No baseline or owner field changes until allocation succeeds.
        lea ecx,[r10*4]
        call #L(MRIP_PathMalloc)
        test rax,rax
        jnz preference_path_allocated
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)],-4
        jmp preference_path_notify
        preference_path_allocated:
        mov [rsp+#SHADOW_SPACE_BOTTOM(-1216)],rax
        mov rdx,rax
        mov r10d,[rsp+#SHADOW_SPACE_BOTTOM(-1192)]
        preference_path_copy_ready:
        lea r11,[rsp+#SHADOW_SPACE_BOTTOM(-1184)]
        xor r9d,r9d
        preference_path_copy:
        mov eax,[r11+r9*4]
        mov [rdx+r9*4],eax
        inc r9d
        cmp r9d,r10d
        jl preference_path_copy
        mov [rsp+#SHADOW_SPACE_BOTTOM(-32)],r10
        mov r11,[rsp+#SHADOW_SPACE_BOTTOM(-1200)]
        test r11,r11
        jz preference_path_committed
        mov [r11+10h],r10w
        mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-1216)]
        test rax,rax
        jz preference_path_committed
        mov [r11+18h],rax
        mov rcx,[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov [rsp+#SHADOW_SPACE_BOTTOM(-24)],rax
        call #L(MRIP_PlannerFree)
        preference_path_committed:
        mov dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)],1
        preference_path_notify:
    ]]},EEex_GenLuaCall('MRIP_PreferenceCommit',{
        args={
            function(o) return {'mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-16)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}},'CGameSprite' end,
            function(o) return {'mov eax,[rsp+#SHADOW_SPACE_BOTTOM(-1192)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
            function(o) return {'movsxd rax,dword ptr [rsp+#SHADOW_SPACE_BOTTOM(-1208)] #ENDL mov [rsp+#$(1)],rax #ENDL',{o}} end,
        },labelSuffix='_commit',
    }),{[[
        call_error_commit:
        preference_path_restore:
        movdqu xmm5,[rsp+#SHADOW_SPACE_BOTTOM(-152)]
        movdqu xmm4,[rsp+#SHADOW_SPACE_BOTTOM(-136)]
        movdqu xmm3,[rsp+#SHADOW_SPACE_BOTTOM(-120)]
        movdqu xmm2,[rsp+#SHADOW_SPACE_BOTTOM(-104)]
        movdqu xmm1,[rsp+#SHADOW_SPACE_BOTTOM(-88)]
        movdqu xmm0,[rsp+#SHADOW_SPACE_BOTTOM(-72)]
        mov r11,[rsp+#SHADOW_SPACE_BOTTOM(-56)]
        mov r10,[rsp+#SHADOW_SPACE_BOTTOM(-48)]
        mov r9,[rsp+#SHADOW_SPACE_BOTTOM(-40)]
        mov r8,[rsp+#SHADOW_SPACE_BOTTOM(-32)]
        mov rdx,[rsp+#SHADOW_SPACE_BOTTOM(-24)]
        mov rcx,[rsp+#SHADOW_SPACE_BOTTOM(-16)]
        mov rax,[rsp+#SHADOW_SPACE_BOTTOM(-8)]
        #DESTROY_SHADOW_SPACE
        jmp preference_path_flags
        preference_path_wrong_thread:
        #STACK_MOD(8)
        pop rcx
        #STACK_MOD(-8)
        preference_path_fast_exit:
        pop rax
        preference_path_flags:
        popfq
        #STACK_MOD(-8)
        #STACK_MOD(-8)
    ]]}})
end

local function preference_install()
    local ok,err=pcall(function()
        -- All optional signatures are checked before allocation or patching.
        for _,s in ipairs(preference_signatures) do
            for i,v in ipairs(s.bytes) do assert(EEex_ReadU8(base+s.rva+i-1)==v,'preference native signature mismatch: '..s.name) end
        end
        assert(type(EEex_Memcpy)=='function' and type(EEex_Memset)=='function' and type(EEex_WritePtr)=='function','preference memory APIs unavailable')
        preference_state=EEex_Malloc(64)
        assert(preference_state and preference_state~=0,'preference state allocation')
        for o=0,60,4 do EEex_Write32(preference_state+o,0) end
        local labels={MRIP_PlannerState=preference_state,MRIP_PlannerConstruct=base+0x225300,
            MRIP_PlannerDestruct=base+0x225430,MRIP_PlannerFind=base+0x2258B0,MRIP_PlannerGet=base+0x225FC0,
            MRIP_PlannerCopy=base+0x4FA710,MRIP_PlannerFree=base+0x45E690,
            MRIP_PoolReferences=base+0x667920,MRIP_PoolPointer=base+0x667928,MRIP_PoolCapacity=base+0x667930,
            MRIP_PathMalloc=base+0x502678,MRIP_SnapshotCost=base+0x24E5A0,MRIP_ring=buffer}
        for name,address in pairs(labels) do EEex_DefineAssemblyLabel(name,address) end
        EEex_JITNearAsLuaFunction('MRIP_PreferenceQueryNative',{planner_native.query()})
        assert(type(MRIP_PreferenceQueryNative)=='function','preference bridge registration failed')
        MRIP_PreferenceNativeBody=preference_path_body()
        MRIP_PreferenceDepthBodies={planner_native.depth(1),planner_native.depth(-1)}
        MRIP_PreferenceAllocationBody=preference_allocation_body()
        MRIP_PreferenceCostBody=shared_native.cost()
        MRIP_PreferenceDeliveryBody=shared_native.delivered()
        local cost_wrapper=EEex_JITNear({MRIP_PreferenceCostBody})
        local cost_patches={}
        for _,site in ipairs({0x2255A6,0x2256C6,0x225D7B,0x226321,0x2263D8}) do
            cost_patches[#cost_patches+1]={site,shared_native.call_patch(base+site,cost_wrapper)}
        end
        EEex_DisableCodeProtection()
        EEex_HookBeforeRestoreWithLabels(base+0x2258B0,0,7,7,{{'MRIP_PlannerState',preference_state}},MRIP_PreferenceDepthBodies[1])
        EEex_HookBeforeRestoreWithLabels(base+0x225F81,0,7,7,{{'MRIP_PlannerState',preference_state}},MRIP_PreferenceDepthBodies[2])
        for _,site in ipairs({0x375ED9,0x376333}) do
            EEex_HookBeforeCallWithLabels(base+site,{{'MRIP_PlannerState',preference_state},{'MRIP_ring',buffer},
                {'hook_integrity_watchdog_ignore_registers',{EEex_HookIntegrityWatchdogRegister.RCX}}},MRIP_PreferenceAllocationBody)
        end
        EEex_HookBeforeRestoreWithLabels(base+0x374CD0,0,10,10,{{'MRIP_PlannerState',preference_state},{'MRIP_ring',buffer},
            {'MRIP_DirectReturnA',base+0x375FA3},{'MRIP_DirectReturnB',base+0x3763CC},
            {'MRIP_MessageReturn',base+0x215470},
            {'hook_integrity_watchdog_ignore_registers',{EEex_HookIntegrityWatchdogRegister.R8,EEex_HookIntegrityWatchdogRegister.RDX}}},MRIP_PreferenceNativeBody)
        EEex_HookBeforeRestoreWithLabels(base+0x374D16,0,6,6,{{'MRIP_PlannerState',preference_state},
            {'MRIP_ring',buffer}},MRIP_PreferenceDeliveryBody)
        for _,patch in ipairs(cost_patches) do
            EEex_JITAt(base+patch[1],patch[2])
        end
        EEex_EnableCodeProtection()
    end)
    EEex_EnableCodeProtection()
    if not ok then preference_fail(err);return false end
    preference_available=true
    log('PREFERENCE_READY enabled=false scope=singleplayer-Move23 node_budget=2048 rate=6-per100ms soft_route_cost=1 band=18')
    return true
end

local install_ok,install_err=pcall(function()
    base=EEex_Label("CMessageHandler::AddMessage")-0x204EC0
    for _,spec in ipairs(specs) do
        for index,expected in ipairs(spec.bytes) do
            if EEex_ReadU8(base+spec.rva+index-1)~=expected then error("signature mismatch at "..spec.name) end
        end
        if spec.target and base+spec.rva+5+EEex_Read32(base+spec.rva+1)~=base+spec.target then error("call target mismatch at "..spec.name) end
    end
    assert(EEex_Label("CGameObjectArray::GetShare")==base+0x276700,"worker GetShare label mismatch")
    assert(EEex_Label("g_pBaldurChitin")==base+0x667548,"worker chitin global mismatch")
    local layout_errors={}
    for field,offset in pairs({
        ["CGameSprite.m_id"]=0x48,["CGameSprite.m_objectType"]=8,
        ["CGameSprite.m_typeAI.m_EnemyAlly"]=0x38,["CGameSprite.m_pos"]=0xC,
        ["CGameSprite.m_pArea"]=0x18,["CGameSprite.m_curAction.m_actionID"]=0x3F8,
        ["CGameSprite.m_baseStats.m_generalState"]=0x578,
        ["CGameSprite.m_derivedStats.m_generalState"]=0x1120,
        ["CGameSprite.m_tempStats.m_generalState"]=0x1DC8,
        ["CGameSprite.m_bAllowEffectListCall"]=0x4EA4,
        ["EEex_CBaldurChitin.m_pObjectGame"]=0x1090,["EEex_CInfGame.m_charactersPortrait"]=0x6618,
    }) do
        local ok,actual=pcall(EEex_OffsetOf,field)
        if not ok then
            layout_errors[#layout_errors+1]=field..": "..tostring(actual)
        elseif actual~=offset then
            layout_errors[#layout_errors+1]=string.format("%s expected=0x%X actual=0x%X",field,offset,actual)
        end
    end
    assert(#layout_errors==0,"worker field layout validation failed: "..table.concat(layout_errors," | "))
    buffer=EEex_Malloc(header_size+queue_size*stride)
    for offset=0,header_size-4,4 do EEex_Write32(buffer+offset,0) end
    for slot=0,5 do EEex_Write32(buffer+32+slot*4,-1) end
    route_context=EEex_Malloc(48)
    for offset=0,44,4 do EEex_Write32(route_context+offset,0) end
    local attack_context=EEex_Malloc(24)
    for offset=0,20,4 do EEex_Write32(attack_context+offset,0) end
    local labels={{"MRIP_ring",buffer}}
    local bodies={
        recorder(1,0x34744B,"rsi",nil,"mov rax, qword ptr ss:[rbp-19h]",nil,"movzx eax, byte ptr ss:[rsp+48]"),
        recorder(2,0x347463,"rsi",nil,"mov rax, qword ptr ss:[rbp-19h]","mov rax, qword ptr ss:[rbp-11h]"),
        recorder(3,0x347463,"rsi",nil,"mov rax, qword ptr ss:[rbp-19h]",nil,"mov eax, dword ptr ss:[rsp+48]"),
        recorder(4,0x34F5A3,"qword ptr ss:[rbp-50h]","r13"),
        recorder(5,0x34FAAD,"qword ptr ss:[rbp-50h]","rcx","mov rax, qword ptr ss:[rsp+32]"),
        recorder(6,0x34FAAD,"qword ptr ss:[rbp-50h]","rbx","mov rax, qword ptr ss:[rbp-70h]"),
        recorder(7,0x34FBCF,"qword ptr ss:[rbp-50h]","rcx","mov rax, qword ptr ss:[rsp+32]"),
        recorder(8,0x34FBCF,"qword ptr ss:[rbp-50h]","rdi","mov rax, qword ptr ss:[rbp-70h]"),
    }
    MRIP_TraceNativeBodies=bodies -- offline assembly verification
    EEex_DisableCodeProtection()
    local hooked,hook_err=pcall(function()
        MRIP_SnapshotNativeBody=snapshot_body()
        EEex_HookBeforeRestoreWithLabels(base+0x24E1F6,0,7,7,{{"MRIP_ring",buffer}},MRIP_SnapshotNativeBody)
        local filter=pass_body()
        local route_before,route_after=route_context_body(true),route_context_body(false)
        local route_filter=route_cost_body()
        MRIP_RouteNativeBodies={route_before,route_after,route_filter}
        local yield_filter=yield_body()
        MRIP_YieldNativeBody=yield_filter
        EEex_HookAfterRestoreWithLabels(base+0x3473A3,0,10,10,{
            {"MRIP_ring",buffer},{"manual_return",true},
            {"MRIP_yield_return",base+0x3473AD},{"MRIP_yield_continue",base+0x34740A},
        },EEex_FlattenTable({yield_filter,{[[
            jmp_fail:
            #MANUAL_HOOK_EXIT(0)
            jmp #L(MRIP_yield_return)
            jmp_success:
            #MANUAL_HOOK_EXIT(0)
            jmp #L(MRIP_yield_continue)
        ]]}}))
        local route_labels={{"MRIP_ring",buffer},{"MRIP_route_context",route_context}}
        MRIP_RequestNativeBodies={}
        for _,site in ipairs(route_sites) do
            local entry,exit=request_recorder(9,site),request_recorder(10,site)
            MRIP_RequestNativeBodies[#MRIP_RequestNativeBodies+1]=entry
            MRIP_RequestNativeBodies[#MRIP_RequestNativeBodies+1]=exit
            EEex_HookBeforeAndAfterCallWithLabels(base+site,route_labels,
                EEex_FlattenTable({route_before,entry}),EEex_FlattenTable({exit,route_after}))
        end
        local readiness=recorder(11,0x3467F2,"qword ptr ss:[rsp+40]")
        MRIP_RequestNativeBodies[#MRIP_RequestNativeBodies+1]=readiness
        EEex_HookBeforeRestoreWithLabels(base+0x3467F2,0,7,7,labels,readiness)
        for _,branch in ipairs({{0x24DE7B,1},{0x24DECB,0}}) do
            -- Original worker resolves this selected actor. Eight recorder pushes
            -- add 64 bytes to the worker's original rsp+58h actor slot.
            local selected=recorder(12,branch[1],"qword ptr ss:[rsp+98h]",nil,nil,nil,
                "mov eax, "..branch[2])
            MRIP_RequestNativeBodies[#MRIP_RequestNativeBodies+1]=selected
            if branch[2]==1 then
                EEex_HookBeforeRestoreWithLabels(base+branch[1],0,5,5,labels,selected)
            else
                local worker_filter=worker_body()
                MRIP_WorkerNativeBody=worker_filter
                MRIP_WorkerHookBody=EEex_FlattenTable({selected,worker_filter})
                EEex_HookAfterRestoreWithLabels(base+branch[1],0,5,5,{
                    {"MRIP_ring",buffer},{"manual_return",true},
                    {"MRIP_worker_remove",base+0x24DE80},
                    {"MRIP_worker_keep",base+0x24DED0},
                },MRIP_WorkerHookBody)
            end
        end
        MRIP_AttackNativeBody=attack_body()
        MRIP_AttackContinueBody=attack_continue_body()
        MRIP_AttackReevaluateBody=attack_body(true)
        MRIP_AttackReevaluateContinueBody=attack_continue_body(true)
        MRIP_AttackCaptureBody=attack_capture_body()
        EEex_HookBeforeRestoreWithLabels(base+0x3893E8,0,9,9,{
            {"MRIP_attack_context",attack_context},
        },MRIP_AttackCaptureBody)
        for _,entry in ipairs({{0x389472,0x38955B,MRIP_AttackContinueBody},{0x389D84,0x389E48,MRIP_AttackReevaluateContinueBody}}) do
            EEex_HookAfterRestoreWithLabels(base+entry[1],0,7,7,{
                {"MRIP_ring",buffer},{"MRIP_attack_context",attack_context},{"manual_return",true},
                {"MRIP_attack_stop",base+entry[1]+7},{"MRIP_attack_approach",base+entry[2]},
            },entry[3])
        end
        for _,site in ipairs({0x389569,0x389F39}) do
            EEex_HookRemoveCallWithLabels(base+site,{
                {"MRIP_ring",buffer},{"MRIP_attack_context",attack_context},{"manual_return",true},
                {"MRIP_move_point",base+0x3A6330},{"MRIP_move_object",base+0x3A5C70},
                {"MRIP_attack_return",base+site+5},
            },site==0x389569 and MRIP_AttackNativeBody or MRIP_AttackReevaluateBody)
        end
        EEex_HookAfterRestoreWithLabels(base+0x24C880,0,6,6,{
            {"MRIP_ring",buffer},{"MRIP_route_context",route_context},
            {"manual_return",true},{"MRIP_route_return",base+0x24C886},
            {"hook_integrity_watchdog_ignore_registers",{EEex_HookIntegrityWatchdogRegister.RDX}},
        },EEex_FlattenTable({route_filter,{[[
            #MANUAL_HOOK_EXIT(0)
            test dl, dl
            jmp #L(MRIP_route_return)
        ]]}}))
        MRIP_PassNativeBody=filter -- offline ABI validation
        local cost_labels={{"MRIP_ring",buffer},{"hook_integrity_watchdog_ignore_registers",{EEex_HookIntegrityWatchdogRegister.RAX}}}
        EEex_HookAfterCallWithLabels(base+0x34744B,cost_labels,EEex_FlattenTable({bodies[1],filter}))
        EEex_HookBeforeAndAfterCallWithLabels(base+0x347463,labels,bodies[2],bodies[3])
        MRIP_BumpNativeBody=bump_body()
        EEex_HookBeforeRestoreWithLabels(base+0x34F5A3,0,8,8,{
            {"MRIP_ring",buffer},{"MRIP_bump_next",base+0x34F6B4}
        },EEex_FlattenTable({bodies[4],MRIP_BumpNativeBody}))
        EEex_HookBeforeAndAfterCallWithLabels(base+0x34FAAD,labels,bodies[5],bodies[6])
        EEex_HookBeforeAndAfterCallWithLabels(base+0x34FBCF,labels,bodies[7],bodies[8])
        EEex_HookBeforeRestoreWithLabels(base+0x2FCBC0,0,5,5,{{"MRIP_ring",buffer},{"stack_mod",8}},EEex_FlattenTable({{[[
            pushfq
            #STACK_MOD(8)
            push rax
            #STACK_MOD(8)
            mov rax, #L(MRIP_ring)
            cmp dword ptr ds:[rax], 1
            je mrip_tick_work
            cmp dword ptr ds:[rax+56], 1
            je mrip_tick_work
            push rcx
            #STACK_MOD(8)
            mov ecx, dword ptr ds:[rax+8]
            cmp ecx, dword ptr ds:[rax+12]
            pop rcx
            #STACK_MOD(-8)
            jne mrip_tick_work
            jmp mrip_tick_done
            mrip_tick_work:
            push rcx
            #STACK_MOD(8)
            mov rcx, qword ptr gs:[48h]
            mov dword ptr [rax+60], ecx
            pop rcx
            #STACK_MOD(-8)
            pop rax
            #STACK_MOD(-8)
            #MAKE_SHADOW_SPACE(152)
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)], rax
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)], rcx
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)], rdx
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)], r8
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)], r9
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)], r10
            mov qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)], r11
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-72)], xmm0
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-88)], xmm1
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-104)], xmm2
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-120)], xmm3
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-136)], xmm4
            movdqu [rsp+#SHADOW_SPACE_BOTTOM(-152)], xmm5
        ]]},EEex_GenLuaCall("MRIP_Tick"),{[[
            call_error:
            movdqu xmm5, [rsp+#SHADOW_SPACE_BOTTOM(-152)]
            movdqu xmm4, [rsp+#SHADOW_SPACE_BOTTOM(-136)]
            movdqu xmm3, [rsp+#SHADOW_SPACE_BOTTOM(-120)]
            movdqu xmm2, [rsp+#SHADOW_SPACE_BOTTOM(-104)]
            movdqu xmm1, [rsp+#SHADOW_SPACE_BOTTOM(-88)]
            movdqu xmm0, [rsp+#SHADOW_SPACE_BOTTOM(-72)]
            mov r11, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-56)]
            mov r10, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-48)]
            mov r9, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-40)]
            mov r8, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-32)]
            mov rdx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-24)]
            mov rcx, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-16)]
            mov rax, qword ptr ss:[rsp+#SHADOW_SPACE_BOTTOM(-8)]
            #DESTROY_SHADOW_SPACE
            jmp mrip_tick_flags
            mrip_tick_done:
            pop rax
            mrip_tick_flags:
            popfq
            #STACK_MOD(-8)
        ]]}}))
    end)
    EEex_EnableCodeProtection()
    if not hooked then error(hook_err) end
    MRIP_TraceEnabled=true
    log("HOOKS_READY sites=24 signatures=37 native_events=14 bump_reference="..EEex_ReadU8(base+0x59B002))
end)
if not install_ok then log("DISABLED "..tostring(install_err)) end
if install_ok then preference_install() end
-- Settings change activation/defaults only; all52 movement policy is retained.
MRIP_AttackSpacingEnabled=release_options.AttackSpacing
MRIP_SettleEnabled=release_options.GentleSettle
if release_options.RoutePreference and preference_available then
    MRIP_PreferenceEnabled=true;EEex_Write32(preference_state,1)
end
local function release_persist(key,value)
    local ok,err=pcall(release_config.write,EEex.SetINIString,release_options,key,value)
    if not ok then log('CONFIG_WRITE_ERROR key='..key..' error='..tostring(err)) end
end
for _,entry in ipairs({
    {'MRIP_TogglePass','Movement',function()return pass_mode end},
    {'MRIP_ToggleAttackSpacing','AttackSpacing',function()return MRIP_AttackSpacingEnabled end},
    {'MRIP_ToggleSettle','GentleSettle',function()return MRIP_SettleEnabled end},
    {'MRIP_TogglePreference','RoutePreference',function()return MRIP_PreferenceEnabled end}})do
    local name,key,current=entry[1],entry[2],entry[3]
    local toggle=_G[name]
    _G[name]=function()
        local before=current();toggle()
        if current()~=before then release_persist(key,current()) end
    end
end
if install_ok then
    EEex_GameState_AddInitializedListener(function()
        MRIP_StartupActivation=true
        local ok,err=pcall(function()
            if release_options.Movement and MRIP_TraceEnabled and not pass_mode then MRIP_TogglePass() end
            log('RELEASE_READY version=0.1.2-preview movement='..tostring(pass_mode)
                ..' preference='..tostring(MRIP_PreferenceEnabled)..' spacing='..tostring(MRIP_AttackSpacingEnabled)
                ..' settle='..tostring(MRIP_SettleEnabled)..' capture='..tostring(active))
        end)
        MRIP_StartupActivation=false
        if not ok then movement_disable('release-startup');log('RELEASE_ERROR '..tostring(err)) end
    end)
end
EEex_Key_AddPressedListener(function(key)
    if e==nil or worldScreen~=e:GetActiveEngine() or Infinity_TextEditHasFocus()~=0 or not EEex_Key_IsDown(key_ctrl) or not EEex_Key_IsDown(key_shift) then return end
    local ok,err=pcall(function()
        if key==key_preference then MRIP_TogglePreference()
        elseif key==key_settle then MRIP_ToggleSettle()
        elseif key==key_attack then MRIP_ToggleAttackSpacing()
        elseif key==key_pass then MRIP_TogglePass()
        elseif key==key_start then MRIP_Start()
        elseif key==key_snapshot then MRIP_Snapshot()
        elseif key==key_end then MRIP_Stop() end
    end)
    if not ok then movement_disable("key-error"); if buffer then EEex_Write32(buffer+56,0); EEex_Write32(buffer,0) end; active=false; log("ERROR key-listener "..tostring(err)) end
end)
EEex_Action_AddSpriteStartedActionListener(function(sprite,action)
    preference_reset(sprite)
    local observed,observe_err=pcall(MRIP_MovementAction,sprite,action)
    if not observed then movement_disable("action-error");log("ERROR action "..tostring(observe_err)) end
    if not active or not sprite then return end
    local ok,err=pcall(function() if sprite:getPortraitIndex()~=-1 then log("ACTION_START "..describe(sprite)) end end)
    if not ok then log("ERROR action-listener "..tostring(err)) end
end)
for _,key in ipairs(release_config_warnings)do log('CONFIG_DEFAULT key='..key)end
log("LOADED revision=56 trace_enabled="..tostring(MRIP_TraceEnabled))
