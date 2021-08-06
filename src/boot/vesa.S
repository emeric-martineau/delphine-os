;******************************************************************************
;
;--[ File ]--------------------------------------------------------------------
;
; ./src/boot/vesa.S
;
;--[ Description ]-------------------------------------------------------------
;
; Switch to a VESA mode (defined by VESA_MODE) with a linear framebuffer
;
;--[ Version ]-----------------------------------------------------------------;
;
; 0.1 by GaLi (g_cavelier@yahoo.fr)
;
;------------------------------------------------------------------------------
;
; GPL Program
; Compiled with NASM 0.98-38 under FreeBSD 5.2.1
;
;                                                  Copyleft (C) GaLi July 2004


;
; VESA_MODE is only available if you have VESA >= 2.0
;
; Possible values for VESA_MODE :
;
;   - 000h : No VESA mode. Normal text mode (80x25)
;   - 111h : 640x480 (64k colors)  => 80x30
;   - 114h : 800x600 (64k colors)  => 100x37
;   - 117h : 1024x768 (64k colors) => 128x48
;
; If VESA_MODE isn't supported, normal text mode will be the default


VESA_MODE EQU 0h


P_vesa:

	pushad
	push gs

	mov   di , 512
	mov   eax, 32454256h
	mov   dword [di], eax
	mov   ax , 4F00h
	int   10h   ; Get VBE2 information

	cmp   ax , 004Fh
	jne   @end_vesa

	jmp   @get_mode_info

	@test_vesa:
	mov   di , 512
	mov   ax , 4F00h
	int   10h   ; Get VESA information

	cmp   ax , 004Fh
	jne   @end_vesa

	; Check if VESA_MODE != 0
	mov   ax , VESA_MODE
	cmp   ax , 0
	je    @end_vesa

	; Check if version >= 2.0
	mov   ax , [di + 4]
	cmp   ax , 0200h
	mov   di , 1024
	jb    @end_vesa

	; Get info for selected VESA_MODE
	@get_mode_info:
	mov   ax , 4F01h
	mov   cx , VESA_MODE
	int   10h
	cmp   ax , 004Fh
	jne   @end_vesa

	; Setting VESA mode
	mov   ax , 4F02h
	mov   bx , VESA_MODE
	add   bx , 4000h   ; (bit 14: Linear frame buffer)
	add   bx , 8000h   ; (bit 15: Clear memory)
	int   10h
	cmp   ax , 004Fh
	jne   @end_vesa

	@end_vesa:

	mov   word [di], 0FFFFh

	pop gs
	popad

	ret


;--[ Data ]--------------------------------------------------------------------
