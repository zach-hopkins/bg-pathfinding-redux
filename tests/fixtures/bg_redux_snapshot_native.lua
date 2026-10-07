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
