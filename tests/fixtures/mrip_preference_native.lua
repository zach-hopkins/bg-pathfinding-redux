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
        local labels={MRIP_PlannerState=preference_state,MRIP_PlannerConstruct=base+0x2250A0,
            MRIP_PlannerDestruct=base+0x2251D0,MRIP_PlannerFind=base+0x225650,MRIP_PlannerGet=base+0x225D60,
            MRIP_PlannerCopy=base+0x4F9730,MRIP_PlannerFree=base+0x45D6B0,
            MRIP_PoolReferences=base+0x665460,MRIP_PoolPointer=base+0x665468,MRIP_PoolCapacity=base+0x665470,
            MRIP_PathMalloc=base+0x501698,MRIP_SnapshotCost=base+0x24E340,MRIP_ring=buffer}
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
        for _,site in ipairs({0x225346,0x225466,0x225B1B,0x2260C1,0x226178}) do
            cost_patches[#cost_patches+1]={site,shared_native.call_patch(base+site,cost_wrapper)}
        end
        EEex_DisableCodeProtection()
        EEex_HookBeforeRestoreWithLabels(base+0x225650,0,7,7,{{'MRIP_PlannerState',preference_state}},MRIP_PreferenceDepthBodies[1])
        EEex_HookBeforeRestoreWithLabels(base+0x225D21,0,7,7,{{'MRIP_PlannerState',preference_state}},MRIP_PreferenceDepthBodies[2])
        for _,site in ipairs({0x375899,0x375CF3}) do
            EEex_HookBeforeCallWithLabels(base+site,{{'MRIP_PlannerState',preference_state},{'MRIP_ring',buffer},
                {'hook_integrity_watchdog_ignore_registers',{EEex_HookIntegrityWatchdogRegister.RCX}}},MRIP_PreferenceAllocationBody)
        end
        EEex_HookBeforeRestoreWithLabels(base+0x374690,0,10,10,{{'MRIP_PlannerState',preference_state},{'MRIP_ring',buffer},
            {'MRIP_DirectReturnA',base+0x375963},{'MRIP_DirectReturnB',base+0x375D8C},
            {'MRIP_MessageReturn',base+0x215210},
            {'hook_integrity_watchdog_ignore_registers',{EEex_HookIntegrityWatchdogRegister.R8,EEex_HookIntegrityWatchdogRegister.RDX}}},MRIP_PreferenceNativeBody)
        EEex_HookBeforeRestoreWithLabels(base+0x3746D6,0,6,6,{{'MRIP_PlannerState',preference_state},
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
