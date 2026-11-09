; Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
; Licensed under the MIT License.
;
; void crest_preserve_xmm_invoke(void (*fn)(void*), void* context)
;
; Calls fn(context) and gives back XMM6-XMM15 as they were: Chez Scheme's
; foreign-callable on Windows x64 clobbers them, and that ABI makes them
; callee-saved. See XmmGuard.h.
;
; Frame: 20h bytes of shadow space for the callee, 0A0h bytes to save the ten
; registers (16-byte aligned), 8 bytes of padding so that RSP is 16-byte
; aligned at the call.

.code

crest_preserve_xmm_invoke PROC FRAME
	sub rsp, 0C8h
	.allocstack 0C8h
	movdqu xmmword ptr [rsp+20h], xmm6
	.savexmm128 xmm6, 20h
	movdqu xmmword ptr [rsp+30h], xmm7
	.savexmm128 xmm7, 30h
	movdqu xmmword ptr [rsp+40h], xmm8
	.savexmm128 xmm8, 40h
	movdqu xmmword ptr [rsp+50h], xmm9
	.savexmm128 xmm9, 50h
	movdqu xmmword ptr [rsp+60h], xmm10
	.savexmm128 xmm10, 60h
	movdqu xmmword ptr [rsp+70h], xmm11
	.savexmm128 xmm11, 70h
	movdqu xmmword ptr [rsp+80h], xmm12
	.savexmm128 xmm12, 80h
	movdqu xmmword ptr [rsp+90h], xmm13
	.savexmm128 xmm13, 90h
	movdqu xmmword ptr [rsp+0A0h], xmm14
	.savexmm128 xmm14, 0A0h
	movdqu xmmword ptr [rsp+0B0h], xmm15
	.savexmm128 xmm15, 0B0h
	.endprolog

	mov rax, rcx
	mov rcx, rdx
	call rax

	movdqu xmm6, xmmword ptr [rsp+20h]
	movdqu xmm7, xmmword ptr [rsp+30h]
	movdqu xmm8, xmmword ptr [rsp+40h]
	movdqu xmm9, xmmword ptr [rsp+50h]
	movdqu xmm10, xmmword ptr [rsp+60h]
	movdqu xmm11, xmmword ptr [rsp+70h]
	movdqu xmm12, xmmword ptr [rsp+80h]
	movdqu xmm13, xmmword ptr [rsp+90h]
	movdqu xmm14, xmmword ptr [rsp+0A0h]
	movdqu xmm15, xmmword ptr [rsp+0B0h]
	add rsp, 0C8h
	ret
crest_preserve_xmm_invoke ENDP

end
