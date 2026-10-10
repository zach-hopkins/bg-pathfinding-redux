-- Settings change activation/defaults only; all52 movement policy is retained.
MRIP_AttackSpacingEnabled=release_options.AttackSpacing
MRIP_EnemyPrototypeEnabled=release_options.EnemyPrototype
MRIP_SettleEnabled=release_options.GentleSettle
if release_options.RoutePreference and preference_available then
    MRIP_PreferenceEnabled=true;EEex_Write32(preference_state,1)
end
local function release_persist(key,value)
    local ok,err=pcall(release_config.write,EEex.SetINIString,release_options,key,value)
    if not ok then log('CONFIG_WRITE_ERROR key='..key..' error='..tostring(err)) end
end
for _,entry in ipairs({
    {'MRIP_ToggleEnemyPrototype','EnemyPrototype',function()return MRIP_EnemyPrototypeEnabled end},
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
            log('RELEASE_READY version=0.1.9-mp-experimental movement='..tostring(pass_mode)
                ..' preference='..tostring(MRIP_PreferenceEnabled)..' spacing='..tostring(MRIP_AttackSpacingEnabled)
                ..' settle='..tostring(MRIP_SettleEnabled)..' capture='..tostring(active))
        end)
        MRIP_StartupActivation=false
        if not ok then movement_disable('release-startup');log('RELEASE_ERROR '..tostring(err)) end
    end)
end
