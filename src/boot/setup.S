;******************************************************************************
;
;--[ File]------------------------------------------------------------------
;
; ./src/boot/setup.S
;
;--[ Description ]-------------------------------------------------------------
;
; This file is at the beginning of './src/kernel/kernel'. It's a full binary
; file contrary to the kernel which is an ELF binary. It does this :
;
;  - RAM detection : OK (buggy ???)
;  - 32 bits protected mode : OK
;  - Kernel launching : OK
;
;--[ Version ]-----------------------------------------------------------------
;
; 0.9 by GaLi   (g_cavelier@yahoo.fr)
;        Bubule (bubulemaster@free.fr)
;        Edo    (eco_bvd@libertysurf.fr)

;--[ Functions ]---------------------------------------------------------------
; RAM detection : GaLi (2001)
; Keyboard parameters  : Bubule (2001)
; 
;--[ Functions used ]----------------------------------------------------------
; P_msg_out             : print an ASCIIz string (real mode)
; EMPTY_8042            : clear keyboard buffer
;
;------------------------------------------------------------------------------
;
; GPL Program
; Compiled with NASM 0.98 under GNU/Linux
;
;                                                  Copyleft (C) GaLi Oct. 2001


[BITS 16]
[ORG   0]

    ; Constants
    SETUP_SEG EQU 1000h

    ; Shutdown floppy drive motor

    mov   dx , 3F2h
    xor   al , al
    out   dx , al

    ; New stack configuration

    mov   ax , 0E00h
    mov   ss ,  ax
    mov   esp, 2000h
    mov   ebp, 2000h

    mov   ax , SETUP_SEG
    mov   ds , ax
    mov   es , ax
    mov   fs , ax
    mov   gs , ax

    ; Keyboard initialization (maximum rate)
    mov   ax , 0305h
    xor   bx , bx
    int   16h

    ; Activate A20 line (really hard !!!)
    ; Code from Linux

    call  EMPTY_8042
    mov   al , 0D1h               ; Write command
    out   64h, al
    call  EMPTY_8042
    mov   al , 0DFh               ; A20 on
    out   60h, al
    call  EMPTY_8042

;mov ax, 0E41h
;int 10h

    ; OK, A20 line activated (End of code from Linux)

    ; Starting RAM detection (ES = SETUP_SEG)
    ; We register a lot of data at 0x10000 (SETUP_SEG:0000). This data is
    ; read later by mm/init_mem.pp

    times 1280 db 90h   ; To store the bios memory map (512 bytes = 32 entries) and
                        ; VESA information (768 bytes)

    mov   dword [20], 00h

    xor   ebx, ebx
    mov   edi, 24
    @again:
    mov   eax, 0E820h
    mov   ecx, 20
    mov   edx, 534D4150h
    int   15h
    jc    @memE801
    cmp   eax, 534D4150h
    jne   @memE801
    cmp   ecx, 20
    jne   @memE801
    cmp   ebx, 0
    je    @memE801     ; @ram_ok ???
    add   di , 20
    inc   dword [20]
    jmp   @again

    @memE801:
    stc
    xor   cx , cx
    xor   dx , dx
    mov   ax , 0E801h
    int   15h
    jc    @mem88

    cmp   cx , 0
    jne   @usecxdx
    cmp   dx , 0
    jne   @usecxdx
    mov   cx , ax
    mov   dx , bx
    
    @usecxdx:
    and   edx, 0FFFFh
    shl   edx, 6
    and   ecx, 0FFFFh
    add   ecx, edx
    add   ecx, 1024
    jmp   @ram_ok

    @mem88:
    xor   eax, eax
    xor   ecx, ecx
    mov   ah , 88h
    int   15h
    jc    @default_value
    mov   cx , ax
    add   ecx, 1024
    jmp   @ram_ok

    @default_value:
    mov   ecx, 2048

    @ram_ok:
    mov dword [0], ecx

mov   di , 512
mov   ax , 4F00h
int   10h

mov   di , 768
mov   eax, 32454256h
mov   dword [di], eax
mov   ax , 4F00h
int   10h

    ; Check ELF header so that we can launch the kernel

    jmp   @check_header

    @bad_header:
       mov   di , bad_header_str
       call  P_msg_out
       @halt:
       jmp   @halt

    @check_header:

    mov   esi, end_setup          ; ESI points at the ELF header
    mov   eax, [esi]
    cmp   eax, 464C457Fh          ; EAX = ELF magic number ?
    jne   @bad_header             ; Non => invalid header
;    mov   ax , word [esi + 44]    ; AX = Nb of entries in the ELF header
;    cmp   ax , 3
;    jne   @bad_header             ; invalid header : nb of entries <> 3

    mov   eax, dword [esi + 28]   ; Program header table offset in file
    xor   ebx, ebx
    mov   bx , word [esi + 42]    ; Size of 1 entry in the program header table
    add   esi, eax
    
    ; We can now read 'Program header tbale' entries
    ; ESI points at the beginning of the table and EBX = bytes in one entry

    mov   eax, dword [esi + 8]        ; EAX = address where the kernel begins
    mov   dword [kernel_ofs], eax     ; Save it

    ; We save kernel size to print it later. We read each section size.
    ; .text + .bss + .data

    mov   edi, 04h

    mov   eax, dword [esi + 20]       ; EAX = .text section size
    mov   [edi], eax
    add   edi, 4
    add   dword [kernel_size], eax
    mov   eax, dword [esi + ebx + 20] ; EAX = .data section size
    mov   [edi], eax
    add   edi, 4
    add   dword [kernel_size], eax
    add   ebx, ebx
    mov   eax, dword [esi + ebx + 20] ; EAX = .bss section size
    mov   [edi], eax
    add   edi, 4
    add   dword [kernel_size], eax
    add   dword [kernel_size], 1024

    mov   eax, dword [kernel_size]    ; EAX = kernel size in bytes
    shr   eax, 10                     ; EAX = kernel size in Kb

    mov   [edi], eax

    ; 32 bits protected mode initialization

    ; A20 line is already on

    ; PICs programmation  :-(

    mov   al , 00010001b          ; ICW1
    out   20h, al
    nop
    nop
    nop
    out  0A0h, al
    nop
    nop
    nop
    mov   al , 20h                ; INT 20h pour l'IRQ 0
    out   21h, al
    nop
    nop
    nop
    mov   al , 28h                ; INT 28h pour l'IRQ 8
    out  0A1h, al
    nop
    nop
    nop
    mov   al , 00000100b
    out   21h, al
    nop
    nop
    nop
    mov   al , 2
    out  0A1h, al
    nop
    nop
    nop
    mov   al , 1
    out   21h, al
    nop
    nop
    nop
    out  0A1h, al
    nop
    nop
    nop

    mov   al , 0FFh               ; No IRQ from master PIC
    out   21h, al
    mov   al , 0FFh               ; No IRQ from slave PIC
    out  0A1h, al

    ; OK, IRQ 0 to 15 correspond with interrupts 0x20 to 0x2F

    ; Move the GDT at 0x2000

    ; Here, DS = SETUP_SEG and ES = 0x0000

    ; Ask the BIOS cursor position and save it.

    mov   ah , 03h
    xor   bx , bx
    int   10h
    push  dx

    ; Move the GDT

    cld                           ; Clear direction flag
    mov   ax , SETUP_SEG
    mov   ds , ax
    mov   ax , 200h
    mov   es , ax
    xor   di , di
    mov   si , gdt_desc_0
    mov   ecx, 8*6                ; 6 defined descriptors
    rep   movsb

    pop   dx

    xor   eax, eax
    push  eax
    popfd                         ; Eflags = 0 (to be careful)

    lgdt  [GDTR]
    lidt  [IDTR]

    xor   ax , ax
    inc   ax
    lmsw  ax                      ; 16 bits protected mode

    jmp   @flush
@flush:

    ; Jump to kernel

    db 66h,0EAh                   ; 32 bits long jump opcode
kernel_ofs:
    dd 0                          ; Physical address where we want to jump to
    dw 10h

[BITS 16]

;==[ EMPTY_8042 ]==============================================================
; Code from linux

EMPTY_8042:
   
    push  ecx
    mov   ecx, 0FFFFh
   
    @empty_8042_loop:
      dec   ecx
      jz    @empty_8042_end_loop
      nop                         ; Delay
      nop
      nop
      in    al , 64h              ; 8042 status port
      test  al , 1                ; Output buffer ?
      jz    @no_output
      nop
      nop
      nop
      in    al , 60h              ; Read it
      jmp   @empty_8042_loop
      
    @no_output:
      test  al , 2                ; Is input buffer full ?
      jnz   @empty_8042_loop      ; Yes - loop
      
    @empty_8042_end_loop:
      pop   ecx
      ret

;==============================================================================

;==============================================================================
; This procedure prints an ASCIIZ string using the BIOS
;
; Input params :
;   DS : string segment
;   DI : string offset
; Output : non
; Modified registers : non
;
; CopyMiddle Bubule 2001 (Odyssé de l'espace)
;
P_msg_out :
    ; Save registers which will be modified
    push  ax
    push  cx
    push  di

    @Asccii:
    cmp   byte [di] , 00             ; Zero ?
    jz    @FinAffMsg                 ; If end of the string, stop
    mov   al, byte [di]
    mov   ah, 0Eh
    int   10h

    inc   di                         ; next char
    jmp  @Asccii

    @FinAffMsg:

    ; Restore registers
    pop   di
    pop   cx
    pop   ax

    ret

;--[ Data ]--------------------------------------------------------------------

    bad_header_str:
       db 0Ah,0Dh,0Ah,0Dh,'kernel has a bad ELF header, cannot run it !!!', 00

    ram_size:
       dd 0

    ram_str:
       db 0Ah, 0Dh, 0Ah, 0Dh, 'RAM size : ', 00h

    dec_str:
       dd 0, 0, 0, 0
       db 00

    kernel_size:
       dd 0

    IDTR:
       dw 400                     ; IDT size in bytes (50 descriptors)
       dd 100400h                 ; IDT physical address

    GDTR:
       dw 0FFFFh                  ; GDT size (maximum !!!)
       dd 2000h                   ; GDT physical address

    gdt_desc_0:                   ; NULL DESCRIPTOR
       dd 0,0

    gdt_desc_1:                   ; init TSS (DPL 0) (0x08)
       dw 0103                    ; Size = 104 bytes
       dw 0590h                   ; Base = 0x100590
       db 10h
       db 89h
       db 40h
       db 00h                     ; base 3rd part

    gdt_desc_2:                   ; Kernel code descriptor (0x10)
       dw 0FFFFh                  ; Limit 0..15 (4 Gb)
       dw 0000h                   ; Base 0..15
       db 00h                     ; Base 16..23
       db 9Ah                     ; Code, r/x
       db 0CFh
       db 00h

    gdt_desc_3:                   ; Kernel data descriptor (0x18)
       dw 0FFFFh                  ; Limit = 4 Gb
       dw 0000h
       db 00h
       db 92h
       db 0CFh
       db 00h

    gdt_desc_4:                   ; User code descriptor (0x23)
       dw 0FFFFh                  ; Limit = 4 Gb
       dw 0000h                   ; base = 0x0000
       db 00h
       db 0FAh
       db 0CFh
       db 00h

    gdt_desc_5:                   ; User data descriptor (0x2B)
       dw 0FFFFh                  ; Limit = 4 Gb
       dw 00h                     ; Base = 0x0000
       db 00h
       db 0F2h
       db 0CFh
       db 00h

    gdt_end:

ALIGN 8192

end_setup:
