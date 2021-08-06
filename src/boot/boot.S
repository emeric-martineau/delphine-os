;******************************************************************************
;
;--[ Fichier ]-----------------------------------------------------------------
;
; ./src/boot/boot.S
;
;--[ Description ]-------------------------------------------------------------
;
; DelphineOS boot sector. It is on the 2 first sectors of the root partition
; (1024 bytes because it's an ext2 partition). /dev/hda, /dev/hdb, /dev/fd0
; and /dev/fd1 are the only drives you can boot from (Because of the BIOS, it's
; not my fault !!!) 
; All logical block size are supported (1Kb, 2Kb or 4Ko).
;
;--[ Version ]-----------------------------------------------------------------
;
; 1.0.3 : by Bubule and GaLi
; 1.0.2 : by Bubule (bubulemaster@free.fr)
; 1.0.1 : by Edo (eco_bvd@libertysurf.fr)
; 1.0.0 : by GaLi (g_cavelier@yahoo.fr)
;
;--[ Optimizations ]-----------------------------------------------------------
;
; Edo, Bubule
;
;--[ Notice ]---------------------------------------------------------------
;
; 'boot.dat' is created by the install program (under linux) and is used
; to load the kernel without doing some calulations during boot execution.
;
; We load the kernel here but it MUST NOT be bigger than 672Kb (text + bss +
; data)
;
;
;
; FIXME : change mkboot.c so that we have the real kernel size !!!
;         (we have to read kernel ELF header to get text, bss and data
;          sections size)
;
;
;
; Little error management (letter print to screen) :
;
; - A : error while reading /dev/hda or /dev/hdb
; - B : error while reading /dev/fd0
; - C : error when calling BIOS in function P_read_block
;
; GPL program
; Compiled with NASM 0.98 under Linux
;
;                                                   Copyleft (C) GaLi Aug. 2001
;
;******************************************************************************

[ORG   0]
[BITS 16]

    ; Constants
    BOOT_SEG      EQU  07C0h
    BUFFER_SEG    EQU  500h
    NEW_BOOT_SEG  EQU  9000h
    FINCHAINE     EQU  00h

    ; In this file, there is important constants !
    %include "./src/boot/boot.dat"

    cli                           ; No interrupts

    mov   ax , BOOT_SEG           ; Set DS, ES and SS value
    mov   ds , ax
    mov   es , ax
    mov   ss , ax
    mov   sp , 1000h              ; 64 Kb stack ( why not ? )

    nop

    ; Clear screen
    
    push  es
    mov   ax , 0B800h
    mov   es , ax
    xor   di , di
    mov   ax , 0720h
    mov   cx , 2000
    rep   stosw
    pop   es

    ; Put cursor in the top left corner

    mov   ah , 02h
    xor   bh , bh
    xor   dx , dx
    int   10h

    ; Change screen color

    mov   si , RGB
    mov   al , 07
    mov   dx , 03C8h
    out   dx , al

    mov   dx , 03C9h
    outsb
    outsb
    outsb

    ; Look on which drive the kernel is

    mov   al , drive                   ; Defined in 'boot.dat'
    cmp   al , 80h                     ; /dev/hda ?
    je    @read_partition_table
    cmp   al , 81h                     ; /dev/hdb ?
    je    @read_partition_table
    cmp   al , 00h                     ; /dev/fd0 ?
    je    @Lread_floppy
    cmp   al , 01h                     ; /dev/fd1 ?
    je    @Lread_floppy

    jmp @hd_error                      ; drive variable is not valid !!!

    @Lread_floppy:
       jmp @read_floppy

    ; We're going to load the kernel from hda or hdb.
    ; First, we get drive parameters then we read the partition table
    ; (Here, ES = BOOT_SEG)

    ; Those variables MUST be in the first 512 bytes of the boot sector

    RGB:
        db 30,45,15    ; Colors : Red, Green, Blue

    cylindres:
        dw 0

    tetes:
        db 0

    secteurs:
        db 0

    cyl_sec_part:
        dw 0

    tete_part:
        db 0

    first_phblock:
        dd 0

    ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ; Error while reading /dev/hda or /dev/hdb
@hd_error:
    mov   ax , 0E41h
    int   10h        ; Prints 'A'
    jmp   @halt

    ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ; Read partition table
@read_partition_table:

    mov   ah , 08h                     ; Get drive informations
    mov   dl , drive
    int   13h
    jc    @hd_error
   
    inc   dh                           ; First head as number 0
    mov   byte [tetes], dh
    push  cx
    and   cl , 63                      ; Clear bits 6 and 7
    mov   byte [secteurs], cl
    pop   ax
    xor   cx , cx
    mov   cl , al
    shl   cx , 2                       ; Keep bits 6 and 7
    mov   cl , ah
    inc   cx                           ; First cylinder as number 0
    mov   word [cylindres], cx
   
    ; Now, we read the partition table

    mov   ax , 0201h                   ; Read 1 sector
    mov   bx , 512
    mov   cx , 0001h                   ; Cylinder 0, sector 1
    mov   dh , 00h                     ; Head 0
    mov   dl , drive
    int   13h
    jc    @hd_error
   
    mov   si , partition_ofs           ; Defined in "boot.dat"
    add   si , 512

    ; Read the 2nd sector of the boot file and the file system superblock

    mov   ax , 0203h                   ; Read 3 sectors
    mov   bx , 512
    mov   cx , word [si + 2]
    mov   word [cyl_sec_part], cx
    inc   cl                           ; 2nd sector in the partition
    mov   dh , byte [si + 1]
    mov   byte [tete_part], dh
    mov   dl , drive
    int   13h
    jc    @hd_error
   
    ; OK, the 1024 bytes of the boot file are loaded

    mov   ax , word [cyl_sec_part]
    xor   ch , ch
    mov   cl , al
    shl   cx , 2
    mov   cl , ah                      ; CX = 1st partition cylinder
    mov   bx , word [cyl_sec_part]
    and   bl , 63                      ; BL = 1st partition sector
    mov   bh , byte [tete_part]
   
    dec   bl

    xor   eax, eax
    mov   al , bl
    push  eax
   
    xor   ax , ax
    mov   al , bh                      ; AL = 1st partition head
    xor   bx , bx
    mov   bl , byte [secteurs]         ; BX = Sectors per track
    mul   bx                           ; DX:AX = AX * BX
    mov   bx , dx
    shl   ebx, 16
    mov   bx , ax                      ; EBX = DX:AX
    pop   eax
    add   eax, ebx
    push  eax
   
    xor   bx , bx
    mov   bl , byte [secteurs]
    mov   ax , cx                      ; Because CX = 1st partition cylinder
    mul   bx
    mov   bx , dx
    shl   ebx, 16
    mov   bx , ax
    xor   eax, eax
    mov   al , byte [tetes]
    mul   ebx
    pop   ebx
    add   eax, ebx
    mov   dword [first_phblock], eax   ; 1st logical block

    jmp   @recopie_boot

    ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ; Error while reading /dev/fd0
@floppy_error:

    mov   ax , 0E42h
    int   10h        ; Prints 'B'
    jmp   @halt

    ;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    ; Loading kernel from /dev/fd0...
    ; Read the 2nd sector of the boot file and the file system superblock
@read_floppy:
   
    mov   ax , 0203h                  ; Read 3 sectors
    mov   bx , 512
    mov   cx , 0002h                  ; Track 0, sector 2
    xor   dx , dx                     ; Head 0, drive 0
    int   13h
    jc    @floppy_error

    mov   byte [secteurs], 18         ; Value for a 1.44 Mb floppy drive
    mov   byte [tetes], 2             ; Value for a 1.44 Mb floppy drive

    ; BOOT_SEG details :     
    ; BOOT_SEG:0000 -> BOOT_SEG:1024 : boot sector     
    ; BOOT_SEG:1024 -> BOOT_SEG:2048 : file system superblock
    ; We're going to copy the boot sector and the superblock at 9000h:0000
    ; DS = BOOT_SEG

    @recopie_boot:

    mov   di , MSG
    call  P_msg_out

    mov   ax , NEW_BOOT_SEG
    mov   es , ax
    xor   di , di
    xor   si , si
    mov   ecx, 512
    rep   movsd                   ; Move 512 dwords (2Kb)

    jmp NEW_BOOT_SEG : @suite_boot

    @suite_boot:

    mov   ax , NEW_BOOT_SEG       ; We have to reload DS and SS
    mov   ds , ax                      
    mov   ss , ax

    ; Read kernel inode

    mov   eax, 1                      ; 1st group descriptor
    mov   ebx, dword [1024 + 20]
    add   eax, ebx
    mov   cx , NEW_BOOT_SEG
    mov   bx , 2048
    call  P_read_block

    mov   eax, dword [2048 + 8]      ; inode table 1st block
    add   eax, kinode_block          ; Defined in 'boot.dat'
    mov   cx , NEW_BOOT_SEG
    mov   bx , 2560
    call  P_read_block

    ; Now, we just have to load the kernel (not so easy :-)     
    ; Kernel can be load between 0x10000 and 0xB8000

    ; Read the 12 direct blocks in the inode

    mov   si , 2560 + kinode_offset + 40
    mov   ecx, 12

    @read_direct_blocks:
        push   ecx
        mov    eax, dword [si]
        cmp    eax, 0000h
        je     @no_more_direct_blocks
        mov    cx , word [KERNEL_SEG]
        mov    bx , word [k_offset]
        call   P_read_block
        add    word [k_offset], word blk_size
        add    si , 4
        pop    ecx
   loop  @read_direct_blocks

   jmp   @read_indirect_blocks

   @no_more_direct_blocks:
      jmp @jmp_kernel
 
   ; Read simple indirection block

    @read_indirect_blocks:
    mov   eax, dword [si]
    cmp   eax, 0000h                 ; More blocks to read ?
    je    @no_more_direct_blocks     ; No !
    mov   cx , BUFFER_SEG
    xor   bx , bx
    call  P_read_block

    xor   si , si
    mov   ecx, blk_size
    shr   ecx, 2                     ; ECX = ECX div 4 = blocks to read 
                                     ; in simple indirection block
    @indirect_loop:
    push  ecx
    mov   eax, dword [es:si]
    cmp   eax, 0000h
    je @no_more_direct_blocks

    jmp @lkj

    db 'B.E.G'                    ; Bubule, Edo, GaLi
    dw 0AA55h                     ; Boot sector signature 

    @lkj:

    mov   cx , word [KERNEL_SEG]
    mov   bx , word [k_offset]
    push  es
    call  P_read_block
    pop   es
    mov   ax , word [k_offset]
    add   ax , blk_size
    mov   word [k_offset], ax
    cmp   ax , 0000h
    je    @inc_kernel_seg
    jmp   @continue

    @inc_kernel_seg:

    mov   bx , word [KERNEL_SEG]
    add   bx , 1000h
    mov   word [KERNEL_SEG], bx

    @continue:

    pop   ecx
    add   si , 4
    loop  @indirect_loop
   
    ; Now, we have to read at least the first block from double indirection
    ; (because logical blocks can be 1Kb long)

    mov   si , 2560 + kinode_offset + 92
    mov   eax, dword [si]           ; EAX = double indirection block
    cmp   eax, 0000h
    je    @jmp_kernel
    mov   cx , BUFFER_SEG
    xor   bx , bx
    call  P_read_block

    mov   eax, dword [es:00]        ; Just read the first block
    mov   cx , BUFFER_SEG
    xor   bx , bx
    call  P_read_block

    xor   si , si
    mov   ecx, blk_size
    shr   ecx, 2                    ; ECX = ECX div 4

    @indirect_loop2:

    push  ecx
    mov   eax, dword [es:si]
    cmp   eax, 0000h
    je    @jmp_kernel
    mov   cx , word [KERNEL_SEG]
    mov   bx , word [k_offset]
    push  es
    call  P_read_block
    pop   es
    mov   ax , word [k_offset]
    add   ax , blk_size
    mov   word [k_offset], ax
    cmp   ax , 0000h
    je    @inc_kernel_seg2
    jmp   @continue2

    @inc_kernel_seg2:

    mov   bx , word [KERNEL_SEG]
    add   bx , 1000h
    mov   word [KERNEL_SEG], bx

    @continue2:

    pop   ecx
    add   si , 4
    loop  @indirect_loop2
   
    @jmp_kernel:

    mov   di , OK
    call  P_msg_out

;mov ax, 1000h
;mov gs, ax
;xor esi, esi
;mov bx, [gs:esi]
;mov ah, 0Eh
;mov al, bl
;int 10h
;mov ah, 0Eh
;mov al, bh
;int 10h

    jmp   1000h:0000h                ; Launching kernel

@halt:
    jmp   @halt

;--[ Data ]-----------------------------------------------------------------
    tmp_cylindre:
        dw 0

    tmp_tete:
        db 0

    tmp_secteur:
        db 0

    truc_qui_tourne:
        db 2Fh,2Dh,5Ch,7Ch        ; /, -, \, |

    KERNEL_SEG:
        dw 1000h

    num_tourne:
        db 0

    k_offset:
        dw 0

    MSG:
        db 'Loading DelphineOS ...  ', FINCHAINE

    OK:
        db 'OK', 0Ah, 0Dh, 0Ah, 0Dh, FINCHAINE

    bios_seg:
        dw 0

    bios_ofs:
        dw 0

;==============================================================================
; This procedure prints an ASCIIZ string using the BIOS
;
; Input  :
;   DS   : string segment
;   DI   : string offset
;
; Output : None
;
; Modify registers : None
;
P_msg_out :
    ; Save registers that will be modified
    push ax
    push cx
    push di

    @Asccii:
    cmp   byte [di] , 00             ; Zero ?
    jz    @FinAffMsg                 ; if end of string, stop
    mov   al, [di]
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
;==============================================================================

;==============================================================================
;
; Converts a logical block number into C/H/S notation
;
; Input :   EAX = Block to read (from filesystem point of view)
;            BX = Buffer offset
;            CX = Buffer segment
;
; Output : tmp_secteur, tmp_tete et tmp_cylindre are initialized and data 
;          from the block is in the buffer
;
; Calculations :
;    Sector = 1 + ( BIOS_BLOCK mod SECTEURS_PAR_PISTE )
;    Head = ( BIOS_BLOCK div SECTEURS_PAR_PISTE ) mod NB_FACES
;    Cylinder = BIOS_BLOCK div ( SECTEURS_PAR_PISTE * NB_FACES )

P_read_block:
   
    pushad

    mov   word [bios_seg], cx
    mov   word [bios_ofs], bx

    ; Block number (from BIOS view)

    mov   cx , blk_size              ; Defined in 'boot.dat'
    shr   cx , 10                    ; CX = CX div 1024 ( 1, 2, 4 )
    cmp   cx , 4
    jne   @log
    dec   cx
   
    @log:

    shl   eax, cl                    ; EAX = EAX * 2^CX

    @test_drive:

    mov   bl , drive                 ; Defined in 'boot.dat'
    cmp   bl , 00h                   ; /dev/fd0 ???
    je    @calculs
    cmp   bl , 01h                   ; /dev/fd1 ???
    je    @calculs

    add   eax, dword [first_phblock] ; 1st logical block in the partition

    @calculs:

    mov   dx , nb_sec                ; Defined dans 'boot.dat'

    @read_log_block:

    push  eax
    push  dx

    mov   ecx, eax                   ; Save EAX in ECX (not in the stack)

    xor   edx, edx
    xor   ebx, ebx
    mov   bl , byte [secteurs]
    div   ebx
    inc   dl
    mov   byte [tmp_secteur], dl     ; DL = division remainder

    mov   eax, ecx

    xor   edx, edx
    xor   ebx, ebx
    mov   bl , byte [secteurs]
    div   ebx                        ; EAX = quotient
    xor   edx, edx
    xor   ebx, ebx
    mov   bl , byte [tetes]
    div   ebx                        ; DL = remainder
    mov   byte [tmp_tete], dl

    xor   ebx, ebx
    mov   bl , byte [secteurs]
    xor   eax, eax
    mov   al , byte [tetes]
    mul   bx                         ; Multiply EBX by nb of heads (AX)
    mov   bx , ax
    mov   eax, ecx
    xor   edx, edx
    div   ebx
    mov   word [tmp_cylindre], ax    ; AX = quotient

    mov   ax , word [bios_seg]
    mov   es , ax
    mov   ax , 0201h                 ; Read 1 sector each time
    mov   cx , word [tmp_cylindre]
    shr   cx , 2
    and   cl , 11000000b             ; CL bits 6 and 7 = cylinder bits 8 and 9

    mov   ch , byte [tmp_secteur]
    or    ch , cl
    mov   cl , ch
   
    mov   bx , word [tmp_cylindre]
    mov   ch , bl
    mov   dh , byte [tmp_tete]
    mov   dl , drive
    mov   bx , word [bios_ofs]
    int   13h
    jc    @blockread_error
    jmp   @fin_read_block
   
    @blockread_error:
       mov   ax , 0E43h
       int   10h
       jmp   @halt

    @fin_read_block:
    
    @debut_truc_qui_tourne:

    mov   bl , byte [num_tourne]
    inc   bl                      ; Next char
    and   bl , 3                  ; BL cannot be greater than 3
    mov   byte [num_tourne] , bl  ; Save number
    xor   bh , bh
    mov   al , byte [truc_qui_tourne + bx]
    mov   ah , 0Ah
    xor   cx , cx
    inc   cx
    int   10h

    pop   dx                      ; Saved at the beginning of @read_log_block
    cmp   dx , 1                  ; More sectors to read ?
    je    @end_read_log_block
    dec   dx
    add   word [bios_ofs], 512
    pop   eax
    inc   eax
    jmp   @read_log_block

    @end_read_log_block:
      
    pop   eax
    popad
    ret
;==============================================================================


ALIGN 1024
