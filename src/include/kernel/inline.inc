{* Inline function *}



procedure cli; inline; assembler;
asm
	cli
end;



procedure sti; inline; assembler;
asm
	sti
end;



procedure pushfd; inline; assembler;
asm
	pushfd
end;



procedure popfd; inline; assembler;
asm
	popfd
end;



procedure pushad; inline; assembler;
asm
	pushad
end;



procedure popad; inline; assembler;
asm
	popad
end;



procedure flush_tlb; inline; assembler;
asm
	mov   eax, cr3
	mov   cr3, eax
end;



function page_align (nb : longint) : dword;
begin
   if (nb mod 4096) = 0 then
       result := nb
   else
       result := (nb + 4096) and $FFFFF000;
end;



{*
 * NOTE: may be (nb and $FFF) is faster than (nb mod 4096)
 *}
function page_aligned (nb : longint) : boolean;
begin
   if ((nb mod 4096) <> 0) then
       result := FALSE
   else
       result := TRUE;
end;
