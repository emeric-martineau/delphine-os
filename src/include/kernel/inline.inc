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
