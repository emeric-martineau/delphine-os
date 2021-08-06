{******************************************************************************
 *  init.pp
 * 
 *  IDT initialization
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.0 - ??/??/2001 - GaLi - initial version
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *****************************************************************************}


unit idt_initialisation;


INTERFACE


{$I int.inc}


procedure enable_IRQ (irq : byte);
procedure set_intr_gate (n : dword ; addr : pointer);
procedure set_system_gate (n : dword ; addr : pointer);
procedure set_trap_gate (n : dword ; addr : pointer);

procedure memcpy (src, dest : pointer ; size : dword); external;
procedure printk (format : string ; args : array of const); external;
procedure ignore_int; external;
function  inb (port : word) : byte; external;
procedure outb (port : word ; val : byte); external;

procedure exception_0; external;
procedure exception_1; external;
procedure exception_2; external;
procedure exception_3; external;
procedure exception_4; external;
procedure exception_5; external;
procedure exception_6; external;
procedure exception_7; external;
procedure exception_8; external;
procedure exception_9; external;
procedure exception_10; external;
procedure exception_11; external;
procedure exception_12; external;
procedure exception_13; external;
procedure exception_14; external;
procedure exception_15; external;
procedure exception_16; external;
procedure exception_17; external;
procedure exception_18; external;
procedure exception_19; external;
procedure exception_20; external;
procedure exception_21; external;
procedure exception_22; external;
procedure exception_23; external;
procedure exception_24; external;
procedure exception_25; external;
procedure exception_26; external;
procedure exception_27; external;
procedure exception_28; external;
procedure exception_29; external;
procedure exception_30; external;
procedure exception_31; external;
procedure system_call;  external;



IMPLEMENTATION



{******************************************************************************
 * init_idt
 *
 * Initialisation de l'IDT. Appelée uniquement lors de l'initialisation de
 * DelphineOS
 *****************************************************************************}
procedure init_idt; [public, alias : 'INIT_IDT'];

var
   i : dword;

begin

   asm
      mov   edi, idt_start
      xor   eax, eax
      mov   ecx, 100
      rep   stosd
   end;

   set_intr_gate(0, @exception_0);
   set_intr_gate(1, @exception_1);
   set_intr_gate(2, @exception_2);
   set_intr_gate(3, @exception_3);
   set_intr_gate(4, @exception_4);
   set_intr_gate(5, @exception_5);
   set_intr_gate(6, @exception_6);
   set_intr_gate(7, @exception_7);
   set_intr_gate(8, @exception_8);
   set_intr_gate(9, @exception_9);
   set_intr_gate(10, @exception_10);
   set_intr_gate(11, @exception_11);
   set_intr_gate(12, @exception_12);
   set_intr_gate(13, @exception_13);
   set_intr_gate(14, @exception_14);
   set_intr_gate(15, @exception_15);
   set_intr_gate(16, @exception_16);
   set_intr_gate(17, @exception_17);
   set_intr_gate(18, @exception_18);
   set_intr_gate(19, @exception_19);
   set_intr_gate(20, @exception_20);
   set_intr_gate(21, @exception_21);
   set_intr_gate(22, @exception_22);
   set_intr_gate(23, @exception_23);
   set_intr_gate(24, @exception_24);
   set_intr_gate(25, @exception_25);
   set_intr_gate(26, @exception_26);
   set_intr_gate(27, @exception_27);
   set_intr_gate(28, @exception_28);
   set_intr_gate(29, @exception_29);
   set_intr_gate(30, @exception_30);
   set_intr_gate(31, @exception_31);

   for i := 32 to 49 do
      begin
         set_intr_gate(i, @ignore_int);
      end;

   set_system_gate($30, @system_call);

   enable_IRQ(2);

end;



{******************************************************************************
 * disable_IRQ
 *
 * Entrée : numéro de l'IRQ
 *
 * Désactive l'IRQ passée en paramètre
 *****************************************************************************}
procedure disable_IRQ (irq : byte); [public, alias : 'DISABLE_IRQ'];

var
   tmp : byte;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (irq < 8) then
      begin
         tmp := inb($21);
	 tmp := tmp or pic_mask[irq];
	 outb($21, tmp);
      end
   else
      begin
         tmp := inb($A1);
	 tmp := tmp or pic_mask[irq - 8];
	 outb($A1, tmp);
      end;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * enable_IRQ
 *
 * Entrée : numéro de l'IRQ
 *
 * Active l'IRQ passée en paramètre
 *****************************************************************************}
procedure enable_IRQ (irq : byte); [public, alias : 'ENABLE_IRQ'];

var
   tmp : byte;

begin

   asm
      pushfd
      cli   { Section critique }
   end;

   if (irq < 8) then
      begin
         tmp := inb($21);
	 tmp := tmp and (not pic_mask[irq]);
	 outb($21, tmp);
      end
   else
      begin
         tmp := inb($A1);
	 tmp := tmp and (not pic_mask[irq-8]);
	 outb($A1, tmp);
      end;

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * set_intr_gate
 *
 * Entrée : numéro d'entrée de l'IDT, adresse à pointer
 *
 * Insère une porte d'interruption dans la n-ieme entrée de l'IDT. Le sélecteur
 * de segment de la porte prend la valeur du sélecteur de segment du noyau. Le
 * champ DPL est a 0.
 *****************************************************************************}
procedure set_intr_gate (n : dword ; addr : pointer); [public, alias : 'SET_INTR_GATE'];

var
   ofs         : dword;
   tmp_desc    : idt_desc;
   lsw, msw    : word;
   test, test1 : dword;
   tmp         : pointer;

begin

   ofs := idt_start + (n * 8);
   tmp := @ignore_int;

   asm
      mov   eax, tmp
      mov   test1, eax

      mov   esi, ofs
      mov   ax , word [esi + 6]
      shl   eax, 16
      mov   ax , word [esi]
      mov   test, eax

      mov   eax, addr
      mov   lsw, ax
      shr   eax, 16
      mov   msw, ax
   end;

   if (test <> 0) and (test <> test1) then
       begin
          printk('set_intr_gate: gate %d is already initialized. (preserving current value)\n', [n]);
	  exit;
       end;

   tmp_desc.base1 := lsw;
   tmp_desc.base2 := msw;
   tmp_desc.seg   := $10;   { Sélecteur de segment du code noyau }
   tmp_desc.attr  := $8E00;

   asm
      pushfd
      cli   { Section critique }
   end;

   memcpy(@tmp_desc, pointer(ofs), sizeof(idt_desc));

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * set_system_gate
 *
 * Entrée : numéro de l'entree IDT, adresse à pointer
 *
 * Insère une porte de trappe dans la n-ième entrée de l'IDT. Le sélecteur de
 * segment prend la valeur du sélecteur de segment de code du noyau. Le champ
 * DPL est a 3.
 *****************************************************************************}
procedure set_system_gate (n : dword ; addr : pointer); [public, alias: 'SET_SYTEM_GATE'];

var
   lsw, msw : word;
   tmp_desc : idt_desc;
   ofs      : dword;

begin

   ofs := idt_start + (n*8);

   asm
      mov   eax, addr
      mov   lsw, ax
      shr   eax, 16
      mov   msw, ax
   end;

   tmp_desc.base1 := lsw;
   tmp_desc.base2 := msw;
   tmp_desc.seg   := $10;
   tmp_desc.attr  := $EE00;

   asm
      pushfd
      cli   { Section critique }
   end;

   memcpy(@tmp_desc, pointer(ofs), sizeof(idt_desc));

   asm
      popfd   { Fin section critique }
   end;

end;



{******************************************************************************
 * set_trap_gate
 *
 * Entrée : numéro dans l'IDT, adresse à pointer
 *
 * Similaire à la procédure set_system_gate si ce n'est que le champ DPL est
 * initialisé a 0.
 *****************************************************************************}
procedure set_trap_gate (n : dword ; addr : pointer); [public, alias : 'SET_TRAP_GATE'];

var
   ofs      : dword;
   tmp_desc : idt_desc;
   lsw, msw : word;

begin

   ofs := idt_start + (n*8);

   asm
      mov   eax, addr
      mov   lsw, ax
      shr   eax, 16
      mov   msw, ax
   end;

   tmp_desc.base1 := lsw;
   tmp_desc.base2 := msw;
   tmp_desc.seg   := $10;
   tmp_desc.attr  := $8F00;

   asm
      pushfd
      cli   { Section critique }
   end;

   memcpy(@tmp_desc, pointer(ofs), sizeof(idt_desc));

   asm
      popfd   { Fin section critique }
   end;

end;



begin
end.
