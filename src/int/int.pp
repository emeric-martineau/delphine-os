{******************************************************************************
 *  int.pp
 * 
 *  Ce fichier contient les procédures qui gèrent les exceptions.
 *
 *  CopyLeft 2002 GaLi
 *
 *  version 0.2 - 14/05/2003 - GaLi - Page fault exception gives more stack.
 *                                    (A process has a 4096 bytes stack but
 *                                    now, we add 4096 bytes if the process
 *                                    has caused an exception because it uses
 *                                    too much stack).
 *
 *  version 0.1 - 20/06/2002 - GaLi - Begin "Copy On Write" management
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

{DEFINE DEBUG_14}

{$I fs.inc}
{$I mm.inc}
{$I process.inc}


function  btod (val : byte) : dword; external;
function  get_free_page : pointer; external;
function  get_page_rights (adr : pointer) : dword; external;
function  get_phys_addr (adr : pointer) : pointer; external;
function  inb (port : word) : byte; external;
function  kmalloc (size : dword) : pointer; external;
function  MAP_NR (adr : pointer) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure panic (reason : string); external;
procedure print_registers; external;
procedure printk (format : string ; args : array of const); external;
procedure schedule; external;
procedure send_sig (sig : dword ; p : P_task_struct); external;


var
   fpu_present  : boolean; external name 'U_CPU_FPU_PRESENT';
   mem_map      : P_page; external name 'U_MEM_MEM_MAP';
   current      : P_task_struct; external name 'U_PROCESS_CURRENT';
   shared_pages : dword; external name 'U_MEM_SHARED_PAGES';



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
   printk('WARNING: Unknown interrupt (isr1=%h2, isr2=%h2)\n', [btod(isr1), btod(isr2)]);
   outb($A0, $20);      { End of interrupt (EOI) pour l'esclave }
   outb($20, $20);      { EOI pour le maitre }
end;



{******************************************************************************
 * exception_0
 *
 * Se déclenche lors d'une division par zéro
 ******************************************************************************}
procedure exception_0; [public, alias : 'EXCEPTION_0'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 0: zero divide.');

end;



{******************************************************************************
 * exception_1
 *
 * Se déclenche lors du debuggage
 *****************************************************************************}
procedure exception_1; [public, alias : 'EXCEPTION_1'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 1: debug exception.');

end;



{******************************************************************************
 * exception_2
 *
 * Se déclenche lors qu'une interruption externe non masquable intervient
 *****************************************************************************}
procedure exception_2; [public, alias : 'EXCEPTION_2'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 2: NMI.');

end;



{******************************************************************************
 * exception_3
 *
 * Se déclenche lorsque le processeur rencontre un breakpoint
 *****************************************************************************}
procedure exception_3; [public, alias : 'EXCEPTION_3'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 3: breakpoint.');

end;



{******************************************************************************
 * exception_4
 *
 * Se déclenche lors d'un depassement de capacite
 *****************************************************************************}
procedure exception_4; [public, alias : 'EXCEPTION_4'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 4');

end;



{******************************************************************************
 * exception_5
 *
 * Se déclenche lors d'un depassement pour l'instruction BOUND
 *****************************************************************************}
procedure exception_5; [public, alias : 'EXCEPTION_5'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 5');

end;



{******************************************************************************
 * exception_6
 *
 * Se déclenche lorsque le processeur rencontre une instruction inconnue
 *****************************************************************************}
procedure exception_6; [public, alias : 'EXCEPTION_6'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 6: unknown instruction.');

end;



{******************************************************************************
 * exception_7
 *
 * Exception 7 is executed when a FPU instruction is executed without FPU or
 * when TS bit (register CR0) is set.
 *
 * FIXME: test this with a user mode program which uses the FPU.
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
	    { FIXME: Save FPU registers in P_i387_regs structure }
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
       panic('FPU instruction detected without coprocessor');

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

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 8: double exception.');

end;



{******************************************************************************
 * exception_9
 *
 * Se déclenche lors d'un Coprocessor Segment Overrun
 *****************************************************************************}
procedure exception_9; [public, alias : 'EXCEPTION_9'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 9: Coprocessor Segment Overrun.');

end;



{******************************************************************************
 * exception_10
 *
 * Se déclenche lors qu'un TSS invalide est rencontré
 *****************************************************************************}
procedure exception_10; [public, alias : 'EXCEPTION_10'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 10: invalid TSS.');

end;



{******************************************************************************
 * exception_11
 *
 * Se déclenche lorsqu'un segment est non présent
 *****************************************************************************}
procedure exception_11; [public, alias : 'EXCEPTION_11'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 11: non-present segment.');

end;



{******************************************************************************
 * exception_12
 *
 * Se déclenche lorsqu'un segement de pile manque
 *****************************************************************************}
procedure exception_12; [public, alias : 'EXCEPTION_12'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 12: no stack segment.');

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
 *****************************************************************************}
procedure exception_13; [public, alias : 'EXCEPTION_13'];

var
   r_cr0, r_cr3, flags : dword;
   esp0, r_eip : dword;
   error_code : dword;

begin
   
   asm
      mov   eax, [ebp + 4]
      mov   error_code, eax
      mov   eax, [ebp + 8]
      mov   r_eip, eax
      mov   eax, cr0
      mov   r_cr0, eax
      mov   eax, cr3
      mov   r_cr3, eax
      pushfd
      pop   eax
      mov   flags, eax
      mov   eax, esp
      mov   esp0, eax
   end;

   printk('\nPID=%d  CR0: %h  CR3: %h  flags: %h\n', [current^.pid, r_cr0, r_cr3, flags]);
   printk('EIP: %h  ESP: %h  error_code: %h\n', [r_eip, esp0, error_code]);

   panic('General Protection Fault');

end;



{******************************************************************************
 * exception_14
 *
 * Se déclenche lorsqu'une page est demandée et n'est pas présente en mémoire.
 * Il faudra donc gerer la memoire virtuelle ici.
 *
 * Error code bits definition :
 *
 *   bit 0: 0 -> page not present
 *          1 -> protection violation
 *
 *   bit 1: 0 -> read fault
 *          1 -> write fault
 *
 *   bit 2: 0 -> error in kernel mode
 *          1 -> error in user mode
 *****************************************************************************}
procedure exception_14; [public, alias : 'EXCEPTION_14'];

var
   error_code : dword;
   r_cr2      : pointer;
   page_index : dword;
   glob_index : dword;
   fault_adr  : pointer;
   new_page   : pointer;
   r_eip, i   : dword;
   page_table : P_pte_t;

begin

   asm
      pushad   { FIXME: May be we could save more registers }
      mov   eax, cr2
      mov   r_cr2, eax
      mov   eax, [ebp + 8]
      mov   r_eip, eax
      mov   eax, [ebp + 4]   { Get error code }
      and   eax, 111b
      mov   error_code, eax
      sti      { Set interrupts on }
   end;

   {$IFDEF DEBUG_14}
      printk('exception_14 (%d): %d@%h  rights=%h2  EIP=%h ', [current^.pid, error_code, r_cr2,
      							       get_page_rights(get_phys_addr(r_cr2)), r_eip]);
   {$ENDIF}

   if (error_code and $4) <> $4 then
   begin
      printk('\nPage fault in kernel mode (fuckin'' bad news !!!) PID=%d\n', [current^.pid]);
      printk('CR2: %h -> %h  error_code: %d  EIP=%h -> %h\n', [r_cr2, get_phys_addr(r_cr2), error_code, r_eip,
     							       get_phys_addr(pointer(r_eip))]);
      panic('kernel panic');
   end
   else    { The page fault appeared in user mode }
   begin
      if (error_code and $1) = $1 then   { Protection violation }
      begin

         fault_adr := get_phys_addr(r_cr2);

	 {* Si fault_page appartient aux pages adressables par le
	  * processus, on lui en alloue une autre. Sinon, on le tue
	  * (il a tenté un accès illégal quand même !!!) *}

	 if ((longint(fault_adr) and $FFFFF000) > $FFC01000) and
	    ((longint(fault_adr) and $FFFFF000) < current^.brk) then
	 begin
	    {$IFDEF DEBUG_14}
	       printk('mem_map count=%d', [mem_map[MAP_NR(fault_adr)].count]);
	    {$ENDIF}
	    if (mem_map[MAP_NR(fault_adr)].count > 1) then
	    begin
	       asm
	          pushfd
	          cli
	       end;
	       shared_pages -= 1;
	       mem_map[MAP_NR(fault_adr)].count -= 1;
	       asm
		  popfd
	       end;
	       new_page := get_free_page();
	       if (new_page = NIL) then panic('exception_14: not enough memory');

	       { On recopie les données qui sont dans la page partagée }
	       memcpy(pointer(longint(fault_adr) and $FFFFF000), new_page, 4096);
		   
	       { On enregistre maintenant la nouvelle page avec un accès en écriture }

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
		  or    eax, 7   { Access rights }
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
	    {$IFDEF DEBUG_14}
	       printk('\n', []);
	    {$ENDIF}
	    asm
	       popad
	       leave
	       add   esp, 4   {* On enlève le code d'erreur de la pile
		               * (voir docs Intel) *}
	       iret
	    end;
	 end
	 else
	 begin
	    printk('Process %d is trying to accces a protected page !!!\n', [current^.pid]);
	    printk('%d@%h  EIP=%h\n', [error_code, r_cr2, r_eip]);
	    printk('Killing it !!!\n\n', []);
	    send_sig(SIGKILL, current);
	    schedule();
	    asm
	       popad
	       leave
	       add   esp, 4   {* On enlève le code d'erreur de la pile
		               * (voir docs Intel) *}
	       iret
            end;
	 end
       end
       else
       begin
          {* Si on arrive ici, c'est la faute a été causé par un processus
	   * en mode utilisateur qui veut accéder à une de ces pages
	   * alors que celle-ci n'est pas pésente en RAM. C'est donc ici
	   * que l'on devra gérer une partie du swapping *}
		
	  { Check if the process needs more stack. If it needs more, we add 4096 bytes for the stack (but not more) }
	  if ((longint(r_cr2) > $FFBFF000) and (longint(r_cr2) < $FFC00000)) then
	  begin
	     page_table := get_free_page();
	     new_page   := get_free_page();
	     if ((page_table = NIL) or (new_page = NIL)) then panic('exception_14: not enough memory');
	     memset(page_table, 0, 4096);
	     memset(new_page, 0, 4096);
	     current^.cr3[1022] := longint(page_table) or USER_PAGE;
	     page_table[1023]   := longint(new_page) or USER_PAGE;
	     {$IFDEF DEBUG_14}
	        printk('-> more stack\n', []);
	     {$ENDIF}
	     asm
	        mov   eax, cr3   { Flush TLB, don't know if we really need this. }
	        mov   cr3, eax   { I put it to be careful }
	        popad
		leave
		add   esp, 4
		iret
	     end;
	  end
	  else
	  { The process needs more than 8192 bytes for his stack...  Fuck it  :-) }
	  if (longint(r_cr2) < $FFBFF000) and (longint(r_cr2) > $FFB00000)then
	  begin
	     {printk('\nCR2: %h  error_code: %d  EIP=%h\n', [r_cr2, error_code, r_eip]);}
	     printk('\n\n---!!!---===***===---!!!---\n', []);
	     printk('PID %d is using too much stack. (CR2=%h)\n', [current^.pid, r_cr2]);
	     printk('DelphineOS gives processes 8192 stack bytes (not more), Sorry...\n', []);
	     printk('Killing PID %d\n---!!!---===***===---!!!---\n\n', [current^.pid]);
	     send_sig(SIGKILL, current);
	     schedule();
	     asm
	        popad
		leave
		add   esp, 4
		iret
	     end;
	  end
	  else
	  begin
	     printk('\nSwapping not implemented yet (PID=%d) !!!\n', [current^.pid]);
	     printk('CR2: %h  error_code: %d  EIP=%h\n', [r_cr2, error_code, r_eip]);
	     page_index := (longint(r_cr2) and $FFFF) div 4096;
	     printk('Current process page table entry #%d dump: ', [page_index]);
	     printk('%h\n', [current^.page_table[page_index]]);
	     panic('');
	  end;
       end;
    end;
end;



{******************************************************************************
 * exception_15
 *
 * Exception reservée
 *****************************************************************************}
procedure exception_15; [public, alias : 'EXCEPTION_15'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 15');

end;



{******************************************************************************
 * exception_16
 *
 * Se déclenche lors d'une erreur de virgule flottante
 *****************************************************************************}
procedure exception_16; [public, alias : 'EXCEPTION_16'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 4]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 16');

end;



{******************************************************************************
 * exception_17
 *
 * Se déclenche lors d'une erreur d'alignement
 *****************************************************************************}
procedure exception_17; [public, alias : 'EXCEPTION_17'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 17');

end;



{******************************************************************************
 * exception_18
 *
 * Se déclenche lors d'un problème machine
 *****************************************************************************}
procedure exception_18; [public, alias : 'EXCEPTION_18'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 18');

end;



{******************************************************************************
 * exception_19
 *
 * ???
 *****************************************************************************}
procedure exception_19; [public, alias : 'EXCEPTION_19'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 19');

end;



{******************************************************************************
 * exception_20
 *
 * ???
 *****************************************************************************}
procedure exception_20; [public, alias : 'EXCEPTION_20'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 20');

end;



{******************************************************************************
 * exception_21
 *
 * ???
 *****************************************************************************}
procedure exception_21; [public, alias : 'EXCEPTION_21'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 21');

end;



{******************************************************************************
 * exception_22
 *
 * ???
 *****************************************************************************}
procedure exception_22; [public, alias : 'EXCEPTION_22'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 22');

end;



{******************************************************************************
 * exception_23
 *
 * ???
 *****************************************************************************}
procedure exception_23; [public, alias : 'EXCEPTION_23'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 23');

end;



{******************************************************************************
 * exception_24
 *
 * ???
 *****************************************************************************}
procedure exception_24; [public, alias : 'EXCEPTION_24'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 24');

end;



{******************************************************************************
 * exception_25
 *
 * ???
 *****************************************************************************}
procedure exception_25; [public, alias : 'EXCEPTION_25'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 25');

end;



{******************************************************************************
 * exception_26
 *
 * ???
 *****************************************************************************}
procedure exception_26; [public, alias : 'EXCEPTION_26'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 26');

end;



{******************************************************************************
 * exception_27
 *
 * ???
 *****************************************************************************}
procedure exception_27; [public, alias : 'EXCEPTION_27'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 27');

end;




{******************************************************************************
 * exception_28
 *
 * ???
 *****************************************************************************}
procedure exception_28; [public, alias : 'EXCEPTION_28'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 28');

end;



{******************************************************************************
 * exception_29
 *
 * ???
 *****************************************************************************}
procedure exception_29; [public, alias : 'EXCEPTION_29'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 29');

end;



{******************************************************************************
 * exception_30
 *
 * ???
 *****************************************************************************}
procedure exception_30; [public, alias : 'EXCEPTION_30'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 30');

end;



{******************************************************************************
 * exception_31
 *
 * ???
 *****************************************************************************}
procedure exception_31; [public, alias : 'EXCEPTION_31'];

var
   r_eip : dword;

begin

   asm
      mov   eax, [ebp + 8]
      mov   r_eip, eax
   end;
   printk('\nEIP: %h', [r_eip]);

   panic('Exception 31');

end;



begin
end.
