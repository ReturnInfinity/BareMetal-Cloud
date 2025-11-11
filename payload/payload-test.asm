; =============================================================================
; BareMetal Stub Payload
; Copyright (C) 2008-2025 Return Infinity -- see LICENSE.TXT
; =============================================================================

BITS 64
ORG 0x001E0000
DEFAULT ABS

%INCLUDE "libBareMetal.asm"

start:
	lea rsi, [rel message]		; Load RSI with the relative memory address of string
	mov ecx, 25			; Output 25 characters
	call [b_output]			; Output the string that RSI points to
halt:
	hlt
	jmp halt

message: db 'Replace this test payload', 0
