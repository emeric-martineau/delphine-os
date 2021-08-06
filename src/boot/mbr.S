; DelphineOS "Master Boot Record"
; 
; This file is put on the first sector of the disk image
;
; PLEASE DO NOT MODIFY IT...

[ORG   0]
[BITS 16]


    ; Constants
    BOOT_SEG      EQU  07C0h
    NEW_BOOT_SEG  EQU  9000h
 
    cli

    mov   ax , BOOT_SEG           ; Set DS, ES and SS value
    mov   ds , ax
    mov   es , ax
    mov   ss , ax
    mov   sp , 1000h              ; 4 Kb stack ( why not ? )

    mov   ax , NEW_BOOT_SEG
    mov   es , ax
    xor   di , di
    xor   si , si
    mov   ecx, 128
    rep   movsd                   ; Move 128 dwords (512 bytes)

    jmp NEW_BOOT_SEG : @suite_boot

    @suite_boot:

    mov   ax , NEW_BOOT_SEG       ; We have to reload DS and SS
    mov   ds , ax                      
    mov   ss , ax

    mov   ax , BOOT_SEG
    mov   es , ax
    mov   ax , 0201h		  ; We read one sector
    mov   dl , 80h
    mov   dh , 01h		  ; head
    mov   ch , 00h		  ; cylinder
    mov   cl , 01h		  ; sector
    xor   bx , bx
    int   13h

    jc    @hd_error
    jmp   @no_error

    @hd_error:
       mov   ax , 0E45h
       int   10h        ; Prints 'E'
       @halt:
          jmp   @halt
    
    @no_error:

    jmp BOOT_SEG : 0000h

times 352 db 90h   ; REALLY IMPORTANT !!!
