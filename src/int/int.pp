{******************************************************************************
 *  int.pp
 * 
 *  Exceptions management.
 *
 *  CopyLeft 2003 GaLi
 *
 *  version 0.2a - 20/09/2003 - GaLi - When a page fault is due to an
 *    	             	      	      application error, a signal is sent.
 *
 *  version 0.0  - ??/??/2001 - GaLi - initial version
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
{DEFINE DEBUG_DO_NO_PAGE}
{DEFINE DEBUG_DO_WP_PAGE}
{DEFINE DEBUG_ALLOC_BSS}

{$I fs.inc}
{$I mm.inc}
{$I process.inc}
{$I signal.inc}


function  btod (val : byte) : dword; external;
function  do_signal (signr : dword) : boolean; external;
function  find_mmap_req (addr : pointer) : P_mmap_req; external;
function  get_free_page : pointer; external;
function  get_page_rights (adr : dword) : dword; external;
function  get_phys_addr (adr : dword) : pointer; external;
function  get_pte (addr : dword) : P_pte_t; external;
function  inb (port : word) : byte; external;
function  MAP_NR (adr : dword) : dword; external;
procedure memcpy (src, dest : pointer ; size : dword); external;
procedure memset (adr : pointer ; c : byte ; size : dword); external;
procedure outb (port : word ; val : byte); external;
procedure panic (reason : string); external;
procedure print_bochs (format : string ; args : array of const); external;
procedure print_registers; external;
procedure printk (format : string ; args : array of const); external;
procedure schedule; external;
procedure send_sig (sig : dword ; p : P_task_struct); external;
procedure set_page_rights (adr : pointer ; r :dword); external;
procedure set_pte (addr : dword ; pte : pte_t); external;


function  do_no_page (addr : dword ; pte : P_pte_t) : boolean;
function  do_wp_page (addr : dword) : boolean;
procedure ignore_int;


var
   fpu_present  : boolean; external name 'U_CPU_FPU_PRESENT';
   mem_map      : P_page; external name 'U_MEM_MEM_MAP';
   current      : P_task_struct; external name 'U_PROCESS_CURRENT';
   shared_pages : dword; external name 'U_MEM_SHARED_PAGES';



IMPLEMENTATION


{$I inline.inc}


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
   outb($A0, $20);      { Send End Of Interrupt (EOI) to slave PIC }
   outb($20, $20);      { EOI to master PIC }
end;



{******************************************************************************
 * exception_0 (Zero divide)
 *
 * Se déclenche lors d'une division par zéro
 ******************************************************************************}
procedure exception_0; [public, alias : 'EXCEPTION_0'];
begin

   send_sig(SIGFPE, current);

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
 * exception_6 (Unknown instruction)
 *
 * Se déclenche lorsque le processeur rencontre une instruction inconnue
 *****************************************************************************}
procedure exception_6; [public, alias : 'EXCEPTION_6'];
begin

   send_sig(SIGILL, current);
	schedule();

end;



{******************************************************************************
 * exception_7
 *
 * Exception 7 is executed when a FPU instruction is executed without an
 * installed FPU or if the TS bit (register CR0) is set.
 *
 * FIXME: test this with a user mode program which uses the FPU.
 *****************************************************************************}
procedure exception_7; [public, alias : 'EXCEPTION_7']; interrupt;

const
   P_i387_regs : pointer = NIL;

begin

   if (fpu_present) then
   begin
{      if (P_i387_regs <> NIL) then
      begin
         if (P_i387_regs <> current) then
	 		begin
	    		{ FIXME: Save FPU registers in P_i387_regs structure }
	 		end;
      end;
      P_i387_regs := current;}
      asm
	 		clts   { Unset TS bit in cr0 }
{			finit}
      end;
   	print_bochs('exception_7 (PID=%d): just setting the TS bit to 0\n', [current^.pid]);
		
   end
   else
       panic('FPU instruction detected without coprocessor');

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
   r_cr0, r_cr3 : dword;
   esp0, r_eip  : dword;
   error_code   : dword;

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
      mov   eax, esp
      mov   esp0, eax
   end;

   printk('\nPID=%d  CR0: %h  CR3: %h\n', [current^.pid, r_cr0, r_cr3]);
   printk('EIP: %h  ESP: %h  error_code: %h\n', [r_eip, esp0, error_code]);

   panic('General Protection Fault');

end;



{******************************************************************************
 * exception_14
 *
 * Page fault handler.
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
   address    : dword;
   r_eip, i   : dword;
   pte 	     : P_pte_t;

label bad_addr;

begin

   asm
      pushad   { NOTE: May be we could save more registers }
      mov   eax, cr2
      mov   address, eax
      mov   eax, [ebp + 8]
      mov   r_eip, eax
      mov   eax, [ebp + 4]   { Get error code }
      and   eax, 111b
      mov   error_code, eax
      sti      { Set interrupts on }
   end;

   {$IFDEF DEBUG_14}
      print_bochs('exception_14 (%d): %d@%h (%h) rights=%h4 BRK=%h %h\n',
      	    		[current^.pid, error_code, address, get_pte(address),
	      	   	 get_page_rights(address), current^.brk,
				   	 current^.end_data]);
   {$ENDIF}

   if not ((address > $C0000000) and (address < current^.brk)) then
      goto bad_addr;

   pte := get_pte(address);

	if (longint(pte) and $FFFFF000) = 0 then
   begin
      if (do_no_page(address, pte) = FALSE) then
		goto bad_addr;
   end
   else
   begin
      if (error_code and 2) = 2 then
      { It's a write fault }
      begin
			if (mem_map[MAP_NR(address)].flags and WRITE_PAGE) = 0 then
	 		begin
	    		print_bochs('exception_14 (%d): try to write on a read-only page (%h) %d\n', [current^.pid, address, mem_map[MAP_NR(address)].flags]);
	    		goto bad_addr;
	 		end;
			if (do_wp_page(address) = FALSE) then
			goto bad_addr;
      end
      else
      begin
      	 printk('exception_14: don''t know what to do !!!\n', []);
      	 panic('');
      end;
   end;

   asm
      mov   eax, cr3
      mov   cr3, eax
      popad
      leave
      add   esp, 4
      iret
   end;


bad_addr:
   {$IFDEF DEBUG_14}
      printk('\nexception_14 (%d): bad_addr: %d@%h -> %h EIP=%h\n\n',
		[current^.pid, error_code, address, get_phys_addr(address), r_eip]);
   {$ENDIF}
      print_bochs('\nexception_14 (%d): bad_addr: %d@%h -> %h EIP=%h\n\n',
		[current^.pid, error_code, address, get_phys_addr(address), r_eip]);

	{ FIXME FIXME !!! }

{   send_sig(SIGSEGV, current);}
	do_signal(SIGSEGV);
{   schedule();}
   asm
      popad
      leave
      add   esp, 4
      iret
   end;

end;



{******************************************************************************
 * do_wp_page
 *
 * This function is used to manage Copy On Write
 *****************************************************************************}
function do_wp_page (addr : dword) : boolean;

var
   new_page : pointer;

begin

   result := FALSE;

   if (mem_map[MAP_NR(addr)].count > 1) then
   begin
      {$IFDEF DEBUG_DO_WP_PAGE}
      	 print_bochs('do_wp_page: count > 1 (%d) => COW (flags=%d)\n',
			 				 [mem_map[MAP_NR(addr)].count,
							  mem_map[MAP_NR(addr)].flags]);
      {$ENDIF}
		pushfd();
		cli();
      shared_pages -= 1;
      mem_map[MAP_NR(addr)].count -= 1;
		popfd();
      new_page := get_free_page();
      if (new_page = NIL) then
      begin
			printk('do_wp_page: not enough memory\n', []);
	 		exit;
      end;
      memcpy(pointer(addr and $FFFFF000), new_page, 4096);
      set_pte(addr, longint(new_page) or USER_PAGE);
      {$IFDEF DEBUG_DO_WP_PAGE}
      	 print_bochs('do_wp_page: new_page=%h -> %d\n',
			 				 [new_page, mem_map[longint(new_page) shr 12].flags]);
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG_DO_WP_PAGE}
      	 print_bochs('do_wp_page: COW (just setting page rights)\n', []);
      {$ENDIF}
      set_page_rights(pointer(addr), USER_PAGE);
   end;

	result := TRUE;

end;



{******************************************************************************
 * do_no_page
 *
 * This function is called when a page fault is due to a non present page.
 *****************************************************************************}
function do_no_page (addr : dword ; pte : P_pte_t) : boolean;

var
	req				: P_mmap_req;
   fichier        : file_t;
   new_page, buf	: pointer;
   page_nb	      : dword;
   res            : longint;

begin

   result := FALSE;

	if (longint(pte) and $FFF) = 0 then
	{ This only happens when the process stack needs to grow up }
	begin
		if (addr >= BASE_ADDR) then
		begin
			print_bochs('\nBUG: do_no_page: addr=%h  pte=%h\n\n', [addr, pte]);
			panic('Invalid page table: addr >= BASE_ADDR and pte flags = 0');
			exit;
		end;
	end;

   if (addr >= current^.end_data) then
   begin
		if (longint(pte) and FILE_MAPPED_PAGE) = FILE_MAPPED_PAGE then
		begin
			req := find_mmap_req(pointer(addr));
	      buf := get_free_page();
			if (buf = NIL) then
      	begin
				printk('do_no_page: not enough memory to read a page from disk (1)\n', []);
	 			exit;
      	end;

			{ Going to load the page from disk }
			memset(buf, 0, 4096);
			page_nb := (addr - longint(req^.addr)) div 4096;
			req^.fichier^.pos := (page_nb * 4096) + req^.pgoff;
			res := req^.fichier^.op^.read(req^.fichier, buf, 4096);
      	if (res <= 0) then
      	begin
				print_bochs('do_no_page: cannot read from disk (1)\n', []);
	 			exit;
      	end;

			{ FIXME: check req^.prot value }
     	 	set_pte(addr, longint(buf) or USER_PAGE);

      	current^.real_size += 1;
      	result := TRUE;
		end
		else
		begin
			{ Just allocate one more page for the bss section }
			{$IFDEF DEBUG_ALLOC_BSS}
       		print_bochs('do_no_page: allocating a new page for bss (addr=%h, brk=%h)\n', [addr, current^.brk]);
      	{$ENDIF}
      	new_page := get_free_page();
      	if (new_page = NIL) then
      	begin
				printk('do_no_page: not enough memory for bss\n', []);
	 			exit;
      	end;
      	memset(new_page, 0, 4096);   { FIXME: Do we REALLY need this ??? }
      	set_pte(addr, longint(new_page) or USER_PAGE);
      	current^.real_size += 1;
      	result := TRUE;
		end;
   end
   else if (addr < BASE_ADDR) then
   begin
      {$IFDEF DEBUG_DO_NO_PAGE}
      	 print_bochs('do_no_page: got to expand stack (%h -> %d)\n', [addr, 1023 - ((BASE_ADDR - addr) div 4096)]);
      {$ENDIF}
      new_page := get_free_page();
      if (new_page = NIL) then
      begin
			printk('do_no_page: not enough memory for stack\n', []);
	 		exit;
      end;
      memset(new_page, 0, 4096);   { FIXME: Do we REALLY need this ??? }
      set_pte(addr, longint(new_page) or USER_PAGE);
      result := TRUE;
   end
   else
   begin
      { We have to load the page from disk (text or data section) }
      if (current^.executable = NIL) then exit;
      page_nb := (addr - BASE_ADDR) div 4096;
      if (page_nb > current^.executable^.size div 4096) then exit;
      {$IFDEF DEBUG_DO_NO_PAGE}
      	 print_bochs('do_no_page: going to load page %d from disk (addr=%h)\n', [page_nb, addr]);
      {$ENDIF}
      buf := get_free_page();
      if (buf = NIL) then
      begin
			printk('do_no_page: not enough memory to read a page from disk (2)\n', []);
	 		exit;
      end;
      memset(@fichier, 0, sizeof(fichier));
      fichier.pos   := page_nb * 4096;
      fichier.inode := current^.executable;
      res := current^.executable^.op^.default_file_ops^.read(@fichier, buf, 4096);
      if (res <= 0) then
      begin
			print_bochs('do_no_page: cannot read from disk (2)n', []);
	 		exit;
      end;
      
      { Setting page rights }
      if (addr < current^.end_code) then
      	 set_pte(addr, longint(buf) or RDONLY_PAGE)
      else
      	 set_pte(addr, longint(buf) or USER_PAGE);

      {$IFDEF DEBUG_DO_NO_PAGE}
      	 print_bochs('do_no_page: %h -> %h (dump=%h) page %d\n', [addr, get_pte(addr), longint(buf^), page_nb]);
      {$ENDIF}
      current^.real_size += 1;
      result := TRUE;
   end;

end;



{******************************************************************************
 * exception_15
 *
 * Reserved by Intel
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

   panic('Floating point exception');

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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
 * Reserved by Intel
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
