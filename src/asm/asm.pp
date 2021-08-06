{******************************************************************************
 *  asm.pp
 *
 *  This file contains a lot of very important functions which are used in many
 *  other files. There is a lot of assembly here  :-)
 *
 *  Copyleft (C) 2002 GaLi
 *
 *  version 0.2 - ??/??/2001 - GaLi - initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit assembleur;


INTERFACE


function  bitscan (nb : dword) : dword;
function  btod (nb : byte) : dword;
procedure halt;
function  inb (port : word) : byte;
function  ind (port : word) : dword;
procedure int_strcmp (dstr, sstr : pointer);
procedure int_strcopy (len : dword ; sstr, dstr : pointer);
function  inw (port : word) : word;
procedure IO_delay;
function  memd (adr : pointer) : dword;
procedure outb (port : word ; val : byte);
procedure outd (port : word ; val : dword);
procedure outw (port : word ; val : word);
procedure reset_computer;
procedure set_bit (i : dword ; ptr_nb : pointer);
procedure unset_bit (i : dword ; ptr_nb : pointer);
function  wtod (nb : word) : dword;



IMPLEMENTATION



const
   mask : array[0..31] of dword = ($80000000, $40000000, $20000000,
                                   $10000000, $8000000, $4000000, $2000000,
        			   $1000000, $800000, $400000, $200000,
				   $100000, $80000, $40000, $20000,
				   $10000, $8000, $4000, $2000,
				   $1000, $800, $400, $200,
				   $100, $80, $40, $20,
				   $10, $8, $4, $2, $1);



{******************************************************************************
 * halt
 *
 * Stop the system
 *****************************************************************************}
procedure halt; assembler; [public, alias : 'HALT'];

asm
   mov   edi, $B8000
   mov   ax , $0748
   mov   word [edi], ax

   @halt:
      nop
      nop
      nop
   jmp @halt;
end;



{******************************************************************************
 * reset_computer
 *
 * Activate the /RESET pin of the CPU.
 *****************************************************************************}
procedure reset_computer; assembler; [public, alias : 'RESET_COMPUTER'];
asm
   cli

   @wait:
      in    al , $64
      test  al , 2
   jnz @wait

   mov   edi, $472
   mov   word [edi], $1234   { Don't check the RAM again (unlike $4312) }
   mov   al , $FC
   out   $64, al

   @die:
      hlt
      jmp @die
end;



{******************************************************************************
 * memd
 *
 * Input  : pointer to dword
 * Output : dword
 *****************************************************************************}
function memd (adr : pointer) : dword; [public, alias : 'MEMD'];

var
   tmp : dword;

begin

   asm
      mov   esi, adr
      mov   eax, [esi]
      mov   tmp, eax
   end;
   
   result := tmp;

end;



{******************************************************************************
 * bitscan
 *
 * Input  : dword to scan
 * Output : index of the first 'zero bit'
 *
 * This function is used in bitmap scanning. It scans a dword and returns the
 * index of the first 'zero bit'.
 * Scan is done from left to right, so, if nb=$80000000, result is 1.
 *
 * WARNING : This function MUST NOT be called with nb=$FFFFFFFF
 *****************************************************************************}
function bitscan (nb : dword) : dword; [public, alias : 'BITSCAN'];

var
   res : dword;

begin

   asm
      clc
      mov   ecx, 32
      mov   eax, nb

      @continue:
         dec   ecx
         push  eax
	 bt    eax, ecx
         pop   eax
	 jnc   @stop
         jmp   @continue

      @stop:
         mov   res, ecx

   end;

   result := 31 - res;

end;



{******************************************************************************
 * set_bit
 *
 * Input  : bit index, pointer to dword
 * Output : dword with bit indexed set to 1
 *
 * WARNING : i=0 sets bit 31 to 1
 *****************************************************************************}
procedure set_bit (i : dword ; ptr_nb : pointer); [public, alias : 'SET_BIT'];

var
   tmp : dword;

begin

   tmp := mask[i];

   asm
      mov   esi, ptr_nb
      mov   eax, [esi]
      mov   ebx, tmp
      or    eax, ebx
      mov   [esi], eax
   end;

end;



{******************************************************************************
 * unset_bit
 *
 * Input  : bit index, pointer to dword
 * Output : dword with bit indexed set to 0
 *
 * WARNING : i=0 set bit 31 to 0
 *****************************************************************************}
procedure unset_bit (i : dword ; ptr_nb : pointer); [public, alias : 'UNSET_BIT'];

var
   tmp : dword;

begin

   tmp := mask[i];

   asm
      mov   esi, ptr_nb
      mov   eax, [esi]
      mov   ebx, tmp
      not   ebx
      and   eax, ebx
      mov   [esi], eax
   end;

end;



{******************************************************************************
 * outb
 *
 * Input  : destination port, byte to write
 * Output : None
 *
 * Write 'val' to port 'port'
 *****************************************************************************}
procedure outb (port : word ; val : byte); assembler; [public, alias : 'OUTB'];

asm
   mov   dx , port
   mov   al , val
   out   dx , al
end;



{******************************************************************************
 * outw
 *
 * Input : destination port, word to write
 *
 * Write 'val' to port 'port'
 *****************************************************************************}
procedure outw (port : word ; val : word); [public, alias : 'OUTW'];

var
   p   : pointer;

begin

   p := @val;

   asm
      mov   dx , port
      mov   esi, p
      outsw
   end;
end;



{******************************************************************************
 * outd
 *
 * Input  : destination port, dword to write
 * Output : None
 *
 * Write 'val' to port 'port'
 *****************************************************************************}
procedure outd (port : word ; val : dword); [public, alias : 'OUTD'];

var
   p   : pointer;

begin

   p := @val;

   asm
      mov   dx , port
      mov   esi, p
      outsd
   end;
end;



{******************************************************************************
 * inb
 *
 * Input  : source port
 * Output : None
 *
 * Read a byte from port 'port'
 *****************************************************************************}
function inb (port : word) : byte; [public, alias : 'INB'];

var
   tmp : byte;

begin
   asm
      mov   dx , port
      in    al , dx
      mov   tmp, al
   end;

   result := tmp;

end;



{******************************************************************************
 * inw
 *
 * Input  : source port
 * Output : None
 *
 * Read a word from port 'port'
 *****************************************************************************}
function inw (port : word) : word; [public, alias : 'INW'];

var
   tmp : word;
   p : pointer;

begin

   p := @tmp;

   asm
      mov   dx , port
      mov   edi, p
      insw
   end;

   result := tmp;

end;



{******************************************************************************
 * ind
 *
 * Input  : source port
 * Output : None
 *
 * Read a dword from port 'port'
 *****************************************************************************}
function ind (port : word) : dword; [public, alias : 'IND'];

var
   tmp : dword;
   p : pointer;

begin

   p := @tmp;

   asm
      mov   dx , port
      mov   edi, p
      insd
   end;

   result := tmp;

end;



{******************************************************************************
 * btod
 *
 * Input  : byte
 * Output : dword
 *
 * Convert a byte into a dword
 *****************************************************************************}
function btod (nb : byte) : dword; [public, alias : 'BTOD'];

var
   tmp : dword;

begin
   asm
      xor   eax, eax
      mov   al , nb
      mov   tmp, eax
   end;

   result := tmp;

end;



{******************************************************************************
 * wtod
 *
 * Input  : word
 * Output : dword
 *
 * Convert a word into a dword
 *****************************************************************************}
function wtod (nb : word) : dword; [public, alias : 'WTOD'];

var
   tmp : dword;

begin
   asm
      xor   eax, eax
      mov   ax , nb
      mov   tmp, eax
   end;

   result := tmp;

end;



{******************************************************************************
 * int_strcopy
 *
 * Input  : string length, pointer to source and destination strings
 * Output : None
 *
 * This procedure is ONLY used by the Free Pascal Compiler
 *****************************************************************************}
procedure int_strcopy (len : dword ; sstr, dstr : pointer); assembler; [public, alias : 'FPC_SHORTSTR_COPY'];
asm
   push   eax
   push   ecx
   cld

   mov    edi, dstr
   mov    esi, sstr
   mov    ecx, len
   rep    movsb

   pop    ecx
   pop    eax
end;



{******************************************************************************
 * int_strcmp
 *
 * Input  : pointers to source and destination strings
 * Output : EAX is set to 0 if dstr = sstr
 *
 * This procedure is ONLY used by the Free Pascal Compiler
 *****************************************************************************}
procedure int_strcmp (dstr, sstr : pointer); assembler; [public, alias : 'FPC_SHORTSTR_COMPARE'];
asm
   cld
   xor   ebx, ebx
   xor   eax, eax
   mov   esi, sstr
   mov   edi, dstr
   mov   al , [esi]
   mov   bl , [edi]
   inc   esi
   inc   edi
   cmp   eax, ebx   { Same length ? }
   jne   @Fin
   mov   ecx, eax
   rep   cmpsb
@Fin:
end;



{******************************************************************************
 * IO_Delay
 *
 * Delay for I/O operations (not used, I hope)
 *****************************************************************************}
procedure IO_delay; [public, alias : 'IO_DELAY'];
begin
   asm
      nop
      jmp @d1
      @d1:
      nop
      jmp @d2
      @d2:
      nop
   end;
end;



begin
end.
