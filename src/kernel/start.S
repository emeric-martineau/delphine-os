
BITS 32

; Ce fichier définit le point d'entrée du noyau ainsi que la procédure
; qui permet d'effectuer le changement de tache.

EXTERN PASCALMAIN

GLOBAL _start
GLOBAL FARJUMP

SECTION .text

_start:

    mov   eax, 18h
    mov   ds , eax
    mov   es , eax
    mov   fs , eax
    mov   gs , eax
    mov   ss , eax

    mov   eax, 2000h
    mov   esp, eax
    mov   ebp, eax

    jmp PASCALMAIN


FARJUMP:
    push   ebp
    mov    ebp, esp
    mov    ax , word [ebp + 8]
    mov    word [ebp - 2], ax
    mov    eax, dword [ebp + 12]
    mov    dword [ebp - 6], eax
    jmp    dword far [ebp - 6]
    leave
    ret    8
