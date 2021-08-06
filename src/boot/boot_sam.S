[ORG 0]
[BITS 16]

   BOOT_SEG     EQU 07C0h
   NEW_BOOT_SEG EQU 9000h

cli

mov   ax , BOOT_SEG
mov   ds , ax
mov   ss , ax
mov   sp , 1000h

mov   ax , NEW_BOOT_SEG
mov   es , ax
xor   di , di
xor   si , si
mov   cx , 512
rep   movsb

jmp   NEW_BOOT_SEG:@suite

@suite:

mov   ax , BOOT_SEG
mov   es , ax

mov   ax , 0201h
mov   bx , 0000h
mov   cx , 0001h
mov   dx , 0180h
int   13h

jmp   BOOT_SEG:0000h
