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
    if not MRIP_TraceEnabled then feedback('prototype unavailable; check log');return end
    if active then MRIP_Stop('attack-mode-change') end
    MRIP_AttackSpacingEnabled=not MRIP_AttackSpacingEnabled
    attack_reset()
    log('ATTACK_MODE enabled='..tostring(MRIP_AttackSpacingEnabled))
    feedback(MRIP_AttackSpacingEnabled and 'attack spacing ON; F7=start test' or 'attack spacing OFF; F7=start test')
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
