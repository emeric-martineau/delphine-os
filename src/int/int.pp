{******************************************************************************
 *  int.pp
 * 
 *  Ce fichier contient les procédures qui gèrent les exceptions.
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.1 - 20/06/2002 - GaLi - début de la gestion du Copy On Write
 *                                    voir procédure 'exception_14'
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
 ******************************************************************************}


unit int;


INTERFACE

{$DEFINE DEBUG}

{$I fs.inc}
{$I mm.inc}
{$I process.inc}


procedure printk (format : string ; args : array of const); external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure panic (reason : string); external;
procedure print_registers; external;
function  get_phys_adr (adr : pointer) : pointer; external;
function  kmalloc (size : dword) : pointer; external;
function  btod (val : byte) : dword; external;
function  inb (port : word) : byte; external;
function  MAP_NR (adr : pointer) : dword; external;


var
   fpu_present : boolean; external name 'U_CPU_FPU_PRESENT';
   mem_map     : P_page; external name 'U_MEM_MEM_MAP';
   current     : P_task_struct; external name 'U_PROCESS_CURRENT';



IMPLEMENTATION



{******************************************************************************
 * ignore_int
 *
 * Cette routine se déclenche quand une interruption non gérée survient
 *****************************************************************************}
procedure ignore_int; interrupt; [public, alias : 'IGNORE_INT'];

var
   isr1, isr2 : byte;

begin

   outb($20, $B);
   outb($A0, $B);
   asm
      nop
      nop
      nop
      nop
   end;
   isr1 := inb($20);
   isr2 := inb($A0);
   printk('Unknown interrupt', []);
   printk(' (isr1 = %h2 and isr2 = %h2)\n', [btod(isr1), btod(isr2)]);
   outb($A0, $20);      { End of interrupt (EOI) pour l'esclave }
   outb($20, $20);      { EOI pour le maitre }
end;



{******************************************************************************
 * exception_0
 *
 * Se déclenche lors d'une division par zéro
 ******************************************************************************}
procedure exception_0; [public, alias : 'EXCEPTION_0'];
begin
   printk('Exception 0 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_1
 *
 * Se déclenche lors du debuggage
 *****************************************************************************}
procedure exception_1; [public, alias : 'EXCEPTION_1'];
begin
   printk('Exception 1 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_2
 *
 * Se déclenche lors qu'une interruption externe non masquable intervient
 *****************************************************************************}
procedure exception_2; [public, alias : 'EXCEPTION_2'];
begin
   printk('Exception 2 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_3
 *
 * Se déclenche lorsque le processeur rencontre un breakpoint
 *****************************************************************************}
procedure exception_3; [public, alias : 'EXCEPTION_3'];
begin
   printk('Exception 3 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_4
 *
 * Se déclenche lors d'un depassement de capacite
 *****************************************************************************}
procedure exception_4; [public, alias : 'EXCEPTION_4'];
begin
   printk('Exception 4 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_5
 *
 * Se déclenche lors d'un depassement pour l'instruction BOUND
 *****************************************************************************}
procedure exception_5; [public, alias : 'EXCEPTION_5'];
begin
   printk('Exception 5 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_6
 *
 * Se déclenche lorsque le processeur rencontre une instruction inconnue
 *****************************************************************************}
procedure exception_6; [public, alias : 'EXCEPTION_6'];
begin
   printk('Exception 6 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_7
 *
 * Exception 7 is executed when a FPU instruction is executed without FPU or
 * when TS bit (register CR0) is set.
 *****************************************************************************}
procedure exception_7; [public, alias : 'EXCEPTION_7'];

const
   P_i387_regs : pointer = NIL;

begin

   if (fpu_present) then
       begin
          if (P_i387_regs <> NIL) then
	      begin
	         if (P_i387_regs <> current) then
		     begin
		        { Save FPU registers in P_i387_regs structure }
		     end;
	      end;
	  P_i387_regs := current;
	  { Unset TS bit in cr0 }
	  asm
	     mov   eax, cr0
	     or    al , $8
	     mov   cr0, eax
	  end;
       end
   else
       begin
          panic('FPU instruction detected without coprocessor');
       end;

   asm
      leave
      iret
   end;

end;



{******************************************************************************
 * exception_8
 *
 * Se déclenche lors d'une double faute
 *****************************************************************************}
procedure exception_8; [public, alias : 'EXCEPTION_8'];
begin
   printk('Exception 8 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_9
 *
 * Se déclenche lors d'un Coprocessor Segment Overrun
 *****************************************************************************}
procedure exception_9; [public, alias : 'EXCEPTION_9'];
begin
   printk('Exception 9 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_10
 *
 * Se déclenche lors qu'un TSS invalide est rencontré
 *****************************************************************************}
procedure exception_10; [public, alias : 'EXCEPTION_10'];
begin
   printk('Exception 10 : invalid TSS.\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_11
 *
 * Se déclenche lorsqu'un segment est non présent
 *****************************************************************************}
procedure exception_11; [public, alias : 'EXCEPTION_11'];
begin
   printk('Exception 11 : non-present segment.\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_12
 *
 * Se déclenche lorsqu'un segement de pile manque
 *****************************************************************************}
procedure exception_12; [public, alias : 'EXCEPTION_12'];
begin
   printk('Exception 12 : no stack segment.\n', []);
   asm
      hlt
   end;
   {* Si cette exception est déclenchée par un segment de pile non présent ou
    * par un OverFlow de la nouvelle pile, durant un inter-privilege-level
    * class, le code d'erreur contient un sélecteur de segment pour le segment
    * qui a déclenché l'exception. Le gestionnaire d'exception peut tester flag
    * présent dans le descripteur de segment pour determiner la cause. Pour
    * un dépassement simple de pile, le code d'erreur est 0. (voir les docs
    * d'Intel) *}

end;



{******************************************************************************
 * exception_13
 *
 * Se déclenche lorsqu'un processeur tente d'acceder à une zone mémoire qui lui
 * est interdite.
 *****************************************************************************}
procedure exception_13; [public, alias : 'EXCEPTION_13'];

var
   r_cs : word;
   r_cr0, r_cr3, flags : dword;
   esp0 : dword;
   error_code : dword;

begin
   printk('General Protection Fault !!!\n', []);
   
   asm
      mov   eax, [ebp + 4]
      mov   error_code, eax
      mov   ax , cs
      mov  r_cs, ax
      mov   eax, cr0
      mov  r_cr0, eax
      mov   eax, cr3
      mov  r_cr3, eax
      pushfd
      pop  eax
      mov   flags, eax
      mov  eax, esp
      mov  esp0, eax
   end;

printk('CS: %h4  CR0: %h  CR3: %h  flags: %h\n', [r_cs, r_cr0, r_cr3, flags]);
printk('esp: %h  error_code: %h\n', [esp0, error_code]);

   panic('');

end;



{******************************************************************************
 * exception_14
 *
 * Se déclenche lorsqu'une page est demandée et n'est pas présente en mémoire.
 * Il faudra donc gerer la memoire virtuelle ici.
 *****************************************************************************}
procedure exception_14; [public, alias : 'EXCEPTION_14'];

var
   error_code : dword;
   r_cr2      : pointer;
   page_index : dword;
   glob_index : dword;
   fault_adr  : pointer;
   new_page   : pointer;

begin

   asm
      pushad
      sti   { Set interrupts on }
      mov   eax, cr2
      mov   r_cr2, eax
      mov   eax, [ebp + 4]   { Get error code }
      and   eax, 111b
      mov   error_code, eax
   end;

   {$IFDEF DEBUG}
      printk('\n14: %d@%h\n', [error_code, r_cr2]);
   {$ENDIF}

   if (error_code and $4) <> $4 then
       begin
           printk('\nPage fault in kernel (fuckin'' bad news !!!)\n', []);
	   printk('CR2: %h   error_code: %h\n', [r_cr2, error_code]);
	   panic('kernel panic');
       end
   else
       begin
           if (error_code and $1) = $1 then
	       begin
	           {* printk('\nCurrent process is trying to access a protected page => killing it...\n', []);
		    * printk('CR2: %h   error_code: %h\n', [r_cr2, error_code]); *}
		   fault_adr := get_phys_adr(r_cr2);

		   {* Ci fault_page appartient aux pages adressables par le
		    * processus, on lui en alloue une autre. Sinon, on le tue
		    * (il a tenté un accès illégal quand même !!!) *}
		   if ((error_code and $FFFFF000) > $FFC01000) then
		   begin
		      {* printk('fault_adr: %h\n', [fault_adr]); *}
		      if (mem_map[MAP_NR(fault_adr)].count > 1) then
		      begin
		         asm
			    cli
			 end;
		         mem_map[MAP_NR(fault_adr)].count -= 1;
			 asm
			    sti
			 end;
		         new_page := kmalloc(4096);

		         { On recopie les données qui sont dans la page
			   partagée }
		         memcpy(pointer(longint(fault_adr) and $FFFFF000), new_page, 4096);
		   
		         { On enregistre maintenant la nouvelle page avec un
			   accès en écriture }
		         asm
		            mov   eax, r_cr2
		            push  eax
		            shr   eax, 22
		            mov   glob_index, eax
		            pop   eax
		            shr   eax, 12
		            and   eax, 1111111111b
		            mov   page_index, eax

		            mov   edi, cr3
		            mov   eax, glob_index
		            shl   eax, 2    { EAX = EAX * 4 }
		            add   edi, eax
		            mov   ebx, [edi]
		            and   ebx, $FFFFF000
		            mov   eax, page_index
		            shl   eax, 2
		            add   ebx, eax
		            mov   eax, new_page
		            or    eax, 7
		            mov   [ebx], eax
		            mov   eax, cr3  {* On vide le cache pour que la
			                     * nouvelle entrée soit prise en
					     * compte* }
			    mov   cr3, eax
		         end;
		      end
		   else
		      begin
		         asm
			    mov   eax, r_cr2
			    push  eax
			    shr   eax, 22
			    mov   glob_index, eax
			    pop   eax
			    shr   eax, 12
			    and   eax, 1111111111b
			    mov   page_index, eax
			    
			    mov   edi, cr3
			    mov   eax, glob_index
			    shl   eax, 2   { EAX = EAX * 4 }
			    add   edi, eax
			    mov   ebx, [edi]
			    and   ebx, $FFFFF000
			    mov   eax, page_index
			    shl   eax, 2
			    add   ebx, eax
			    mov   eax, [ebx]
			    or    eax, 7
			    mov   [ebx], eax
			    mov   eax, cr3
			    mov   cr3, eax
			 end;
		      end;
		   asm
		      popad
		      leave
		      pop   eax   {* On enlève le code d'erreur de la pile
		                   * (voir docs Intel) *}
		      iret
		   end;
		   end
		   else
		   begin
		      printk('Process %d is trying to accces a protected page !!!\n', [current^.pid]);
		      printk('%h2@%h\n', [error_code, r_cr2]);
		      printk('Killing it !!!\n', []);
		      panic('');
		      asm
		         popad
			 leave
			 pop   eax{* On enlève le code d'erreur de la pile
			           * (voir docs Intel) *}
		         {iret}
			 cli
		         hlt
		      end;
		   end
	       end
	   else
	       begin
	       {* Si on arrive ici, c'est la faute a été causé par un processus
	        * en mode utilisateur qui veut accéder à une de ces pages
		* alors que celle-ci n'est pas pésente en RAM. C'est donc ici
		* que l'on gère une partie du swapping *}
	           printk('\nSwapping not implemented yet !!!\n', []);
		   printk('CR2: %h   error_code: %h\n', [r_cr2, error_code]);
		   panic('');
	       end;
       end;
end;



{******************************************************************************
 * exception_15
 *
 * Exception reservée
 *****************************************************************************}
procedure exception_15; [public, alias : 'EXCEPTION_15'];
begin
   printk('Exception 15 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_16
 *
 * Se déclenche lors d'une erreur de virgule flottante
 *****************************************************************************}
procedure exception_16; [public, alias : 'EXCEPTION_16'];
begin
   printk('Exception 16 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_17
 *
 * Se déclenche lors d'une erreur d'alignement
 *****************************************************************************}
procedure exception_17; [public, alias : 'EXCEPTION_17'];
begin
   printk('Exception 17 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_18
 *
 * Se déclenche lors d'un problème machine
 *****************************************************************************}
procedure exception_18; [public, alias : 'EXCEPTION_18'];
begin
   printk('Exception 18 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_19
 *
 * ???
 *****************************************************************************}
procedure exception_19; [public, alias : 'EXCEPTION_19'];
begin
   printk('Exception 19 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_20
 *
 * ???
 *****************************************************************************}
procedure exception_20; [public, alias : 'EXCEPTION_20'];
begin
   printk('Exception 20 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_21
 *
 * ???
 *****************************************************************************}
procedure exception_21; [public, alias : 'EXCEPTION_21'];
begin
   printk('Exception 21 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_22
 *
 * ???
 *****************************************************************************}
procedure exception_22; [public, alias : 'EXCEPTION_22'];
begin
   printk('Exception 22 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_23
 *
 * ???
 *****************************************************************************}
procedure exception_23; [public, alias : 'EXCEPTION_23'];
begin
   printk('Exception 23 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_24
 *
 * ???
 *****************************************************************************}
procedure exception_24; [public, alias : 'EXCEPTION_24'];
begin
   printk('Exception 24 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_25
 *
 * ???
 *****************************************************************************}
procedure exception_25; [public, alias : 'EXCEPTION_25'];
begin
   printk('Exception 25 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_26
 *
 * ???
 *****************************************************************************}
procedure exception_26; [public, alias : 'EXCEPTION_26'];
begin
   printk('Exception 26 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_27
 *
 * ???
 *****************************************************************************}
procedure exception_27; [public, alias : 'EXCEPTION_27'];
begin
   printk('Exception 27 !!!\n', []);
   asm
      hlt
   end;
end;




{******************************************************************************
 * exception_28
 *
 * ???
 *****************************************************************************}
procedure exception_28; [public, alias : 'EXCEPTION_28'];
begin
   printk('Exception 28 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_29
 *
 * ???
 *****************************************************************************}
procedure exception_29; [public, alias : 'EXCEPTION_29'];
begin
   printk('Exception 29 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_30
 *
 * ???
 *****************************************************************************}
procedure exception_30; [public, alias : 'EXCEPTION_30'];
begin
   printk('Exception 30 !!!\n', []);
   asm
      hlt
   end;
end;



{******************************************************************************
 * exception_31
 *
 * ???
 *****************************************************************************}
procedure exception_31; [public, alias : 'EXCEPTION_31'];
begin
   printk('Exception 31 !!!\n', []);
   asm
      hlt
   end;
end;



begin
end.
