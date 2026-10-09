local R=dofile('tests/fixtures/bg_redux_release_config.lua')
local checks=0
local function check(value)assert(value);checks=checks+1 end
local defaults,warnings=R.read(function(path,section,key,default)
    check(path=='.\\bg-redux-movement.ini' and section=='Movement' and key~='Movement');return default
end)
check(defaults.Movement and not defaults.EnemyPrototype and defaults.AttackSpacing and defaults.GentleSettle and not defaults.RoutePreference and #warnings==0)
local invalid,warnings=R.read(function()return 'maybe' end)
check(invalid.Movement and not invalid.EnemyPrototype and invalid.AttackSpacing and invalid.GentleSettle and not invalid.RoutePreference and #warnings==4)
local bootstrap=assert(io.open('tests/fixtures/bg_redux_release_bootstrap.lua')):read('*a')
local legacy=R.read(function(_,_,key,default)
    check(key~='Movement');return key=='EnemyPrototype' and '1' or default
end)
check(legacy.Movement and legacy.EnemyPrototype)
for bits=0,15 do
    local values={}
    for i,entry in ipairs(R.keys)do values[entry[1]]=math.floor(bits/2^(i-1))%2==1 and '1' or '0' end
    local options=R.read(function(_,_,key)return values[key] end)
    for i,entry in ipairs(R.keys)do check(options[entry[1]]==(values[entry[1]]=='1')) end
    for _,available in ipairs({true,false})do
        local options=R.read(function(_,_,key)return values[key] end)
        local env={release_config=R,release_options=options,preference_available=available,preference_state=100,
            pass_mode=false,active=false,install_ok=true,MRIP_TraceEnabled=true,MRIP_PreferenceEnabled=false,
            logs={},writes={},native={},disabled=false}
        env._G=env;setmetatable(env,{__index=_G})
        env.EEex={SetINIString=function(_,_,key,value)env.writes[key]=value end}
        env.EEex_Write32=function(address,value)env.native[address]=value end
        env.log=function(line)env.logs[#env.logs+1]=line end
        env.movement_disable=function()env.pass_mode=false;env.disabled=true end
        env.MRIP_TogglePass=function()env.pass_mode=not env.pass_mode end
        env.MRIP_ToggleEnemyPrototype=function()env.MRIP_EnemyPrototypeEnabled=not env.MRIP_EnemyPrototypeEnabled end
        env.MRIP_ToggleAttackSpacing=function()env.MRIP_AttackSpacingEnabled=not env.MRIP_AttackSpacingEnabled end
        env.MRIP_ToggleSettle=function()env.MRIP_SettleEnabled=not env.MRIP_SettleEnabled end
        env.MRIP_TogglePreference=function()if available then env.MRIP_PreferenceEnabled=not env.MRIP_PreferenceEnabled end end
        env.EEex_GameState_AddInitializedListener=function(callback)env.initialized=callback end
        local chunk=assert(loadstring(bootstrap));setfenv(chunk,env);chunk();env.initialized()
        check(env.pass_mode==options.Movement and env.active==false)
        check(env.MRIP_AttackSpacingEnabled==options.AttackSpacing and env.MRIP_SettleEnabled==options.GentleSettle)
        check(env.MRIP_EnemyPrototypeEnabled==options.EnemyPrototype)
        check(env.MRIP_PreferenceEnabled==(options.RoutePreference and available))
        check(not env.disabled)
        if available then
            for _,entry in ipairs({{'MRIP_ToggleEnemyPrototype','EnemyPrototype'},{'MRIP_ToggleAttackSpacing','AttackSpacing'},
                {'MRIP_ToggleSettle','GentleSettle'},{'MRIP_TogglePreference','RoutePreference'}})do
                local before=options[entry[2]];env[entry[1]]()
                check(options[entry[2]]==not before and env.writes[entry[2]]==(before and '0' or '1'))
                env[entry[1]]()
            end
            env.MRIP_ToggleEnemyPrototype()
            local restarted=R.read(function(_,_,key,default)return env.writes[key] or default end)
            check(restarted.EnemyPrototype==env.MRIP_EnemyPrototypeEnabled)
            env.MRIP_TogglePass();check(not env.pass_mode and env.writes.Movement==nil)
            check(restarted.Movement)
            env.MRIP_TogglePass();check(env.pass_mode and env.writes.Movement==nil)
            env.EEex.SetINIString=function()error('fixture write failure')end
            local before=env.MRIP_EnemyPrototypeEnabled;env.MRIP_ToggleEnemyPrototype()
            check(env.MRIP_EnemyPrototypeEnabled~=before and not env.disabled and env.logs[#env.logs]:find('CONFIG_WRITE_ERROR',1,true))
        else
            env.MRIP_TogglePreference();check(env.writes.RoutePreference==nil)
        end
        -- Startup failure is contained and leaves movement off.
        env.release_options.Movement=true;env.pass_mode=false
        env.MRIP_TogglePass=function()error('fixture activation failure')end
        env.initialized();check(env.disabled and not env.pass_mode and env.logs[#env.logs]:find('RELEASE_ERROR',1,true))
    end
end
print('Release configuration/bootstrap: '..checks..' assertions, all16 persistent switch combinations, session movement, optional refusal, persistence failure and startup failure containment')
