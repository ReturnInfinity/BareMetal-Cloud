; =============================================================================
; BareMetal Exec
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
;
; This program copies the 8KiB directly after it to program memory and
; executes it. We could use the disk to load a program but for small Assembly
; examples this will work.
; 
; Instructions:
; nasm exec.asm -o exec.bin
; cat exec.bin program.bin > execprogram.bin
; ./baremetal.sh build execprogram.bin
; ./baremetal.sh install
; ./baremetal.sh run
; =============================================================================

BITS 64
ORG 0x001E0000
DEFAULT ABS

start:
	mov esi, payload
	mov rdi, [ProgramLocation]
	mov ecx, 8192/8			; Divide by 8 since we use movsq
	rep movsq
	xor eax, eax
	xor esi, esi
	xor edi, edi
	call [ProgramLocation]
halt:
	hlt
	jmp halt

ProgramLocation:	dq 0xFFFF800000000000

align 16
payload:
